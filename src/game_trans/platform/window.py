"""Overlay window styles and safe foreground focus helpers (Windows).

Makes caption/status Qt windows click-through and non-activating so they never steal focus or
input from the game. Only touches *our own* window handles – nothing is injected into the game.
"""

from __future__ import annotations

import ctypes
import sys

GWL_EXSTYLE = -20
WS_EX_LAYERED = 0x00080000
WS_EX_TRANSPARENT = 0x00000020
WS_EX_NOACTIVATE = 0x08000000
WS_EX_TOOLWINDOW = 0x00000080

SWP_NOSIZE = 0x0001
SWP_NOMOVE = 0x0002
SWP_NOZORDER = 0x0004
SWP_NOACTIVATE = 0x0010
SWP_FRAMECHANGED = 0x0020
HWND_TOPMOST = -1


def _user32():
    if sys.platform != "win32":
        raise OSError("Windows only")
    return ctypes.windll.user32


def set_click_through(hwnd: int, enabled: bool) -> None:
    """Toggle mouse pass-through. Disabled in overlay *edit mode* so the user can drag it."""
    if not hwnd:
        return
    user32 = _user32()
    style = user32.GetWindowLongPtrW(hwnd, GWL_EXSTYLE)
    style |= WS_EX_LAYERED | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW
    if enabled:
        style |= WS_EX_TRANSPARENT
    else:
        style &= ~WS_EX_TRANSPARENT
    user32.SetWindowLongPtrW(hwnd, GWL_EXSTYLE, style)
    user32.SetWindowPos(
        hwnd,
        HWND_TOPMOST,
        0,
        0,
        0,
        0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED,
    )


def set_no_activate(hwnd: int) -> None:
    """Make a window topmost and clickable without stealing keyboard focus from the game."""
    if not hwnd:
        return
    user32 = _user32()
    style = user32.GetWindowLongPtrW(hwnd, GWL_EXSTYLE)
    style = (style | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW) & ~WS_EX_TRANSPARENT
    user32.SetWindowLongPtrW(hwnd, GWL_EXSTYLE, style)
    user32.SetWindowPos(
        hwnd,
        HWND_TOPMOST,
        0,
        0,
        0,
        0,
        SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED,
    )


def get_foreground_hwnd() -> int:
    if sys.platform != "win32":
        return 0
    return int(_user32().GetForegroundWindow())


def restore_foreground(hwnd: int) -> None:
    """Return focus to the previous window (e.g. Roblox) after closing the input bar."""
    if sys.platform != "win32" or not hwnd:
        return
    user32 = _user32()
    if user32.IsWindow(hwnd):
        user32.SetForegroundWindow(hwnd)


def focus_window(hwnd: int) -> None:
    """Bring our focusable input bar to foreground cleanly when summoned by global hotkey."""
    if sys.platform != "win32" or not hwnd:
        return
    user32 = _user32()
    kernel32 = ctypes.windll.kernel32
    fg = user32.GetForegroundWindow()
    fg_tid = user32.GetWindowThreadProcessId(fg, None) if fg else 0
    cur_tid = kernel32.GetCurrentThreadId()
    attached = False
    if fg_tid and fg_tid != cur_tid:
        attached = bool(user32.AttachThreadInput(fg_tid, cur_tid, True))
    try:
        user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE)
        user32.SetForegroundWindow(hwnd)
        user32.SetFocus(hwnd)
    finally:
        if attached:
            user32.AttachThreadInput(fg_tid, cur_tid, False)


def set_dark_titlebar(hwnd: int) -> None:
    """Enable Windows 10/11 immersive dark titlebar and match #0F1012 caption color on Win11."""
    if sys.platform != "win32" or not hwnd:
        return
    try:
        dwmapi = ctypes.windll.dwmapi
        dark = ctypes.c_int(1)
        for attr in (20, 19):  # DWMWA_USE_IMMERSIVE_DARK_MODE (Win11 / Win10 1903+)
            dwmapi.DwmSetWindowAttribute(hwnd, attr, ctypes.byref(dark), ctypes.sizeof(dark))
        # DWMWA_CAPTION_COLOR = 35, COLORREF BGR (#0F1012 -> 0x0012100F)
        caption_bgr = ctypes.c_uint(0x0012100F)
        dwmapi.DwmSetWindowAttribute(hwnd, 35, ctypes.byref(caption_bgr), ctypes.sizeof(caption_bgr))
    except OSError:
        pass
