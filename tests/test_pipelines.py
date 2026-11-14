import asyncio
import datetime as dt
import json
from types import SimpleNamespace

import numpy as np
import pytest
from google.genai import errors

from game_trans.ai.gemini_client import GeminiClient, QuotaExceeded, pcm16_to_wav
from game_trans.ai.usage import UsageMeter, UsageStore
from game_trans.audio.capture import compute_rms_level, to_16k_mono_pcm16
from game_trans.audio.vad import FRAME_SAMPLES, SAMPLE_RATE, VadSegmenter
from game_trans.config import (
    Audio,
    Config,
    load_config,
    load_glossary,
    load_phrases,
    save_config,
    save_glossary,
    save_phrases,
)
from game_trans.events import Segment
from game_trans.tts.base import FallbackTTS, SpeechAudio, TTSEngine
from game_trans.tts.edge import DEFAULT_VOICES, EdgeTTS


def _sine_pcm16(freq_hz: float, duration_s: float, amp: float = 0.25, sr: int = SAMPLE_RATE) -> bytes:
    n = int(sr * duration_s)
    t = np.arange(n, dtype=np.float32) / sr
    wave = (amp * np.sin(2.0 * np.pi * freq_hz * t)).astype(np.float32)
    return np.clip(wave * 32767.0, -32768.0, 32767.0).astype(np.int16).tobytes()


# --------------------------------------------------------------------------- config & persistence


def test_save_and_load_config_roundtrip(tmp_path):
    cfg = Config()
    cfg.ai.model = "gemini-3.5-flash"
    cfg.ai.rpm_limit = 120
    cfg.overlay.opacity = 0.65
    cfg.audio.bgm_suppression = True
    cfg.voice_out.mix_microphone = True

    path = save_config(cfg, tmp_path / "config.toml")
    loaded = load_config(path)
    assert loaded.ai.model == "gemini-3.5-flash"
    assert loaded.ai.rpm_limit == 120
    assert loaded.overlay.opacity == pytest.approx(0.65)
    assert loaded.audio.bgm_suppression is True
    assert loaded.voice_out.mix_microphone is True


def test_phrases_and_glossary_roundtrip(tmp_path):
    p_path = tmp_path / "phrases.json"
    defaults = load_phrases(p_path)
    assert len(defaults) >= 4

    custom = [{"emoji": "⚡", "text": "빨리!"}, {"emoji": "🎮", "text": "같이 하자"}]
    save_phrases(custom, p_path)
    assert load_phrases(p_path) == custom

    g_path = tmp_path / "glossary.json"
    assert load_glossary(g_path) == []
    save_glossary(["  blox fruits ", "", "ggwp\n"], g_path)
    assert load_glossary(g_path) == ["blox fruits", "ggwp"]


# --------------------------------------------------------------------------- usage SQLite store


def test_usage_store_and_meter_persistence(tmp_path):
    db = tmp_path / "usage.sqlite"
    today = dt.date(2026, 11, 14)
    store = UsageStore(db)
    store.add(today.isoformat(), 500_000, 100_000, 0.40)
    store.add((today - dt.timedelta(days=1)).isoformat(), 250_000, 50_000, 0.20)
    store.close()

    reopened = UsageStore(db)
    t_stats, m_stats = reopened.load_totals(today=today)
    assert t_stats.requests == 1
    assert t_stats.cost_usd == pytest.approx(0.40)
    assert m_stats.requests == 2
    assert m_stats.cost_usd == pytest.approx(0.60)

    bars = reopened.recent_days(days=12, today=today)
    assert len(bars) == 12
    assert bars[-1] == (today.isoformat(), pytest.approx(0.40))
    assert bars[-2] == ((today - dt.timedelta(days=1)).isoformat(), pytest.approx(0.20))
    reopened.close()

    meter_store = UsageStore(tmp_path / "meter.sqlite")
    meter = UsageMeter(input_per_mtok=0.30, output_per_mtok=2.50, store=meter_store)
    cost = meter.record(1_000_000, 100_000)
    assert cost == pytest.approx(0.55)
    meter_store.close()

    meter_store2 = UsageStore(tmp_path / "meter.sqlite")
    meter2 = UsageMeter(store=meter_store2)
    assert meter2.today.requests == 1
    assert meter2.today.cost_usd == pytest.approx(0.55)
    meter_store2.close()


# --------------------------------------------------------------------------- audio helpers & VAD


def test_to_16k_mono_and_rms():
    assert to_16k_mono_pcm16(np.array([], dtype=np.float32), 48_000, channels=2) == b""
    assert compute_rms_level(b"") == 0.0
    assert compute_rms_level(b"\x00" * 1024) == 0.0

    # 48 kHz stereo 1 kHz sine -> 16 kHz mono int16 (1/3 sample count per channel)
    n_frames = 4800
    t = np.arange(n_frames, dtype=np.float32) / 48_000
    mono = 0.2 * np.sin(2.0 * np.pi * 1000.0 * t).astype(np.float32)
    stereo = np.column_stack([mono, mono]).reshape(-1)
    pcm16 = to_16k_mono_pcm16(stereo, sample_rate=48_000, channels=2)
    out = np.frombuffer(pcm16, dtype=np.int16)
    assert len(out) == 1600
    assert 0.1 < compute_rms_level(pcm16) <= 1.0


def test_spectral_vad_segmentation_and_edge_cases():
    emitted: list[Segment] = []
    cfg = Audio(
        speech_threshold=0.45,
        min_speech_ms=200,
        silence_end_ms=320,
        pre_roll_ms=128,
        max_segment_s=1.0,
    )
    vad = VadSegmenter(cfg, emitted.append, allow_download=False, force_spectral=True)
    assert vad.backend_name == "spectral"

    # Pure silence -> nothing emitted
    vad.feed(b"\x00" * (FRAME_SAMPLES * 2 * 30))
    assert emitted == []

    # Short noise burst (< min_speech_ms) followed by silence -> dropped
    vad.feed(_sine_pcm16(1000.0, 0.096))
    vad.feed(b"\x00" * (FRAME_SAMPLES * 2 * 15))
    assert emitted == []

    # Speech burst (>= 200 ms) followed by trailing silence -> 1 segment
    vad.feed(_sine_pcm16(1000.0, 0.384))
    vad.feed(b"\x00" * (FRAME_SAMPLES * 2 * 12))
    assert len(emitted) == 1
    assert emitted[0].id == 1
    assert emitted[0].sample_rate == SAMPLE_RATE
    assert emitted[0].duration_s > 0.35

    # Forced split on continuous speech > max_segment_s (1.0 s)
    emitted.clear()
    vad.reset()
    vad.feed(_sine_pcm16(900.0, 1.3))
    assert len(emitted) >= 1

    # Flush emits unfinished speech segment
    emitted.clear()
    vad.reset()
    vad.feed(_sine_pcm16(1100.0, 0.32))
    assert emitted == []
    vad.flush()
    assert len(emitted) == 1


def test_vad_bgm_suppression_bandpass():
    emitted: list[Segment] = []
    cfg = Audio(bgm_suppression=True, min_speech_ms=160, silence_end_ms=256)
    vad = VadSegmenter(cfg, emitted.append, allow_download=False, force_spectral=True)

    # Low sub-bass rumble (60 Hz) attenuated by 300-3400 Hz bandpass
    vad.feed(_sine_pcm16(60.0, 0.4, amp=0.3))
    vad.feed(b"\x00" * (FRAME_SAMPLES * 2 * 10))
    assert emitted == []

    # Voice-band 1 kHz tone triggers normally
    vad.feed(_sine_pcm16(1000.0, 0.35, amp=0.25))
    vad.feed(b"\x00" * (FRAME_SAMPLES * 2 * 10))
    assert len(emitted) == 1


# --------------------------------------------------------------------------- TTS fallback & cache


class _DummyEngine(TTSEngine):
    def __init__(self, name: str, fail: bool = False) -> None:
        self.name = name
        self.fail = fail
        self.calls = 0

    async def synthesize(self, text: str, lang: str) -> SpeechAudio:
        self.calls += 1
        if self.fail:
            raise RuntimeError(f"{self.name} down")
        return SpeechAudio(pcm16=f"{self.name}:{lang}:{text}".encode(), sample_rate=24_000)


def test_fallback_tts_chain_and_lru_cache():
    primary = _DummyEngine("edge", fail=True)
    backup = _DummyEngine("sapi", fail=False)
    tts = FallbackTTS([primary, backup], max_cache=2)

    async def run():
        a1 = await tts.synthesize("hello", "en")
        a2 = await tts.synthesize("hello", "en")  # cached hit
        assert a1 == a2
        assert primary.calls == 1
        assert backup.calls == 1

        tts.clear_cache()
        await tts.synthesize("hello", "en")
        assert backup.calls == 2

    asyncio.run(run())


def test_edge_tts_voice_selection():
    tts = EdgeTTS(voice="en-US-AriaNeural")
    assert tts._pick_voice("en") == "en-US-AriaNeural"
    assert tts._pick_voice("EN-gb") == "en-US-AriaNeural"
    assert tts._pick_voice("ja") == DEFAULT_VOICES["ja"]


# --------------------------------------------------------------------------- GeminiClient (mocked)


class _FakeModels:
    def __init__(self, handler):
        self._handler = handler
        self.calls = []

    async def generate_content(self, *, model, contents, config):
        self.calls.append((model, contents, config))
        return await self._handler(model, contents, config)


class _FakeClient:
    def __init__(self, handler):
        self.aio = SimpleNamespace(models=_FakeModels(handler))


def _make_resp(payload: dict | str, prompt_tok: int = 100, out_tok: int = 20, thought_tok: int = 5):
    text = payload if isinstance(payload, str) else json.dumps(payload, ensure_ascii=False)
    usage = SimpleNamespace(
        prompt_token_count=prompt_tok,
        candidates_token_count=out_tok,
        thoughts_token_count=thought_tok,
    )
    return SimpleNamespace(text=text, usage_metadata=usage)


def test_gemini_client_pipelines_and_retries(monkeypatch):
    responses = []

    async def handler(model, contents, config):
        nxt = responses.pop(0)
        if isinstance(nxt, Exception):
            raise nxt
        return nxt

    fake = _FakeClient(handler)
    monkeypatch.setattr("game_trans.ai.gemini_client.genai.Client", lambda **kw: fake)

    async def fast_sleep(_s):
        return None

    monkeypatch.setattr("game_trans.ai.gemini_client.asyncio.sleep", fast_sleep)

    cfg = Config()
    cfg.ai.rpm_limit = 1000
    meter = UsageMeter()
    client = GeminiClient("fake-key", cfg, meter)
    client.glossary = ["Blox Fruits"]

    async def run():
        # 1. interpret_audio
        responses.append(
            _make_resp(
                {
                    "is_speech": True,
                    "source_lang": "en",
                    "transcript": "Trade me!",
                    "translation": "나랑 거래하자!",
                    "confidence": 0.95,
                }
            )
        )
        cap = await client.interpret_audio(Segment(id=1, pcm16=_sine_pcm16(1000.0, 0.2), sample_rate=16_000))
        assert cap.is_speech is True
        assert cap.translation == "나랑 거래하자!"
        assert list(client.context) == ["Trade me!"]
        assert meter.today.requests == 1
        assert meter.today.input_tokens == 100
        assert meter.today.output_tokens == 25  # 20 + 5 thought tokens

        # 2. translate_text (local STT path)
        responses.append(
            _make_resp(
                {
                    "is_speech": True,
                    "source_lang": "ja",
                    "transcript": "ありがとう",
                    "translation": "고마워",
                    "confidence": 0.9,
                }
            )
        )
        cap2 = await client.translate_text(2, "ありがとう", "ja")
        assert cap2.translation == "고마워"
        assert len(client.context) == 2

        # 3. translate_outgoing + tone_override + show_pronunciation toggle
        responses.append(
            _make_resp(
                {
                    "translation": "Hold on!",
                    "pronunciation": "홀드 온!",
                    "casual": "Sec!",
                    "polite": "One moment, please.",
                }
            )
        )
        out = await client.translate_outgoing("잠깐만", "en", tone_override="casual")
        assert out.translation == "Hold on!"
        assert out.pronunciation == "홀드 온!"
        assert out.casual == "Sec!"

        cfg.ai.show_pronunciation = False
        responses.append(_make_resp({"translation": "Thanks!", "pronunciation": "땡스!", "casual": "Thx!", "polite": "Thank you!"}))
        out2 = await client.translate_outgoing("고마워", "en")
        assert out2.pronunciation == ""

        # 4. 400 drops thinking_config & 429 retries then succeeds
        responses.append(errors.APIError(400, {"error": {"message": "thinking unsupported"}}))
        responses.append(errors.APIError(429, {"error": {"message": "rate limited"}}))
        responses.append(_make_resp("OK"))
        ok, msg = await client.test_connection()
        assert ok is True
        assert cfg.ai.model in msg

        # 5. Exhausted 429 raises QuotaExceeded
        responses.extend([errors.APIError(429, {"error": {"message": "quota"}}) for _ in range(4)])
        with pytest.raises(QuotaExceeded):
            await client.translate_outgoing("테스트", "en")

    assert len(pcm16_to_wav(b"\x00\x00" * 160)) == 44 + 320
    asyncio.run(run())
