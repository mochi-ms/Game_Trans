"""Gemini TTS engine (optional).

Model: ``gemini-3.8-flash-lite-tts`` – billed per audio output token (25 tokens/s).
Free-tier limits for TTS are very low, so this is meant for credit-linked (Tier 1) projects.
"""

from __future__ import annotations

import io
import wave

from google.genai import types

from .base import SpeechAudio, TTSEngine


class GeminiTTS(TTSEngine):
    name = "gemini"

    def __init__(self, gemini_client, model: str = "gemini-3.8-flash-lite-tts", voice: str = "Puck") -> None:
        self.gemini_client = gemini_client
        self.model = model
        self.voice = voice

    async def synthesize(self, text: str, lang: str) -> SpeechAudio:
        if self.gemini_client is None:
            raise RuntimeError("Gemini client is not configured")
        await self.gemini_client.limiter.acquire()
        config = types.GenerateContentConfig(
            response_modalities=["AUDIO"],
            speech_config=types.SpeechConfig(
                voice_config=types.VoiceConfig(
                    prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=self.voice)
                )
            ),
        )
        resp = await self.gemini_client.client.aio.models.generate_content(
            model=self.model, contents=text, config=config
        )
        if resp.usage_metadata:
            u = resp.usage_metadata
            out = (u.candidates_token_count or 0) + (u.thoughts_token_count or 0)
            self.gemini_client.meter.record(u.prompt_token_count or 0, out)

        raw = b""
        for cand in resp.candidates or ():
            for part in (cand.content.parts if cand.content else ()) or ():
                if part.inline_data and part.inline_data.data:
                    raw = part.inline_data.data
                    break
            if raw:
                break
        if not raw:
            raise RuntimeError("Gemini TTS returned empty audio")

        if raw[:4] == b"RIFF":
            with wave.open(io.BytesIO(raw), "rb") as w:
                return SpeechAudio(pcm16=w.readframes(w.getnframes()), sample_rate=w.getframerate())
        return SpeechAudio(pcm16=raw, sample_rate=24_000)
