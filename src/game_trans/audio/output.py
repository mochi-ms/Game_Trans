"""Virtual microphone output & optional physical microphone mixer.

Plays TTS audio to ``CABLE Input (VB-Audio Virtual Cable)`` so the game hears it as mic input,
optionally mirrored to a monitor device (your headset). Also supports an optional live mic
passthrough mixer that blends the physical microphone into VB-Cable and ducks it during TTS.
"""

from __future__ import annotations

import logging
import math
import threading

import numpy as np
import sounddevice as sd
from scipy.signal import resample_poly

log = logging.getLogger(__name__)


_HOSTAPI_RANK = {"Windows WASAPI": 0, "Windows WDM-KS": 1, "Windows DirectSound": 2, "MME": 3}
_GENERIC_NAMES = ("microsoft 사운드 매퍼", "microsoft sound mapper", "주 사운드 드라이버", "primary sound driver")


def _hostapi_name(dev: dict, apis: list[dict]) -> str:
    idx = int(dev.get("hostapi", 0))
    return str(apis[idx]["name"]) if 0 <= idx < len(apis) else ""


def refresh_audio_devices() -> None:
    """Reload PortAudio's cached device list (e.g. after installing VB-Cable)."""
    sd._terminate()
    sd._initialize()


def list_output_devices() -> list[tuple[int, str]]:
    apis = sd.query_hostapis()
    chosen: dict[str, tuple[int, int, str]] = {}
    fallback: list[tuple[int, str]] = []
    for idx, dev in enumerate(sd.query_devices()):
        if dev["max_output_channels"] <= 0:
            continue
        name = str(dev["name"]).strip()
        low = name.lower()
        fallback.append((idx, name))
        if any(low.startswith(g) for g in _GENERIC_NAMES):
            continue
        rank = _HOSTAPI_RANK.get(_hostapi_name(dev, apis), 9)
        # MME truncates names at 31 chars, so match prefix when deduping
        key = low[:28]
        prev = chosen.get(key)
        if prev is None or (rank, -len(name)) < (prev[0], -len(prev[2])):
            chosen[key] = (rank, idx, name)
    if chosen:
        return [(idx, name) for _rank, idx, name in chosen.values()]
    return fallback


def list_input_devices() -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    for idx, dev in enumerate(sd.query_devices()):
        if dev["max_input_channels"] > 0:
            out.append((idx, str(dev["name"])))
    return out


def find_output_device(name_part: str) -> int | None:
    if not name_part:
        return None
    apis = sd.query_hostapis()
    best: tuple[int, int] | None = None
    for idx, dev in enumerate(sd.query_devices()):
        if dev["max_output_channels"] > 0 and name_part.lower() in str(dev["name"]).lower():
            rank = _HOSTAPI_RANK.get(_hostapi_name(dev, apis), 9)
            if best is None or rank < best[0]:
                best = (rank, idx)
    return best[1] if best is not None else None


def find_input_device(name_part: str) -> int | None:
    if not name_part:
        return None
    for idx, dev in enumerate(sd.query_devices()):
        if dev["max_input_channels"] > 0 and name_part.lower() in str(dev["name"]).lower():
            return idx
    return None


def _resample_f32(mono: np.ndarray, src_rate: int, dst_rate: int) -> np.ndarray:
    if src_rate == dst_rate or mono.size == 0:
        return mono
    g = math.gcd(int(src_rate), int(dst_rate))
    return resample_poly(mono, int(dst_rate) // g, int(src_rate) // g).astype(np.float32)


class VirtualMicOutput:
    def __init__(
        self,
        device_name: str = "CABLE Input",
        monitor_name: str = "",
        mix_microphone: bool = False,
        mic_device: str = "",
    ) -> None:
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None
        self._playing = False
        self._mic_stream: sd.Stream | None = None
        self.device: int | None = None
        self.monitor: int | None = None
        self.configure(device_name, monitor_name, mix_microphone, mic_device)

    def configure(
        self,
        device_name: str = "CABLE Input",
        monitor_name: str = "",
        mix_microphone: bool = False,
        mic_device: str = "",
    ) -> None:
        self.stop_mixer()
        self.device = find_output_device(device_name)
        self.monitor = find_output_device(monitor_name) if monitor_name else None
        if mix_microphone and self.device is not None:
            self._start_mixer(mic_device)

    @property
    def available(self) -> bool:
        return self.device is not None

    @property
    def is_playing(self) -> bool:
        return self._playing

    def _start_mixer(self, mic_name: str) -> None:
        mic_idx = find_input_device(mic_name) if mic_name else sd.default.device[0]
        if mic_idx is None or self.device is None:
            return
        try:
            out_info = sd.query_devices(self.device)
            rate = int(out_info["default_samplerate"])
            channels = min(2, int(out_info["max_output_channels"]))
            in_info = sd.query_devices(mic_idx)
            in_ch = min(channels, int(in_info["max_input_channels"]))

            def _cb(indata, outdata, _frames, _time, _status):
                gain = 0.12 if self._playing else 1.0
                if in_ch == channels:
                    outdata[:] = indata * gain
                else:
                    outdata[:] = indata[:, :1] * gain

            self._mic_stream = sd.Stream(
                device=(mic_idx, self.device),
                samplerate=rate,
                channels=(in_ch, channels),
                dtype="float32",
                callback=_cb,
            )
            self._mic_stream.start()
        except Exception as e:  # noqa: BLE001
            log.warning("Could not start mic passthrough mixer: %s", e)
            self._mic_stream = None

    def stop_mixer(self) -> None:
        if self._mic_stream is not None:
            try:
                self._mic_stream.stop()
                self._mic_stream.close()
            except Exception as e:  # noqa: BLE001
                log.debug("Failed stopping mic passthrough stream: %s", e)
            self._mic_stream = None

    def _play_on_device(self, dev_idx: int, mono_f32: np.ndarray, sample_rate: int) -> None:
        info = sd.query_devices(dev_idx)
        dst_rate = int(info["default_samplerate"])
        channels = min(2, int(info["max_output_channels"]))
        resampled = _resample_f32(mono_f32, sample_rate, dst_rate)
        if channels == 2:
            buf = np.column_stack([resampled, resampled])
        else:
            buf = resampled.reshape(-1, 1)

        cursor = 0
        done = threading.Event()

        def _callback(outdata, frames, _time, _status):
            nonlocal cursor
            if self._stop_event.is_set() or cursor >= len(buf):
                outdata.fill(0)
                done.set()
                raise sd.CallbackStop()
            end = min(cursor + frames, len(buf))
            count = end - cursor
            outdata[:count] = buf[cursor:end]
            if count < frames:
                outdata[count:] = 0
                done.set()
                raise sd.CallbackStop()
            cursor = end

        with sd.OutputStream(
            device=dev_idx,
            samplerate=dst_rate,
            channels=channels,
            dtype="float32",
            callback=_callback,
        ):
            while not done.is_set() and not self._stop_event.is_set():
                done.wait(timeout=0.05)

    def play(self, pcm: bytes, sample_rate: int, on_finished=None) -> None:
        """Non-blocking playback on virtual cable (and optional monitor device)."""
        if not self.available:
            raise RuntimeError("CABLE Input(VB-Cable) 장치를 찾지 못했습니다.")
        self.stop()
        mono_f32 = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
        self._stop_event.clear()
        self._playing = True

        def _worker() -> None:
            try:
                targets = [self.device]
                if self.monitor is not None and self.monitor != self.device:
                    targets.append(self.monitor)
                threads = [
                    threading.Thread(
                        target=self._play_on_device,
                        args=(idx, mono_f32, sample_rate),
                        daemon=True,
                    )
                    for idx in targets
                    if idx is not None
                ]
                for t in threads:
                    t.start()
                for t in threads:
                    t.join()
            finally:
                self._playing = False
                if on_finished is not None:
                    on_finished()

        with self._lock:
            self._thread = threading.Thread(target=_worker, daemon=True)
            self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        t = self._thread
        if t is not None and t.is_alive() and t is not threading.current_thread():
            t.join(timeout=0.5)
        self._thread = None
        self._playing = False

    def close(self) -> None:
        self.stop()
        self.stop_mixer()
