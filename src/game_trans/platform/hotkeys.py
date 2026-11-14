"""Global hotkeys via Win32 ``RegisterHotKey``.

Deliberately *not* a low-level keyboard hook (``SetWindowsHookEx``): RegisterHotKey only
receives the specific combos we register, which is lighter and anti-cheat friendly.
"""

from __future__ import annotations

import ctypes
import logging
import sys
from collections.abc import Callable
from ctypes import wintypes

log = logging.getLogger(__name__)

MOD_ALT, MOD_CONTROL, MOD_SHIFT, MOD_WIN, MOD_NOREPEAT = 0x1, 0x2, 0x4, 0x8, 0x4000
WM_HOTKEY = 0x0312

_MODS = {"ctrl": MOD_CONTROL, "control": MOD_CONTROL, "shift": MOD_SHIFT, "alt": MOD_ALT, "win": MOD_WIN}
_KEYS = {
    "space": 0x20,
    "enter": 0x0D,
    "return": 0x0D,
    "esc": 0x1B,
    "escape": 0x1B,
    "tab": 0x09,
    "backspace": 0x08,
    "insert": 0x2D,
    "delete": 0x2E,
    "home": 0x24,
    "end": 0x23,
    "pageup": 0x21,
    "pagedown": 0x22,
    "left": 0x25,
    "up": 0x26,
    "right": 0x27,
    "down": 0x28,
    **{f"f{i}": 0x6F + i for i in range(1, 13)},
}


def parse_hotkey(text: str) -> tuple[int, int]:
    """'Ctrl+Shift+Space' -> (modifiers, virtual-key code)."""
    mods, vk = MOD_NOREPEAT, 0
    for part in (p.strip().lower() for p in text.split("+")):
        if not part:
            continue
        if part in _MODS:
            mods |= _MODS[part]
        elif part in _KEYS:
            vk = _KEYS[part]
        elif len(part) == 1 and part.isalnum():
            vk = ord(part.upper())
        else:
            raise ValueError(f"unknown key: {part!r}")
    if not vk:
        raise ValueError(f"hotkey needs a non-modifier key: {text!r}")
    return mods, vk


try:
    from PySide6.QtCore import QAbstractNativeEventFilter
    from PySide6.QtGui import QWindow

    class _NativeFilter(QAbstractNativeEventFilter):
        def __init__(self, dispatch: Callable[[int], None]) -> None:
            super().__init__()
            self._dispatch = dispatch

        def nativeEventFilter(self, eventType, message):
            if eventType == b"windows_generic_MSG" or bytes(eventType) == b"windows_generic_MSG":
                msg = ctypes.cast(int(message), ctypes.POINTER(wintypes.MSG)).contents
                if msg.message == WM_HOTKEY:
                    self._dispatch(int(msg.wParam))
                    return True, 0
            return False, 0

except ImportError:
    _NativeFilter = None  # type: ignore[assignment,misc]
    QWindow = None  # type: ignore[assignment,misc]


class HotkeyManager:
    """Registers global hotkeys on a hidden QWindow and dispatches via QAbstractNativeEventFilter."""

    def __init__(self, app=None) -> None:
        self._app = app
        self._handlers: dict[int, Callable[[], None]] = {}
        self._next_id = 1
        self._window = None
        self._hwnd = 0
        self._filter = None

    def _ensure_installed(self) -> None:
        if sys.platform != "win32":
            return
        if self._window is None and QWindow is not None:
            self._window = QWindow()
            self._window.setObjectName("GameTransHotkeySink")
            self._window.create()
            self._hwnd = int(self._window.winId())
        if self._filter is None and self._app is not None and _NativeFilter is not None:
            self._filter = _NativeFilter(self._on_hotkey)
            self._app.installNativeEventFilter(self._filter)

    def _on_hotkey(self, hotkey_id: int) -> None:
        handler = self._handlers.get(hotkey_id)
        if handler is not None:
            handler()

    def register(self, combo: str, handler: Callable[[], None]) -> bool:
        mods, vk = parse_hotkey(combo)
        if sys.platform != "win32":
            return False
        self._ensure_installed()
        hotkey_id = self._next_id
        self._next_id += 1
        ok = bool(ctypes.windll.user32.RegisterHotKey(self._hwnd, hotkey_id, mods, vk))
        if not ok:
            log.warning("Failed to register global hotkey %s (already in use?)", combo)
            return False
        self._handlers[hotkey_id] = handler
        return True

    def unregister_all(self) -> None:
        if sys.platform == "win32":
            user32 = ctypes.windll.user32
            for hotkey_id in list(self._handlers):
                user32.UnregisterHotKey(self._hwnd, hotkey_id)
        self._handlers.clear()
        if self._filter is not None and self._app is not None:
            self._app.removeNativeEventFilter(self._filter)
            self._filter = None
