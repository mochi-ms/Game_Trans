"""Voice activity detection & utterance segmentation.

Primary detector: Silero VAD v5/v6 via ``onnxruntime`` (cached under
``%APPDATA%\\GameTrans\\models\\silero_vad.onnx``).
Fallback detector: lightweight speech-band spectral VAD (NumPy + SciPy) when
``onnxruntime`` or the model file isn't available (e.g., offline or missing VC++ runtime).

State machine per 32 ms frame (512 samples @ 16 kHz):
    IDLE --(p>=threshold)--> SPEAKING --(silence >= silence_end_ms)--> emit Segment -> IDLE
                                     \\--(len >= max_segment_s)--> emit Segment (forced split)
Segments shorter than ``min_speech_ms`` are dropped; ``pre_roll_ms`` of audio before the
speech start is prepended so the first syllable isn't clipped.
"""

from __future__ import annotations

import logging
import urllib.request
from collections import deque
from collections.abc import Callable
from pathlib import Path

import numpy as np
from scipy.signal import butter, sosfilt

from ..config import Audio, app_dir
from ..events import Segment

log = logging.getLogger(__name__)

SAMPLE_RATE = 16_000
FRAME_SAMPLES = 512  # 32 ms at 16 kHz
FRAME_MS = 32
SILERO_URL = "https://raw.githubusercontent.com/snakers4/silero-vad/master/src/silero_vad/data/silero_vad.onnx"

SegmentCallback = Callable[[Segment], None]


def silero_model_path() -> Path:
    return app_dir() / "models" / "silero_vad.onnx"


def ensure_silero_model(download: bool = True) -> Path | None:
    path = silero_model_path()
    if path.exists() and path.stat().st_size > 100_000:
        return path
    if not download:
        return None
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        urllib.request.urlretrieve(SILERO_URL, tmp)
        tmp.replace(path)
        return path
    except Exception as e:  # noqa: BLE001
        log.warning("Could not fetch Silero VAD model (%s); using spectral VAD fallback", e)
        return None


class _SileroDetector:
    """Silero VAD v5/v6 ONNX runner with 64-sample context window."""

    def __init__(self, model_path: Path) -> None:
        import onnxruntime as ort

        opts = ort.SessionOptions()
        opts.inter_op_num_threads = 1
        opts.intra_op_num_threads = 1
        self._session = ort.InferenceSession(
            str(model_path), sess_options=opts, providers=["CPUExecutionProvider"]
        )
        self._input_names = [i.name for i in self._session.get_inputs()]
        self._context = np.zeros(64, dtype=np.float32)
        self._state = np.zeros((2, 1, 128), dtype=np.float32)
        self._sr = np.array(SAMPLE_RATE, dtype=np.int64)
        self._expects_3d = len(self._session.get_inputs()[0].shape) == 3

    def reset(self) -> None:
        self._context.fill(0.0)
        self._state.fill(0.0)

    def probability(self, frame_f32: np.ndarray) -> float:
        x = np.concatenate([self._context, frame_f32])
        self._context = frame_f32[-64:].copy()
        inp = x[np.newaxis, np.newaxis, :] if self._expects_3d else x[np.newaxis, :]
        feeds = {"input": inp, "state": self._state}
        if "sr" in self._input_names:
            sr_shape = self._session.get_inputs()[self._input_names.index("sr")].shape
            feeds["sr"] = self._sr.reshape((1,)) if sr_shape else self._sr
        out, next_state = self._session.run(None, feeds)
        self._state = next_state
        return float(np.asarray(out).reshape(-1)[0])


class _SpectralDetector:
    """Zero-dependency speech-band (300–3400 Hz) + adaptive noise floor VAD."""

    def __init__(self) -> None:
        self._window = np.hanning(FRAME_SAMPLES).astype(np.float32)
        freqs = np.fft.rfftfreq(FRAME_SAMPLES, 1.0 / SAMPLE_RATE)
        self._speech_mask = (freqs >= 300.0) & (freqs <= 3400.0)
        self._noise_floor = 0.008

    def reset(self) -> None:
        self._noise_floor = 0.008

    def probability(self, frame_f32: np.ndarray) -> float:
        spec = np.abs(np.fft.rfft(frame_f32 * self._window))
        power = spec * spec
        total_e = float(np.sum(power)) + 1e-12
        speech_e = float(np.sum(power[self._speech_mask]))
        speech_ratio = speech_e / total_e
        speech_rms = float(np.sqrt(speech_e / FRAME_SAMPLES))

        # Adapt noise floor slowly when frame doesn't strongly look like speech
        if speech_rms < self._noise_floor * 2.2 or speech_ratio < 0.40:
            self._noise_floor = 0.96 * self._noise_floor + 0.04 * max(0.004, min(speech_rms, 0.06))

        snr = speech_rms / max(self._noise_floor, 0.004)
        # Map SNR (above 2.2x noise floor) and speech_band concentration into 0..1
        if speech_rms < 0.009 or speech_ratio < 0.35:
            return min(0.3, snr * 0.08)
        snr_score = min(1.0, max(0.0, (snr - 1.6) / 2.8))
        band_score = min(1.0, max(0.0, (speech_ratio - 0.30) / 0.45))
        return float(0.65 * snr_score + 0.35 * band_score)


class VadSegmenter:
    def __init__(
        self,
        cfg: Audio,
        on_segment: SegmentCallback,
        allow_download: bool = True,
        force_spectral: bool = False,
    ) -> None:
        self.cfg = cfg
        self.on_segment = on_segment
        self._byte_buf = bytearray()
        self._next_id = 1
        self._speaking = False
        self._speech_frames = 0
        self._silence_frames = 0
        self._active_frames: list[bytes] = []
        pre_count = max(1, cfg.pre_roll_ms // FRAME_MS)
        self._pre_roll: deque[bytes] = deque(maxlen=pre_count)
        self._bandpass_sos = butter(4, [300.0, 3400.0], btype="bandpass", fs=SAMPLE_RATE, output="sos")
        self._bandpass_zi = None
        self._detector = self._init_detector(allow_download=allow_download, force_spectral=force_spectral)

    def _init_detector(self, allow_download: bool, force_spectral: bool):
        if not force_spectral:
            try:
                path = ensure_silero_model(download=allow_download)
                if path is not None:
                    det = _SileroDetector(path)
                    log.info("VAD initialized with Silero ONNX (%s)", path)
                    return det
            except Exception as e:  # noqa: BLE001
                log.warning("Silero VAD unavailable (%s); falling back to spectral VAD", e)
        return _SpectralDetector()

    @property
    def backend_name(self) -> str:
        return "silero" if isinstance(self._detector, _SileroDetector) else "spectral"

    def reset(self) -> None:
        self._byte_buf.clear()
        self._speaking = False
        self._speech_frames = 0
        self._silence_frames = 0
        self._active_frames.clear()
        self._pre_roll.clear()
        self._bandpass_zi = None
        self._detector.reset()

    def _detect_prob(self, frame_bytes: bytes) -> float:
        f32 = np.frombuffer(frame_bytes, dtype=np.int16).astype(np.float32) / 32768.0
        if self.cfg.bgm_suppression:
            if self._bandpass_zi is None:
                filtered, self._bandpass_zi = sosfilt(
                    self._bandpass_sos, f32, zi=np.zeros((self._bandpass_sos.shape[0], 2), dtype=np.float64)
                )
            else:
                filtered, self._bandpass_zi = sosfilt(self._bandpass_sos, f32, zi=self._bandpass_zi)
            f32 = filtered.astype(np.float32)
        return self._detector.probability(f32)

    def _emit_active(self, trim_tail: bool) -> None:
        frames = self._active_frames
        if trim_tail and self._silence_frames > 4:
            # Keep a 4-frame (~128 ms) natural tail rather than full silence_end_ms
            cut = self._silence_frames - 4
            frames = frames[:-cut] if cut < len(frames) else frames
        if self._speech_frames * FRAME_MS >= self.cfg.min_speech_ms and frames:
            seg = Segment(id=self._next_id, pcm16=b"".join(frames), sample_rate=SAMPLE_RATE)
            self._next_id += 1
            self.on_segment(seg)
        self._speaking = False
        self._speech_frames = 0
        self._silence_frames = 0
        self._active_frames.clear()
        self._pre_roll.clear()

    def feed(self, pcm16: bytes) -> None:
        if not pcm16:
            return
        self._byte_buf.extend(pcm16)
        frame_bytes_len = FRAME_SAMPLES * 2
        silence_limit = max(1, self.cfg.silence_end_ms // FRAME_MS)
        max_frames = max(1, int(self.cfg.max_segment_s * 1000 // FRAME_MS))

        while len(self._byte_buf) >= frame_bytes_len:
            frame = bytes(self._byte_buf[:frame_bytes_len])
            del self._byte_buf[:frame_bytes_len]
            prob = self._detect_prob(frame)

            if not self._speaking:
                if prob >= self.cfg.speech_threshold:
                    self._speaking = True
                    self._speech_frames = 1
                    self._silence_frames = 0
                    self._active_frames = [*self._pre_roll, frame]
                    self._pre_roll.clear()
                else:
                    self._pre_roll.append(frame)
            else:
                self._active_frames.append(frame)
                if prob >= self.cfg.speech_threshold:
                    self._speech_frames += 1
                    self._silence_frames = 0
                else:
                    self._silence_frames += 1

                if self._silence_frames >= silence_limit:
                    self._emit_active(trim_tail=True)
                elif len(self._active_frames) >= max_frames:
                    self._emit_active(trim_tail=False)

    def flush(self) -> None:
        if self._speaking:
            self._emit_active(trim_tail=True)
