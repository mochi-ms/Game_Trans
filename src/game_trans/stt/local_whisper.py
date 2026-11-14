"""Local speech-to-text (optional fallback / Local mode).

Uses ``faster-whisper`` (``small`` int8 on CPU, or GPU when CUDA is available).
Install with ``pip install -e .[local]``.
"""

from __future__ import annotations

import numpy as np

from ..events import Segment


class LocalWhisper:
    def __init__(self, model_size: str = "small", device: str = "auto") -> None:
        self.model_size = model_size
        self.device = device
        self._model = None

    def _ensure_model(self):
        if self._model is not None:
            return self._model
        try:
            from faster_whisper import WhisperModel
        except ImportError as e:
            raise RuntimeError(
                "로컬 STT(faster-whisper)가 설치되지 않았습니다. 'pip install -e .[local]'로 설치하세요."
            ) from e
        compute_type = "int8" if self.device in ("auto", "cpu") else "float16"
        self._model = WhisperModel(self.model_size, device=self.device, compute_type=compute_type)
        return self._model

    def transcribe(self, segment: Segment) -> tuple[str, str]:
        """Return ``(language, text)`` from a 16 kHz mono PCM16 segment."""
        model = self._ensure_model()
        audio = np.frombuffer(segment.pcm16, dtype=np.int16).astype(np.float32) / 32768.0
        segments, info = model.transcribe(audio, vad_filter=False, beam_size=1)
        text = " ".join(s.text.strip() for s in segments).strip()
        return (getattr(info, "language", "") or ""), text
