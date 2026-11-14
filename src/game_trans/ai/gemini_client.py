"""Gemini API client for both pipelines.

* ``interpret_audio`` – listen pipeline: one VAD segment -> transcript + translation (JSON).
* ``translate_text`` – local STT mode: text -> translation (JSON).
* ``translate_outgoing`` – speak pipeline: my text -> translation + pronunciation + alternatives.

Uses ``gemini-3.5-flash-lite`` (configurable) with minimal thinking and structured output.
"""

from __future__ import annotations

import asyncio
import io
import json
import wave
from collections import deque

from google import genai
from google.genai import errors, types

from ..config import Config
from ..events import Caption, OutgoingTranslation, Segment
from . import prompts
from .rate_limiter import RateLimiter
from .usage import UsageMeter


class QuotaExceeded(RuntimeError):
    """Raised after retries when the API keeps returning 429."""


def pcm16_to_wav(pcm16: bytes, sample_rate: int = 16_000) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        w.writeframes(pcm16)
    return buf.getvalue()


class GeminiClient:
    MAX_RETRIES = 3

    def __init__(self, api_key: str, cfg: Config, meter: UsageMeter | None = None) -> None:
        self.cfg = cfg
        self.api_key = api_key
        self.client = genai.Client(api_key=api_key)
        self.limiter = RateLimiter(max(1, cfg.ai.rpm_limit))
        self.meter = meter or UsageMeter(
            input_per_mtok=cfg.ai.pricing.input_per_mtok,
            output_per_mtok=cfg.ai.pricing.output_per_mtok,
            monthly_budget_usd=cfg.budget.monthly_budget_usd,
            warn_ratio=cfg.budget.warn_ratio,
        )
        self.context: deque[str] = deque(maxlen=cfg.ai.context_lines)
        self.glossary: list[str] = []

    def update_config(self, cfg: Config, api_key: str | None = None) -> None:
        if cfg.ai.rpm_limit != self.cfg.ai.rpm_limit:
            self.limiter = RateLimiter(max(1, cfg.ai.rpm_limit))
        if cfg.ai.context_lines != self.cfg.ai.context_lines:
            self.context = deque(self.context, maxlen=cfg.ai.context_lines)
        self.cfg = cfg
        self.meter.input_per_mtok = cfg.ai.pricing.input_per_mtok
        self.meter.output_per_mtok = cfg.ai.pricing.output_per_mtok
        self.meter.monthly_budget_usd = cfg.budget.monthly_budget_usd
        self.meter.warn_ratio = cfg.budget.warn_ratio
        if api_key is not None and api_key != self.api_key:
            self.api_key = api_key
            self.client = genai.Client(api_key=api_key)

    # ------------------------------------------------------------------ core

    def _config(
        self, system: str, schema: dict | None, temperature: float, use_thinking: bool = True
    ) -> types.GenerateContentConfig:
        kwargs: dict = {
            "system_instruction": system,
            "temperature": temperature,
        }
        if schema is not None:
            kwargs["response_mime_type"] = "application/json"
            kwargs["response_json_schema"] = schema
        if use_thinking and "3." in self.cfg.ai.model:
            kwargs["thinking_config"] = types.ThinkingConfig(thinking_level="minimal")
        return types.GenerateContentConfig(**kwargs)

    async def _generate(
        self, contents: list, system: str, schema: dict | None, temperature: float
    ) -> dict:
        delay = 1.0
        use_thinking = True
        for attempt in range(self.MAX_RETRIES + 1):
            await self.limiter.acquire()
            config = self._config(system, schema, temperature, use_thinking=use_thinking)
            try:
                resp = await self.client.aio.models.generate_content(
                    model=self.cfg.ai.model, contents=contents, config=config
                )
            except errors.APIError as e:
                if e.code == 400 and use_thinking:
                    # Fallback if user switches to a model without thinking_level support
                    use_thinking = False
                    continue
                if e.code in (429, 503) and attempt < self.MAX_RETRIES:
                    self.limiter.penalize(delay)
                    await asyncio.sleep(delay)
                    delay *= 2
                    continue
                if e.code == 429:
                    raise QuotaExceeded(str(e)) from e
                raise
            usage = resp.usage_metadata
            if usage:
                out = (usage.candidates_token_count or 0) + (usage.thoughts_token_count or 0)
                self.meter.record(usage.prompt_token_count or 0, out)
            if schema is None:
                return {"text": resp.text or ""}
            return json.loads(resp.text or "{}")
        raise QuotaExceeded("retries exhausted")

    async def test_connection(self) -> tuple[bool, str]:
        try:
            await self._generate(
                ["Reply with OK."],
                system="Reply with OK only.",
                schema=None,
                temperature=0.0,
            )
            return True, f"{self.cfg.ai.model} 연결 성공"
        except errors.APIError as e:
            if e.code in (400, 401, 403):
                return False, f"API 키 또는 권한 오류 ({e.code})"
            if e.code == 404:
                return False, f"모델을 찾을 수 없음: {self.cfg.ai.model}"
            if e.code == 429:
                return False, "요청 한도 초과 (429) — 잠시 후 다시 시도하세요"
            return False, f"API 오류 ({e.code}): {e.message or e}"
        except Exception as e:  # noqa: BLE001
            return False, f"연결 실패: {e}"

    # ------------------------------------------------------------------ listen

    async def interpret_audio(self, segment: Segment) -> Caption:
        system = prompts.listen_system_prompt(
            self.cfg.general.my_language, self.glossary, list(self.context)
        )
        wav = pcm16_to_wav(segment.pcm16, segment.sample_rate)
        data = await self._generate(
            [types.Part.from_bytes(data=wav, mime_type="audio/wav"), "Interpret this clip."],
            system=system,
            schema=prompts.LISTEN_SCHEMA,
            temperature=0.2,
        )
        caption = Caption(
            segment_id=segment.id,
            is_speech=bool(data.get("is_speech")),
            source_lang=data.get("source_lang", ""),
            transcript=data.get("transcript", ""),
            translation=data.get("translation", ""),
            confidence=float(data.get("confidence", 1.0)),
        )
        if caption.is_speech and caption.transcript:
            self.context.append(caption.transcript)
        return caption

    async def translate_text(
        self, segment_id: int, text: str, source_lang: str = ""
    ) -> Caption:
        """Local-STT fallback: translate already-transcribed speech using text tokens only."""
        system = prompts.listen_system_prompt(
            self.cfg.general.my_language, self.glossary, list(self.context)
        )
        prompt = f"Already transcribed ({source_lang or 'auto'}): {text}"
        data = await self._generate(
            [prompt],
            system=system,
            schema=prompts.LISTEN_SCHEMA,
            temperature=0.2,
        )
        caption = Caption(
            segment_id=segment_id,
            is_speech=bool(data.get("is_speech", True)),
            source_lang=data.get("source_lang") or source_lang,
            transcript=data.get("transcript") or text,
            translation=data.get("translation", ""),
            confidence=float(data.get("confidence", 0.9)),
        )
        if caption.is_speech and caption.transcript:
            self.context.append(caption.transcript)
        return caption

    # ------------------------------------------------------------------ speak

    async def translate_outgoing(
        self, text: str, target_lang: str, tone_override: str | None = None
    ) -> OutgoingTranslation:
        tone = tone_override or self.cfg.ai.tone
        system = prompts.speak_system_prompt(
            self.cfg.general.my_language, target_lang, tone, self.glossary
        )
        data = await self._generate(
            [text],
            system=system,
            schema=prompts.SPEAK_SCHEMA,
            temperature=0.4,
        )
        return OutgoingTranslation(
            source_text=text,
            target_lang=target_lang,
            translation=data.get("translation", ""),
            pronunciation=data.get("pronunciation", "") if self.cfg.ai.show_pronunciation else "",
            casual=data.get("casual", ""),
            polite=data.get("polite", ""),
        )
