"""Python <-> QML bridge driving audio capture, VAD, Gemini translation, TTS and overlay state."""

from __future__ import annotations

import asyncio
import datetime as dt
import logging
import queue
import threading
from collections import deque

from PySide6.QtCore import Property, QObject, Qt, QTimer, Signal, Slot
from PySide6.QtGui import QGuiApplication

from ..ai.gemini_client import GeminiClient, QuotaExceeded
from ..ai.usage import UsageMeter, UsageStore
from ..audio.capture import (
    AudioCapture,
    DeviceLoopbackCapture,
    ProcessLoopbackCapture,
    compute_rms_level,
    find_game_pid,
    list_audio_processes,
)
from ..audio.output import VirtualMicOutput, list_output_devices, refresh_audio_devices
from ..audio.vad import VadSegmenter
from ..config import (
    Config,
    load_glossary,
    load_phrases,
    save_config,
    save_glossary,
    save_phrases,
)
from ..events import Caption, Segment
from ..platform import secrets
from ..platform.window import (
    focus_window,
    get_foreground_hwnd,
    restore_foreground,
    set_click_through,
    set_dark_titlebar,
    set_no_activate,
)
from ..stt.local_whisper import LocalWhisper
from ..tts.base import FallbackTTS, TTSEngine
from ..tts.edge import EdgeTTS
from ..tts.gemini_tts import GeminiTTS
from ..tts.sapi import SapiTTS

log = logging.getLogger(__name__)

_LANG_CYCLE = ["en", "ja", "zh", "es", "pt", "fr", "de", "ko"]
_TONE_CYCLE = ["casual", "neutral", "polite"]


class Backend(QObject):
    # State signals
    stateChanged = Signal()
    overlayLayoutChanged = Signal()
    usageChanged = Signal()
    phrasesChanged = Signal()
    historyChanged = Signal()
    devicesChanged = Signal()
    composerChanged = Signal()
    settingsChanged = Signal()
    historyWindowChanged = Signal()
    toastChanged = Signal()
    audioLevelChanged = Signal()
    ttsStateChanged = Signal()

    # Action / pipeline signals to QML
    captionStarted = Signal(int)
    captionTranslating = Signal(int)
    captionReady = Signal(int, str, str, str, float)
    captionDismissed = Signal(int)
    historyCleared = Signal()
    outgoingStarted = Signal()
    outgoingReady = Signal(str, str, str, str, str, str)
    outgoingFailed = Signal(str)
    focusInputRequested = Signal()
    apiKeyTestResult = Signal(bool, str)

    def __init__(
        self,
        cfg: Config,
        meter: UsageMeter,
        store: UsageStore | None,
        loop: asyncio.AbstractEventLoop,
    ) -> None:
        super().__init__()
        self.cfg = cfg
        self.meter = meter
        self.store = store
        self.loop = loop

        self._api_key = secrets.get_api_key()
        self.gemini: GeminiClient | None = (
            GeminiClient(self._api_key, cfg, meter) if self._api_key else None
        )
        self._phrases = load_phrases()
        self._glossary = load_glossary()
        if self.gemini is not None:
            self.gemini.glossary = list(self._glossary)

        self._local_whisper = LocalWhisper()
        self._vad = VadSegmenter(cfg.audio, self._on_vad_segment)
        self._output = VirtualMicOutput(
            device_name=cfg.voice_out.output_device,
            monitor_name=cfg.voice_out.monitor_device,
            mix_microphone=cfg.voice_out.mix_microphone,
            mic_device=cfg.voice_out.mic_device,
        )
        self._tts = self._build_tts()

        # Runtime state
        self._listening = False
        self._edit_mode = False
        self._overlay_visible = True
        self._composer_open = False
        self._settings_open = not bool(self._api_key)
        self._history_open = False
        self._status_level = "paused" if self._api_key else "error"
        self._status_text = f"일시정지 · {cfg.hotkeys.toggle_listen}" if self._api_key else "API 키 설정 필요"
        self._detected_partner_lang = "en"
        self._toast_text = ""
        self._audio_level = 0.0
        self._latest_rms = 0.0
        self._tts_playing = False
        self._last_outgoing_text = ""
        self._last_outgoing_lang = "en"
        self._history: list[dict[str, str]] = []
        self._test_caption_seq = 0
        self._quota_errors_recent: deque[float] = deque(maxlen=10)
        self._running_processes: list[str] = []

        # Window tracking
        self._caption_win = None
        self._status_win = None
        self._input_win = None
        self._prev_fg_hwnd = 0

        # Audio threads & async queue
        self._capture: AudioCapture | None = None
        self._vad_queue: queue.Queue[bytes | None] = queue.Queue(maxsize=120)
        self._vad_thread: threading.Thread | None = None
        self._seg_deque: deque[Segment] = deque()
        self._seg_event = asyncio.Event()
        self._worker_task: asyncio.Task | None = None
        self._bg_tasks: set[asyncio.Task] = set()

        # Timers
        self._toast_timer = QTimer(self)
        self._toast_timer.setSingleShot(True)
        self._toast_timer.timeout.connect(self._clear_toast)

        self._level_timer = QTimer(self)
        self._level_timer.setInterval(80)
        self._level_timer.timeout.connect(self._tick_ui)
        self._level_timer.start()

        self._game_timer = QTimer(self)
        self._game_timer.setInterval(3000)
        self._game_timer.timeout.connect(self._check_game_process)
        self._game_timer.start()

    # ------------------------------------------------------------------ startup / shutdown

    def start_background(self) -> None:
        self.refreshRunningProcesses()
        if self._worker_task is None:
            self._worker_task = self.loop.create_task(self._listen_worker())
        if self._api_key and self.cfg.general.auto_listen_on_game_start:
            self._start_listening(auto=True)

    def shutdown(self) -> None:
        self._stop_listening()
        self._output.close()
        if self._worker_task is not None:
            self._worker_task.cancel()
            self._worker_task = None
        for task in list(self._bg_tasks):
            task.cancel()
        if self.store is not None:
            self.store.close()

    def _spawn(self, coro) -> asyncio.Task:
        task = self.loop.create_task(coro)
        self._bg_tasks.add(task)
        task.add_done_callback(self._bg_tasks.discard)
        return task

    def _build_tts(self) -> FallbackTTS:
        edge = EdgeTTS(voice=self.cfg.voice_out.voice, rate=self.cfg.voice_out.rate)
        gem = GeminiTTS(self.gemini) if self.gemini is not None else None
        sapi = SapiTTS()
        pref = self.cfg.voice_out.engine
        order: list[TTSEngine] = []
        if pref == "gemini" and gem is not None:
            order = [gem, edge, sapi]
        elif pref == "sapi":
            order = [sapi, edge]
        else:
            order = [e for e in (edge, gem, sapi) if e is not None]
        return FallbackTTS(order)

    # ------------------------------------------------------------------ window registration

    @Slot(QObject)
    def registerCaptionWindow(self, win) -> None:
        self._caption_win = win
        win.visibleChanged.connect(lambda: QTimer.singleShot(0, self._apply_caption_style))
        QTimer.singleShot(0, self._apply_caption_style)

    @Slot(QObject)
    def registerStatusWindow(self, win) -> None:
        self._status_win = win
        win.visibleChanged.connect(lambda: QTimer.singleShot(0, self._apply_status_style))
        QTimer.singleShot(0, self._apply_status_style)

    @Slot(QObject)
    def registerInputWindow(self, win) -> None:
        self._input_win = win

    @Slot(QObject)
    def registerDarkWindow(self, win) -> None:
        def _apply() -> None:
            try:
                set_dark_titlebar(int(win.winId()))
            except OSError:
                pass

        win.visibleChanged.connect(lambda: QTimer.singleShot(0, _apply))
        QTimer.singleShot(0, _apply)

    def _apply_caption_style(self) -> None:
        if self._caption_win is None or not self._caption_win.isVisible():
            return
        want_pass_through = self.cfg.overlay.click_through and not self._edit_mode
        try:
            self._caption_win.setFlag(Qt.WindowType.WindowTransparentForInput, want_pass_through)
            hwnd = int(self._caption_win.winId())
            if want_pass_through:
                set_click_through(hwnd, True)
            else:
                set_no_activate(hwnd)
        except (OSError, RuntimeError):
            pass

    def _apply_status_style(self) -> None:
        if self._status_win is None or not self._status_win.isVisible():
            return
        try:
            set_no_activate(int(self._status_win.winId()))
        except OSError:
            pass

    # ------------------------------------------------------------------ properties

    @Property(bool, notify=stateChanged)
    def hasApiKey(self) -> bool:
        return bool(self._api_key)

    @Property(str, notify=stateChanged)
    def maskedApiKey(self) -> str:
        return secrets.mask(self._api_key)

    @Property(bool, notify=stateChanged)
    def listening(self) -> bool:
        return self._listening

    @Property(bool, notify=stateChanged)
    def editMode(self) -> bool:
        return self._edit_mode

    @Property(bool, notify=stateChanged)
    def overlayVisible(self) -> bool:
        return self._overlay_visible

    @Property(str, notify=stateChanged)
    def statusLevel(self) -> str:
        return self._status_level

    @Property(str, notify=stateChanged)
    def statusText(self) -> str:
        return self._status_text

    @Property(str, notify=stateChanged)
    def aiModel(self) -> str:
        return self.cfg.ai.model

    @Property(str, notify=stateChanged)
    def aiMode(self) -> str:
        return self.cfg.ai.mode

    @Property(int, notify=stateChanged)
    def rpmLimit(self) -> int:
        return self.cfg.ai.rpm_limit

    @Property(bool, notify=stateChanged)
    def fallbackToLocal(self) -> bool:
        return self.cfg.ai.fallback_to_local_on_quota

    @Property(str, notify=stateChanged)
    def myLanguage(self) -> str:
        return self.cfg.general.my_language

    @Property(str, notify=stateChanged)
    def partnerLanguage(self) -> str:
        return self.cfg.general.partner_language

    @Property(str, notify=stateChanged)
    def effectivePartnerLang(self) -> str:
        if self.cfg.general.partner_language == "auto":
            return self._detected_partner_lang
        return self.cfg.general.partner_language

    @Property(str, notify=stateChanged)
    def tone(self) -> str:
        return self.cfg.ai.tone

    @Property(bool, notify=stateChanged)
    def showPronunciation(self) -> bool:
        return self.cfg.ai.show_pronunciation

    @Property(str, notify=stateChanged)
    def captureMode(self) -> str:
        return self.cfg.audio.capture

    @Property(str, notify=stateChanged)
    def targetProcessesText(self) -> str:
        return ", ".join(self.cfg.audio.target_processes)

    @Property(bool, notify=stateChanged)
    def bgmSuppression(self) -> bool:
        return self.cfg.audio.bgm_suppression

    @Property(str, notify=stateChanged)
    def vadBackend(self) -> str:
        return self._vad.backend_name

    @Property(str, notify=stateChanged)
    def vadPreset(self) -> str:
        if self.cfg.audio.silence_end_ms <= 320:
            return "fast"
        if self.cfg.audio.silence_end_ms >= 680:
            return "sentence"
        return "balanced"

    @Property("QVariantList", notify=devicesChanged)
    def runningProcesses(self) -> list[str]:
        return self._running_processes

    @Property(float, notify=audioLevelChanged)
    def audioLevel(self) -> float:
        return self._audio_level

    @Property(str, notify=overlayLayoutChanged)
    def overlayPosition(self) -> str:
        return self.cfg.overlay.position

    @Property(int, notify=overlayLayoutChanged)
    def overlayOffsetX(self) -> int:
        return self.cfg.overlay.offset_x

    @Property(int, notify=overlayLayoutChanged)
    def overlayOffsetY(self) -> int:
        return self.cfg.overlay.offset_y

    @Property(int, notify=overlayLayoutChanged)
    def captionFontSize(self) -> int:
        return self.cfg.overlay.font_size

    @Property(float, notify=overlayLayoutChanged)
    def overlayOpacity(self) -> float:
        return self.cfg.overlay.opacity

    @Property(int, notify=overlayLayoutChanged)
    def captionDurationS(self) -> int:
        return self.cfg.overlay.caption_duration_s

    @Property(int, notify=overlayLayoutChanged)
    def maxCaptions(self) -> int:
        return self.cfg.overlay.max_captions

    @Property(bool, notify=overlayLayoutChanged)
    def showOriginal(self) -> bool:
        return self.cfg.overlay.show_original

    @Property(bool, notify=overlayLayoutChanged)
    def showOutgoingInFeed(self) -> bool:
        return self.cfg.overlay.show_outgoing_in_feed

    @Property(bool, notify=overlayLayoutChanged)
    def autoCopyOutgoing(self) -> bool:
        return self.cfg.overlay.auto_copy_outgoing

    @Property(bool, notify=overlayLayoutChanged)
    def reduceMotion(self) -> bool:
        return self.cfg.overlay.reduce_motion

    @Property(bool, notify=overlayLayoutChanged)
    def overlayClickThrough(self) -> bool:
        return self.cfg.overlay.click_through

    @Property(bool, notify=devicesChanged)
    def vbCableAvailable(self) -> bool:
        return self._output.available

    @Property(str, notify=devicesChanged)
    def ttsEngine(self) -> str:
        return self.cfg.voice_out.engine

    @Property(str, notify=devicesChanged)
    def voiceOutDevice(self) -> str:
        return self.cfg.voice_out.output_device

    @Property(str, notify=devicesChanged)
    def monitorDevice(self) -> str:
        return self.cfg.voice_out.monitor_device

    @Property(bool, notify=devicesChanged)
    def mixMicrophone(self) -> bool:
        return self.cfg.voice_out.mix_microphone

    @Property("QVariantList", notify=devicesChanged)
    def outputDevices(self) -> list[str]:
        return [name for _idx, name in list_output_devices()]

    @Property(bool, notify=ttsStateChanged)
    def ttsPlaying(self) -> bool:
        return self._tts_playing

    @Property("QVariantList", notify=phrasesChanged)
    def quickPhrases(self) -> list[dict[str, str]]:
        return self._phrases

    @Property(str, notify=phrasesChanged)
    def glossaryText(self) -> str:
        return ", ".join(self._glossary)

    @Property("QVariantList", notify=historyChanged)
    def captionHistory(self) -> list[dict[str, str]]:
        return self._history

    @Property(int, notify=usageChanged)
    def rpm(self) -> int:
        return self.meter.requests_last_minute()

    @Property(int, notify=usageChanged)
    def requestsToday(self) -> int:
        return self.meter.today.requests

    @Property(float, notify=usageChanged)
    def costToday(self) -> float:
        return self.meter.today.cost_usd

    @Property(float, notify=usageChanged)
    def costMonth(self) -> float:
        return self.meter.month.cost_usd

    @Property(float, notify=usageChanged)
    def monthlyBudgetUsd(self) -> float:
        return self.cfg.budget.monthly_budget_usd

    @Property("QVariantList", notify=usageChanged)
    def usageBars(self) -> list[dict]:
        days = self.store.recent_days(12) if self.store is not None else [("", 0.0)] * 12
        peak = max((c for _d, c in days), default=0.0)
        return [{"day": d, "cost": c, "ratio": (c / peak) if peak > 0 else 0.0} for d, c in days]

    @Property(str, notify=stateChanged)
    def hotkeyToggleInput(self) -> str:
        return self.cfg.hotkeys.toggle_input

    @Property(str, notify=stateChanged)
    def hotkeyToggleListen(self) -> str:
        return self.cfg.hotkeys.toggle_listen

    @Property(str, notify=stateChanged)
    def hotkeyRepeatLast(self) -> str:
        return self.cfg.hotkeys.repeat_last

    @Property(str, notify=stateChanged)
    def hotkeyHistory(self) -> str:
        return self.cfg.hotkeys.history

    @Property(str, notify=stateChanged)
    def hotkeyEditOverlay(self) -> str:
        return self.cfg.hotkeys.edit_overlay

    @Property(str, notify=toastChanged)
    def toastText(self) -> str:
        return self._toast_text

    # Window visibility properties
    @Property(bool, notify=composerChanged)
    def composerOpen(self) -> bool:
        return self._composer_open

    @Property(bool, notify=settingsChanged)
    def settingsOpen(self) -> bool:
        return self._settings_open

    @settingsOpen.setter
    def settingsOpen(self, val: bool) -> None:
        if self._settings_open != val:
            self._settings_open = val
            self.settingsChanged.emit()

    @Property(bool, notify=historyWindowChanged)
    def historyOpen(self) -> bool:
        return self._history_open

    @historyOpen.setter
    def historyOpen(self, val: bool) -> None:
        if self._history_open != val:
            self._history_open = val
            self.historyWindowChanged.emit()

    # ------------------------------------------------------------------ UI actions / hotkeys

    def show_toast(self, msg: str, duration_ms: int = 2400) -> None:
        self._toast_text = msg
        self.toastChanged.emit()
        self._toast_timer.start(duration_ms)

    @Slot()
    def _clear_toast(self) -> None:
        self._toast_text = ""
        self.toastChanged.emit()

    @Slot(str)
    def copyText(self, text: str) -> None:
        if not text:
            return
        cb = QGuiApplication.clipboard()
        if cb is not None:
            cb.setText(text)
        self.show_toast("복사했어요 · 게임 채팅에 붙여넣으세요")

    @Slot()
    def openSettings(self) -> None:
        self.refreshRunningProcesses()
        self.settingsOpen = True

    @Slot()
    def toggleHistory(self) -> None:
        self.historyOpen = not self._history_open

    @Slot()
    def clearHistory(self) -> None:
        self._history.clear()
        self.historyChanged.emit()
        self.historyCleared.emit()

    @Slot()
    def toggleEditMode(self) -> None:
        self._edit_mode = not self._edit_mode
        self._apply_caption_style()
        self.stateChanged.emit()

    @staticmethod
    def _overlay_base_pos(pos: str, sw: float, sh: float, ww: float, wh: float) -> tuple[float, float]:
        if pos == "top-left":
            return 24.0, 24.0
        if pos == "bottom-right":
            return sw - ww - 28.0, sh - wh - 28.0
        if pos == "bottom-left":
            return 24.0, sh - wh - 28.0
        if pos == "bottom-center":
            return (sw - ww) / 2.0, sh - wh - 28.0
        # Default "top-right": aligned cleanly directly underneath StatusPill
        return sw - ww - 28.0, 66.0

    @Slot(float, float, float, float, float, float)
    def saveOverlayWindowPos(self, wx, wy, sw, sh, ww, wh) -> None:
        base_x, base_y = self._overlay_base_pos(self.cfg.overlay.position, sw, sh, ww, wh)
        self.cfg.overlay.offset_x = int(wx - base_x)
        self.cfg.overlay.offset_y = int(wy - base_y)
        self.cfg.overlay.layout_version = 2
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot()
    def toggleComposer(self) -> None:
        if self._composer_open:
            self.closeComposer()
        else:
            self.openComposer()

    @Slot()
    def openComposer(self) -> None:
        fg = get_foreground_hwnd()
        own = {
            int(w.winId())
            for w in (self._input_win, self._caption_win, self._status_win)
            if w is not None
        }
        if fg and fg not in own:
            self._prev_fg_hwnd = fg
        self._composer_open = True
        self.composerChanged.emit()
        if self._input_win is not None:
            QTimer.singleShot(20, lambda: focus_window(int(self._input_win.winId())))
            QTimer.singleShot(40, self.focusInputRequested.emit)

    @Slot()
    def closeComposer(self) -> None:
        if not self._composer_open:
            return
        self._composer_open = False
        self.composerChanged.emit()
        if self._prev_fg_hwnd:
            hwnd = self._prev_fg_hwnd
            self._prev_fg_hwnd = 0
            QTimer.singleShot(10, lambda: restore_foreground(hwnd))

    @Slot()
    def cycleTone(self) -> None:
        idx = (_TONE_CYCLE.index(self.cfg.ai.tone) + 1) % len(_TONE_CYCLE) if self.cfg.ai.tone in _TONE_CYCLE else 0
        self.cfg.ai.tone = _TONE_CYCLE[idx]
        save_config(self.cfg)
        self.stateChanged.emit()

    @Slot()
    def cyclePartnerLang(self) -> None:
        order = ["auto", *_LANG_CYCLE]
        cur = self.cfg.general.partner_language
        idx = (order.index(cur) + 1) % len(order) if cur in order else 0
        self.cfg.general.partner_language = order[idx]
        save_config(self.cfg)
        self.stateChanged.emit()

    # ------------------------------------------------------------------ Settings mutations

    @Slot(str)
    def saveAndTestApiKey(self, key: str) -> None:
        cleaned = key.strip()
        if not cleaned:
            self.apiKeyTestResult.emit(False, "API 키를 입력해 주세요")
            return
        self._spawn(self._test_and_store_key(cleaned))

    async def _test_and_store_key(self, key: str) -> None:
        probe = GeminiClient(key, self.cfg, self.meter)
        ok, msg = await probe.test_connection()
        if ok:
            secrets.set_api_key(key)
            self._api_key = key
            self.gemini = probe
            self.gemini.glossary = list(self._glossary)
            self._tts = self._build_tts()
            self.cfg.general.onboarding_done = True
            save_config(self.cfg)
            self._refresh_status()
            self.stateChanged.emit()
            if self.cfg.general.auto_listen_on_game_start and not self._listening:
                self._start_listening(auto=True)
        self.apiKeyTestResult.emit(ok, msg)

    @Slot(int)
    def setRpmLimit(self, rpm: int) -> None:
        self.cfg.ai.rpm_limit = max(1, rpm)
        if self.gemini is not None:
            self.gemini.update_config(self.cfg)
        save_config(self.cfg)
        self.stateChanged.emit()

    @Slot(str)
    def setAiModel(self, model: str) -> None:
        if model.strip():
            self.cfg.ai.model = model.strip()
            if self.gemini is not None:
                self.gemini.update_config(self.cfg)
            save_config(self.cfg)
            self.stateChanged.emit()

    @Slot(str)
    def setMyLanguage(self, lang: str) -> None:
        self.cfg.general.my_language = lang
        save_config(self.cfg)
        self._refresh_status()
        self.stateChanged.emit()

    @Slot(str)
    def setPartnerLanguage(self, lang: str) -> None:
        self.cfg.general.partner_language = lang
        save_config(self.cfg)
        self.stateChanged.emit()

    @Slot(bool)
    def setShowPronunciation(self, val: bool) -> None:
        self.cfg.ai.show_pronunciation = val
        save_config(self.cfg)
        self.stateChanged.emit()

    @Slot(str)
    def setAiMode(self, mode: str) -> None:
        self.cfg.ai.mode = mode
        save_config(self.cfg)
        self._refresh_status()
        self.stateChanged.emit()

    @Slot(bool)
    def setFallbackToLocal(self, val: bool) -> None:
        self.cfg.ai.fallback_to_local_on_quota = val
        save_config(self.cfg)
        self.stateChanged.emit()

    @Slot(str)
    def setCaptureMode(self, mode: str) -> None:
        self.cfg.audio.capture = mode
        save_config(self.cfg)
        self.stateChanged.emit()
        if self._listening:
            self._stop_listening()
            self._start_listening()

    @Slot(str)
    def setTargetProcessesText(self, text: str) -> None:
        procs = [p.strip() for p in text.split(",") if p.strip()]
        if procs:
            self.cfg.audio.target_processes = procs
            save_config(self.cfg)
            self.stateChanged.emit()
            if self._listening:
                self._stop_listening()
                self._start_listening()

    @Slot()
    def refreshRunningProcesses(self) -> None:
        try:
            self._running_processes = [name for _pid, name in list_audio_processes()]
        except Exception as e:  # noqa: BLE001
            log.debug("Failed listing processes: %s", e)
            self._running_processes = []
        self.devicesChanged.emit()

    @Slot(str)
    def addTargetProcess(self, proc: str) -> None:
        cleaned = proc.strip()
        if not cleaned:
            return
        existing = {p.lower() for p in self.cfg.audio.target_processes}
        if cleaned.lower() in existing:
            self.show_toast(f"{cleaned} 은(는) 이미 대상에 포함되어 있어요")
            return
        self.cfg.audio.target_processes = [*self.cfg.audio.target_processes, cleaned]
        save_config(self.cfg)
        self.stateChanged.emit()
        if self._listening:
            self._stop_listening()
            self._start_listening()
        self.show_toast(f"{cleaned} 추가됨")

    @Slot(str)
    def setVadPreset(self, preset: str) -> None:
        presets = {
            "fast": (180, 280),
            "balanced": (300, 450),
            "sentence": (300, 750),
        }
        min_ms, sil_ms = presets.get(preset, (300, 450))
        self.cfg.audio.min_speech_ms = min_ms
        self.cfg.audio.silence_end_ms = sil_ms
        save_config(self.cfg)
        self.stateChanged.emit()

    @Slot(bool)
    def setBgmSuppression(self, val: bool) -> None:
        self.cfg.audio.bgm_suppression = val
        save_config(self.cfg)
        self.stateChanged.emit()

    @Slot(int)
    def setCaptionFontSize(self, sz: int) -> None:
        self.cfg.overlay.font_size = sz
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(float)
    def setOverlayOpacity(self, val: float) -> None:
        self.cfg.overlay.opacity = round(val, 2)
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(int)
    def setCaptionDurationS(self, sec: int) -> None:
        self.cfg.overlay.caption_duration_s = sec
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(bool)
    def setShowOriginal(self, val: bool) -> None:
        self.cfg.overlay.show_original = val
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(bool)
    def setShowOutgoingInFeed(self, val: bool) -> None:
        self.cfg.overlay.show_outgoing_in_feed = val
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(bool)
    def setAutoCopyOutgoing(self, val: bool) -> None:
        self.cfg.overlay.auto_copy_outgoing = val
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(bool)
    def setReduceMotion(self, val: bool) -> None:
        self.cfg.overlay.reduce_motion = val
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(int)
    def setMaxCaptions(self, count: int) -> None:
        self.cfg.overlay.max_captions = max(1, min(12, count))
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot(str)
    def setOverlayPosition(self, pos: str) -> None:
        self.cfg.overlay.position = pos
        self.cfg.overlay.offset_x = 0
        self.cfg.overlay.offset_y = 0
        self.cfg.overlay.layout_version = 2
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()

    @Slot()
    def resetOverlayPosition(self) -> None:
        self.cfg.overlay.position = "top-right"
        self.cfg.overlay.offset_x = 0
        self.cfg.overlay.offset_y = 0
        self.cfg.overlay.layout_version = 2
        save_config(self.cfg)
        self.overlayLayoutChanged.emit()
        self.show_toast("자막 위치를 우측 상단으로 초기화했어요")

    @Slot(bool)
    def setOverlayClickThrough(self, val: bool) -> None:
        self.cfg.overlay.click_through = val
        save_config(self.cfg)
        self._apply_caption_style()
        self.overlayLayoutChanged.emit()

    @Slot()
    def toggleOverlayClickThrough(self) -> None:
        new_val = not self.cfg.overlay.click_through
        self.setOverlayClickThrough(new_val)
        if new_val:
            self.show_toast("자막 클릭 통과 잠금 · 상단 자물쇠로 해제")
        else:
            self.show_toast("자막 스크롤·복사 활성화")

    @Slot()
    def emitTestCaption(self) -> None:
        samples = [
            ("en", "Hey watch out, there's a boss spawning behind us!", "야 조심해, 우리 뒤에서 보스 스폰된다!"),
            ("ja", "ちょっと待って、ポーション買ってから行くね", "잠깐만 기다려, 포션 사고 나서 갈게"),
            ("en", "Nice jump! Meet me at the checkpoint flag.", "점프 나이스! 체크포인트 깃발에서 만나자."),
            ("en", "Can anyone trade a mythic pet? I'll add.", "신화 펫 트레이드할 사람? 추가도 드릴게요."),
        ]
        lang, orig, trans = samples[self._test_caption_seq % len(samples)]
        self._test_caption_seq += 1
        seg_id = -self._test_caption_seq
        self.captionReady.emit(seg_id, lang, orig, trans, 0.98)
        self._record_history(lang, orig, trans)

    @Slot(str)
    def setTtsEngine(self, engine: str) -> None:
        self.cfg.voice_out.engine = engine
        self._tts = self._build_tts()
        save_config(self.cfg)
        self.devicesChanged.emit()

    @Slot(str)
    def setVoiceOutDevice(self, dev: str) -> None:
        self.cfg.voice_out.output_device = dev
        self._reconfigure_output()
        save_config(self.cfg)
        self.devicesChanged.emit()

    @Slot(str)
    def setMonitorDevice(self, dev: str) -> None:
        self.cfg.voice_out.monitor_device = dev
        self._reconfigure_output()
        save_config(self.cfg)
        self.devicesChanged.emit()

    @Slot(bool)
    def setMixMicrophone(self, val: bool) -> None:
        self.cfg.voice_out.mix_microphone = val
        self._reconfigure_output()
        save_config(self.cfg)
        self.devicesChanged.emit()

    @Slot()
    def refreshDevices(self) -> None:
        self._output.close()
        refresh_audio_devices()
        self._reconfigure_output()
        self.devicesChanged.emit()

    def _reconfigure_output(self) -> None:
        self._output.configure(
            device_name=self.cfg.voice_out.output_device,
            monitor_name=self.cfg.voice_out.monitor_device,
            mix_microphone=self.cfg.voice_out.mix_microphone,
            mic_device=self.cfg.voice_out.mic_device,
        )

    @Slot(str, str)
    def addQuickPhrase(self, emoji: str, text: str) -> None:
        self._phrases.append({"emoji": emoji, "text": text})
        save_phrases(self._phrases)
        self.phrasesChanged.emit()

    @Slot(int)
    def removeQuickPhrase(self, idx: int) -> None:
        if 0 <= idx < len(self._phrases):
            self._phrases.pop(idx)
            save_phrases(self._phrases)
            self.phrasesChanged.emit()

    @Slot(str)
    def setGlossaryText(self, text: str) -> None:
        self._glossary = [t.strip() for t in text.split(",") if t.strip()]
        save_glossary(self._glossary)
        if self.gemini is not None:
            self.gemini.glossary = list(self._glossary)
        self.phrasesChanged.emit()

    # ------------------------------------------------------------------ Listen pipeline

    @Slot()
    def toggleListening(self) -> None:
        if self._listening:
            self._stop_listening()
        else:
            self._start_listening()

    def _refresh_status(self) -> None:
        if not self._api_key:
            self._status_level = "error"
            self._status_text = "API 키 설정 필요"
        elif not self._listening:
            self._status_level = "paused"
            self._status_text = f"일시정지 · {self.cfg.hotkeys.toggle_listen}"
        elif self._capture is None:
            self._status_level = "warn"
            self._status_text = "게임 대기 중…"
        elif self.cfg.ai.mode == "local":
            self._status_level = "local"
            self._status_text = f"Local · →{self.cfg.general.my_language.upper()}"
        else:
            self._status_level = "live"
            self._status_text = f"Live · {self.effectivePartnerLang.upper()}→{self.cfg.general.my_language.upper()}"

    def _start_capture_device_or_process(self) -> bool:
        if self._capture is not None:
            return True
        cap: AudioCapture
        if self.cfg.audio.capture == "process":
            pid = find_game_pid(self.cfg.audio.target_processes)
            if pid is None:
                return False
            try:
                cap = ProcessLoopbackCapture(pid)
                cap.start(self._on_audio_frames)
                self._capture = cap
                return True
            except Exception as e:  # noqa: BLE001
                log.warning("ProcessLoopbackCapture failed (%s); falling back to device loopback", e)
        try:
            cap = DeviceLoopbackCapture()
            cap.start(self._on_audio_frames)
            self._capture = cap
            return True
        except Exception as e:  # noqa: BLE001
            log.error("Audio capture start failed: %s", e)
            self.show_toast(f"오디오 캡처 시작 실패: {e}")
            return False

    def _start_listening(self, auto: bool = False) -> None:
        if not self._api_key:
            if not auto:
                self.openSettings()
            return
        self._listening = True
        self._vad.reset()
        while not self._vad_queue.empty():
            try:
                self._vad_queue.get_nowait()
            except queue.Empty:
                break
        if self._vad_thread is None or not self._vad_thread.is_alive():
            self._vad_thread = threading.Thread(target=self._vad_worker, daemon=True)
            self._vad_thread.start()
        self._start_capture_device_or_process()
        self._refresh_status()
        self.stateChanged.emit()

    def _stop_listening(self) -> None:
        self._listening = False
        if self._capture is not None:
            self._capture.stop()
            self._capture = None
        self._vad_queue.put(None)
        self._latest_rms = 0.0
        self._refresh_status()
        self.stateChanged.emit()

    def _check_game_process(self) -> None:
        if not self._listening or self.cfg.audio.capture != "process":
            return
        pid = find_game_pid(self.cfg.audio.target_processes)
        if pid is not None and self._capture is None:
            if self._start_capture_device_or_process():
                self._refresh_status()
                self.stateChanged.emit()
        elif pid is None and isinstance(self._capture, ProcessLoopbackCapture):
            self._capture.stop()
            self._capture = None
            self._refresh_status()
            self.stateChanged.emit()

    def _on_audio_frames(self, pcm16: bytes) -> None:
        self._latest_rms = compute_rms_level(pcm16)
        if not self._listening:
            return
        try:
            self._vad_queue.put_nowait(pcm16)
        except queue.Full:
            try:
                self._vad_queue.get_nowait()
            except queue.Empty:
                pass
            try:
                self._vad_queue.put_nowait(pcm16)
            except queue.Full:
                pass

    def _vad_worker(self) -> None:
        while True:
            chunk = self._vad_queue.get()
            if chunk is None:
                self._vad.flush()
                break
            self._vad.feed(chunk)

    def _on_vad_segment(self, seg: Segment) -> None:
        self.loop.call_soon_threadsafe(self._enqueue_segment, seg)

    @staticmethod
    def _should_skip_segment(seg: Segment) -> bool:
        """Drop tiny clicks/silence tails before spending a Gemini API request."""
        return seg.duration_s < 0.28 or compute_rms_level(seg.pcm16) < 0.008

    def _enqueue_segment(self, seg: Segment) -> None:
        if not self._listening or self._should_skip_segment(seg):
            return
        # Latest-first queue bounded to 3 items so captions never drift behind real time
        while len(self._seg_deque) >= 3:
            dropped = self._seg_deque.popleft()
            self.captionDismissed.emit(dropped.id)
        self._seg_deque.append(seg)
        self.captionStarted.emit(seg.id)
        self._seg_event.set()

    async def _listen_worker(self) -> None:
        while True:
            await self._seg_event.wait()
            while self._seg_deque:
                seg = self._seg_deque.popleft()
                if not self._listening or self.gemini is None:
                    self.captionDismissed.emit(seg.id)
                    continue
                self.captionTranslating.emit(seg.id)
                waited_notice = False
                if self.cfg.ai.mode == "cloud":
                    wait_s = self.gemini.limiter.wait_time()
                    if wait_s >= 1.2:
                        waited_notice = True
                        self._status_level = "warn"
                        self._status_text = f"한도 대기 · {max(1, round(wait_s))}초"
                        self.stateChanged.emit()
                try:
                    caption = await self._process_segment(seg)
                except QuotaExceeded:
                    self._handle_quota_error()
                    self.captionDismissed.emit(seg.id)
                    continue
                except Exception:
                    log.exception("Listen error")
                    if waited_notice:
                        self._refresh_status()
                        self.stateChanged.emit()
                    self.captionDismissed.emit(seg.id)
                    continue

                if caption.is_speech and caption.transcript.strip():
                    src_lang = caption.source_lang or "en"
                    if src_lang.lower() != self.cfg.general.my_language.lower():
                        self._detected_partner_lang = src_lang.lower()
                    self.captionReady.emit(
                        caption.segment_id,
                        src_lang,
                        caption.transcript,
                        caption.translation or caption.transcript,
                        caption.confidence,
                    )
                    self._record_history(src_lang, caption.transcript, caption.translation or caption.transcript)
                    self._refresh_status()
                    self.stateChanged.emit()
                    self.usageChanged.emit()
                    self._check_budget_guard()
                else:
                    if waited_notice:
                        self._refresh_status()
                        self.stateChanged.emit()
                    self.captionDismissed.emit(seg.id)
            self._seg_event.clear()

    async def _process_segment(self, seg: Segment) -> Caption:
        assert self.gemini is not None
        if self.cfg.ai.mode == "local":
            lang, text = await asyncio.to_thread(self._local_whisper.transcribe, seg)
            if not text:
                return Caption(seg.id, False, lang, "", "", 0.0)
            return await self.gemini.translate_text(seg.id, text, lang)
        return await self.gemini.interpret_audio(seg)

    def _handle_quota_error(self) -> None:
        now = dt.datetime.now().timestamp()
        self._quota_errors_recent.append(now)
        self._status_level = "warn"
        self._status_text = "한도 대기 중 (429)"
        self.stateChanged.emit()
        recent_count = sum(1 for ts in self._quota_errors_recent if now - ts <= 60)
        if recent_count >= 5 and self.cfg.ai.fallback_to_local_on_quota and self.cfg.ai.mode != "local":
            self.cfg.ai.mode = "local"
            save_config(self.cfg)
            self.show_toast("API 한도로 인해 로컬 모드로 자동 전환했어요")
            self._refresh_status()
            self.stateChanged.emit()

    def _check_budget_guard(self) -> None:
        if self.meter.over_budget and self.cfg.ai.mode != "local":
            self.show_toast("월 예산 상한에 도달했습니다!")
            if self.cfg.ai.fallback_to_local_on_quota:
                self.setAiMode("local")
        elif self.meter.should_warn:
            self.show_toast("월 예산의 80%를 넘었어요")

    def _record_history(self, lang: str, orig: str, trans: str) -> None:
        self._history.insert(
            0,
            {
                "time": dt.datetime.now().strftime("%H:%M:%S"),
                "lang": lang,
                "original": orig,
                "translation": trans,
            },
        )
        if len(self._history) > 100:
            self._history.pop()
        self.historyChanged.emit()

    def _tick_ui(self) -> None:
        self._audio_level = self._audio_level * 0.55 + self._latest_rms * 0.45
        self._latest_rms *= 0.65
        self.audioLevelChanged.emit()
        self.usageChanged.emit()

    # ------------------------------------------------------------------ Speak & Voice Out

    @Slot(str, bool, str)
    def translateOutgoing(self, text: str, speak_after: bool, tone_override: str) -> None:
        if self.gemini is None:
            self.outgoingFailed.emit("API 키가 설정되지 않았습니다 (설정 > 연결·API)")
            return
        self.outgoingStarted.emit()
        self._spawn(self._run_outgoing(text, speak_after, tone_override or None))

    async def _run_outgoing(self, text: str, speak_after: bool, tone_override: str | None) -> None:
        assert self.gemini is not None
        target = self.effectivePartnerLang
        try:
            res = await self.gemini.translate_outgoing(text, target, tone_override)
        except QuotaExceeded:
            self.outgoingFailed.emit("요청 한도 초과 (잠시 후 다시 시도하세요)")
            return
        except Exception as e:  # noqa: BLE001
            self.outgoingFailed.emit(f"번역 오류: {e}")
            return

        self._last_outgoing_text = res.translation
        self._last_outgoing_lang = res.target_lang
        if self.cfg.overlay.auto_copy_outgoing and res.translation:
            cb = QGuiApplication.clipboard()
            if cb is not None:
                cb.setText(res.translation)
        self.outgoingReady.emit(
            res.translation,
            res.pronunciation,
            res.casual,
            res.polite,
            res.source_text,
            res.target_lang,
        )
        self.usageChanged.emit()
        if speak_after and res.translation:
            await self._run_speak(res.translation, res.target_lang)
            self.closeComposer()

    @Slot(int)
    def triggerQuickPhrase(self, idx: int) -> None:
        if 0 <= idx < len(self._phrases):
            self.translateOutgoing(self._phrases[idx]["text"], True, "")

    @Slot()
    def repeatLastOutgoing(self) -> None:
        if self._last_outgoing_text:
            self.speakText(self._last_outgoing_text, self._last_outgoing_lang)
        else:
            self.show_toast("아직 번역한 문장이 없어요")

    @Slot(str, str)
    def speakText(self, text: str, lang: str) -> None:
        if not text:
            return
        self._spawn(self._run_speak(text, lang or self.effectivePartnerLang))

    @Slot()
    def stopSpeak(self) -> None:
        self._output.stop()
        self._tts_playing = False
        self.ttsStateChanged.emit()

    async def _run_speak(self, text: str, lang: str) -> None:
        if not self._output.available:
            self.show_toast("VB-Cable(CABLE Input)이 없어 송출할 수 없어요 · 복사해 사용하세요")
            return
        try:
            audio = await self._tts.synthesize(text, lang)
        except Exception as e:  # noqa: BLE001
            self.show_toast(f"음성 생성 실패: {e}")
            return

        self._tts_playing = True
        self.ttsStateChanged.emit()

        def _done() -> None:
            self.loop.call_soon_threadsafe(self._on_tts_finished)

        try:
            self._output.play(audio.pcm16, audio.sample_rate, on_finished=_done)
        except Exception as e:  # noqa: BLE001
            self._tts_playing = False
            self.ttsStateChanged.emit()
            self.show_toast(f"송출 실패: {e}")

    def _on_tts_finished(self) -> None:
        self._tts_playing = False
        self.ttsStateChanged.emit()
