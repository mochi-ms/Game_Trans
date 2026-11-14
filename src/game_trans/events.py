"""Event payloads shared across pipelines.

The runtime bus will be a QObject with Qt Signals (Phase 1); payloads stay plain dataclasses
so that audio / AI modules don't depend on Qt.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from enum import Enum


class Mode(Enum):
    CLOUD = "cloud"
    LOCAL = "local"


@dataclass(slots=True)
class Segment:
    """One VAD-detected utterance (16 kHz mono PCM16)."""

    id: int
    pcm16: bytes
    sample_rate: int = 16_000
    started_at: float = field(default_factory=time.monotonic)

    @property
    def duration_s(self) -> float:
        return len(self.pcm16) / 2 / self.sample_rate


@dataclass(slots=True)
class Caption:
    """Result of the listen pipeline (incoming speech)."""

    segment_id: int
    is_speech: bool
    source_lang: str
    transcript: str
    translation: str
    confidence: float = 1.0


@dataclass(slots=True)
class OutgoingTranslation:
    """Result of the speak pipeline (my typed text)."""

    source_text: str
    target_lang: str
    translation: str
    pronunciation: str = ""
    casual: str = ""
    polite: str = ""
