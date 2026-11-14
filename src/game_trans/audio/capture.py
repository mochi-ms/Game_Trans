"""Game audio capture.

Primary: WASAPI *process loopback* (Windows 10 build 20348+ / Windows 11) via ``proctap`` –
captures only the target game's audio (``RobloxPlayerBeta.exe``). The game process is only
*looked up* by name via ``psutil``; no handle is opened and its memory is never touched.

Fallback: device loopback of the default output via ``PyAudioWPatch``.
"""

from __future__ import annotations

import logging
import math
import threading
from abc import ABC, abstractmethod
from collections.abc import Callable

import numpy as np
import psutil
from scipy.signal import resample_poly

log = logging.getLogger(__name__)

FrameCallback = Callable[[bytes], None]  # 16 kHz mono PCM16 chunks (~10 ms)
TARGET_SAMPLE_RATE = 16_000


def find_game_pid(process_names: list[str]) -> int | None:
    wanted = {n.lower() for n in process_names}
    for proc in psutil.process_iter(["pid", "name"]):
        if (proc.info.get("name") or "").lower() in wanted:
            return proc.info["pid"]
    return None


def list_audio_processes() -> list[tuple[int, str]]:
    """Return unique running ``(pid, name)`` pairs suitable for the settings dropdown."""
    seen: set[str] = set()
    items: list[tuple[int, str]] = []
    for proc in psutil.process_iter(["pid", "name"]):
        name = proc.info.get("name") or ""
        low = name.lower()
        if not name or not low.endswith(".exe") or low in seen:
            continue
        seen.add(low)
        items.append((int(proc.info["pid"]), name))
    items.sort(key=lambda item: item[1].lower())
    return items


def to_16k_mono_pcm16(samples: np.ndarray, sample_rate: int, channels: int = 1) -> bytes:
    """Convert float32/int16 interleaved audio into 16 kHz mono PCM16 bytes."""
    if samples.size == 0:
        return b""
    arr = samples
    if arr.dtype == np.int16:
        arr = arr.astype(np.float32) / 32768.0
    else:
        arr = arr.astype(np.float32, copy=False)

    if channels > 1:
        usable = (arr.size // channels) * channels
        if usable == 0:
            return b""
        arr = arr[:usable].reshape(-1, channels).mean(axis=1)

    if sample_rate != TARGET_SAMPLE_RATE and arr.size > 0:
        g = math.gcd(TARGET_SAMPLE_RATE, int(sample_rate))
        up = TARGET_SAMPLE_RATE // g
        down = int(sample_rate) // g
        arr = resample_poly(arr, up, down)

    clipped = np.clip(arr * 32767.0, -32768.0, 32767.0).astype(np.int16)
    return clipped.tobytes()


def compute_rms_level(pcm16: bytes) -> float:
    """Return normalized RMS level in ``0.0 .. 1.0`` for UI meters."""
    if not pcm16:
        return 0.0
    arr = np.frombuffer(pcm16, dtype=np.int16).astype(np.float32) / 32768.0
    rms = float(np.sqrt(np.mean(arr * arr))) if arr.size else 0.0
    return min(1.0, rms * 3.5)


class AudioCapture(ABC):
    @abstractmethod
    def start(self, on_frames: FrameCallback) -> None: ...

    @abstractmethod
    def stop(self) -> None: ...


class ProcessLoopbackCapture(AudioCapture):
    """WASAPI per-process loopback via ``proctap`` (48 kHz stereo float32 -> 16 kHz mono PCM16)."""

    def __init__(self, pid: int) -> None:
        self.pid = pid
        self._tap = None
        self._on_frames: FrameCallback | None = None

    def start(self, on_frames: FrameCallback) -> None:
        from proctap import ProcessAudioCapture

        self._on_frames = on_frames

        def _handle(pcm_bytes: bytes, _num_frames: int) -> None:
            if not pcm_bytes or self._on_frames is None:
                return
            arr = np.frombuffer(pcm_bytes, dtype=np.float32)
            out = to_16k_mono_pcm16(arr, sample_rate=48_000, channels=2)
            if out:
                self._on_frames(out)

        self._tap = ProcessAudioCapture(pid=self.pid, on_data=_handle, resample_quality="medium")
        self._tap.start()

    def stop(self) -> None:
        tap = self._tap
        self._tap = None
        self._on_frames = None
        if tap is not None:
            try:
                tap.stop()
            except Exception:
                log.exception("Failed stopping ProcessAudioCapture")


class DeviceLoopbackCapture(AudioCapture):
    """Fallback capture using PyAudioWPatch default WASAPI loopback device."""

    def __init__(self) -> None:
        self._pa = None
        self._stream = None
        self._stop_event = threading.Event()
        self._on_frames: FrameCallback | None = None
        self._sample_rate = 48_000
        self._channels = 2

    def start(self, on_frames: FrameCallback) -> None:
        import pyaudiowpatch as pa

        self._stop_event.clear()
        self._on_frames = on_frames
        self._pa = pa.PyAudio()
        dev = self._pa.get_default_wasapi_loopback()
        if not dev:
            self.stop()
            raise RuntimeError("기본 WASAPI 루프백 오디오 장치를 찾지 못했습니다.")

        self._sample_rate = int(dev["defaultSampleRate"])
        self._channels = max(1, int(dev["maxInputChannels"]))
        frames_per_buffer = max(256, self._sample_rate // 50)  # ~20 ms

        def _callback(in_data, _frame_count, _time_info, _status):
            if self._stop_event.is_set():
                return (None, pa.paComplete)
            if in_data and self._on_frames is not None:
                arr = np.frombuffer(in_data, dtype=np.int16)
                out = to_16k_mono_pcm16(arr, sample_rate=self._sample_rate, channels=self._channels)
                if out:
                    self._on_frames(out)
            return (None, pa.paContinue)

        self._stream = self._pa.open(
            format=pa.paInt16,
            channels=self._channels,
            rate=self._sample_rate,
            frames_per_buffer=frames_per_buffer,
            input=True,
            input_device_index=int(dev["index"]),
            stream_callback=_callback,
        )
        self._stream.start_stream()

    def stop(self) -> None:
        self._stop_event.set()
        self._on_frames = None
        if self._stream is not None:
            try:
                self._stream.stop_stream()
                self._stream.close()
            except Exception as e:  # noqa: BLE001
                log.debug("Failed closing loopback stream: %s", e)
            self._stream = None
        if self._pa is not None:
            try:
                self._pa.terminate()
            except Exception as e:  # noqa: BLE001
                log.debug("Failed terminating PyAudio: %s", e)
            self._pa = None
