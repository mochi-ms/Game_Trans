"""edge-tts engine – free default. Unofficial endpoint, so it sits first in a fallback chain."""

from __future__ import annotations

import edge_tts
import miniaudio

from .base import SpeechAudio, TTSEngine

DEFAULT_VOICES = {
    "en": "en-US-AndrewNeural",
    "ko": "ko-KR-InJoonNeural",
    "ja": "ja-JP-KeitaNeural",
    "zh": "zh-CN-YunxiNeural",
    "es": "es-ES-AlvaroNeural",
    "pt": "pt-BR-AntonioNeural",
    "fr": "fr-FR-HenriNeural",
    "de": "de-DE-ConradNeural",
    "ru": "ru-RU-DmitryNeural",
    "id": "id-ID-ArdiNeural",
    "th": "th-TH-NiwatNeural",
    "vi": "vi-VN-NamMinhNeural",
    "tl": "fil-PH-AngeloNeural",
    "ar": "ar-SA-HamedNeural",
    "tr": "tr-TR-AhmetNeural",
}


class EdgeTTS(TTSEngine):
    name = "edge"

    def __init__(self, voice: str = "en-US-AndrewNeural", rate: str = "+0%") -> None:
        self.voice = voice
        self.rate = rate

    def _pick_voice(self, lang: str) -> str:
        low = (lang or "").lower().split("-")[0]
        if self.voice and self.voice.lower().startswith(f"{low}-"):
            return self.voice
        return DEFAULT_VOICES.get(low, self.voice or "en-US-AndrewNeural")

    async def synthesize(self, text: str, lang: str) -> SpeechAudio:
        voice = self._pick_voice(lang)
        comm = edge_tts.Communicate(text, voice=voice, rate=self.rate)
        chunks: list[bytes] = []
        async for msg in comm.stream():
            if msg["type"] == "audio":
                chunks.append(msg["data"])
        mp3_bytes = b"".join(chunks)
        if not mp3_bytes:
            raise RuntimeError("edge-tts returned empty audio")
        decoded = miniaudio.decode(
            mp3_bytes,
            output_format=miniaudio.SampleFormat.SIGNED16,
            nchannels=1,
            sample_rate=24_000,
        )
        return SpeechAudio(pcm16=decoded.samples.tobytes(), sample_rate=24_000)
