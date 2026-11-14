"""Text-to-speech engines with a fallback chain and in-memory cache."""

from __future__ import annotations

from abc import ABC, abstractmethod
from collections import OrderedDict
from dataclasses import dataclass


@dataclass(slots=True)
class SpeechAudio:
    pcm16: bytes
    sample_rate: int


class TTSEngine(ABC):
    name: str = "base"

    @abstractmethod
    async def synthesize(self, text: str, lang: str) -> SpeechAudio: ...


class FallbackTTS(TTSEngine):
    """Tries engines in order (edge -> gemini -> sapi) and caches results by (text, lang)."""

    name = "fallback"

    def __init__(self, engines: list[TTSEngine], max_cache: int = 64) -> None:
        self.engines = engines
        self._max_cache = max_cache
        self._cache: OrderedDict[tuple[str, str], SpeechAudio] = OrderedDict()

    def clear_cache(self) -> None:
        self._cache.clear()

    async def synthesize(self, text: str, lang: str) -> SpeechAudio:
        key = (text, lang)
        if key in self._cache:
            self._cache.move_to_end(key)
            return self._cache[key]
        last_error: Exception | None = None
        for engine in self.engines:
            try:
                audio = await engine.synthesize(text, lang)
                self._cache[key] = audio
                while len(self._cache) > self._max_cache:
                    self._cache.popitem(last=False)
                return audio
            except Exception as e:  # noqa: BLE001 – try next engine
                last_error = e
        raise RuntimeError(f"all TTS engines failed: {last_error}")
