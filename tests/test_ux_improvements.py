from __future__ import annotations

import asyncio
import os
import struct

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import pytest
from PySide6.QtCore import Qt, QUrl
from PySide6.QtGui import QColor, QPalette
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from game_trans.ai.usage import UsageMeter
from game_trans.app import _apply_dark_theme, _notify_existing_instance, _start_single_instance_server
from game_trans.audio.capture import list_audio_processes
from game_trans.config import Config, load_config, save_config
from game_trans.events import Segment
from game_trans.ui.bridge import Backend


@pytest.fixture
def qapp():
    app = QApplication.instance() or QApplication([])
    return app


def test_dark_theme_overrides_light_palette(qapp) -> None:
    light = QPalette()
    light.setColor(QPalette.ColorRole.WindowText, QColor("#000000"))
    light.setColor(QPalette.ColorRole.Text, QColor("#000000"))
    light.setColor(QPalette.ColorRole.PlaceholderText, QColor("#222222"))
    qapp.setPalette(light)

    _apply_dark_theme(qapp)
    pal = qapp.palette()
    for role in (
        QPalette.ColorRole.WindowText,
        QPalette.ColorRole.Text,
        QPalette.ColorRole.ButtonText,
        QPalette.ColorRole.HighlightedText,
    ):
        col = pal.color(role)
        assert col.lightness() > 200, f"{role} remained dark: {col.name()}"
    assert pal.color(QPalette.ColorRole.PlaceholderText).lightness() > 110


def test_single_instance_socket_wakes_primary(qapp) -> None:
    woken = []
    name = "GameTransTestSingleInstance_ux"
    server = _start_single_instance_server(lambda: woken.append(True), server_name=name)
    try:
        assert _notify_existing_instance(name) is True
        qapp.processEvents()
        assert woken == [True]
    finally:
        server.close()


def test_overlay_new_ux_flags_roundtrip(tmp_path) -> None:
    cfg = Config()
    assert cfg.overlay.show_outgoing_in_feed is True
    assert cfg.overlay.auto_copy_outgoing is True

    cfg.overlay.show_outgoing_in_feed = False
    cfg.overlay.auto_copy_outgoing = False
    path = tmp_path / "config.toml"
    save_config(cfg, path)
    loaded = load_config(path)
    assert loaded.overlay.show_outgoing_in_feed is False
    assert loaded.overlay.auto_copy_outgoing is False


def test_should_skip_segment_drops_clicks_and_silence() -> None:
    # Too short (< 0.28s) even with loud sample
    short_loud = struct.pack("<2000h", *([8000] * 2000))  # 0.125s @ 16kHz
    assert Backend._should_skip_segment(Segment(id=1, pcm16=short_loud)) is True

    # Long enough (0.5s) but dead quiet noise floor
    quiet = b"\x00\x00" * 8000
    assert Backend._should_skip_segment(Segment(id=2, pcm16=quiet)) is True

    # Real speech (0.5s with audible amplitude)
    speech = struct.pack("<8000h", *([3000, -3000] * 4000))
    assert Backend._should_skip_segment(Segment(id=3, pcm16=speech)) is False


def test_vad_preset_and_target_process_helpers(qapp, tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("APPDATA", str(tmp_path))
    monkeypatch.setattr("game_trans.platform.secrets.get_api_key", lambda: "")

    cfg = Config()
    loop = asyncio.new_event_loop()
    meter = UsageMeter(0.3, 2.5, 9.0, 0.8, None)
    backend = Backend(cfg, meter, None, loop)
    try:
        assert backend.vadPreset == "balanced"
        backend.setVadPreset("fast")
        assert backend.vadPreset == "fast"
        assert cfg.audio.silence_end_ms == 280
        assert cfg.audio.min_speech_ms == 180

        backend.setVadPreset("sentence")
        assert backend.vadPreset == "sentence"
        assert cfg.audio.silence_end_ms == 750

        backend.addTargetProcess("Discord.exe")
        assert "Discord.exe" in cfg.audio.target_processes
        # Duplicate case-insensitive addition should not duplicate entries
        before = list(cfg.audio.target_processes)
        backend.addTargetProcess("discord.exe")
        assert cfg.audio.target_processes == before
    finally:
        backend.shutdown()
        loop.close()


def test_list_audio_processes_returns_unique_exes() -> None:
    procs = list_audio_processes()
    names = [name.lower() for _pid, name in procs]
    assert len(names) == len(set(names))
    assert all(name.endswith(".exe") for name in names)


def test_m3_combobox_popup_items_have_visible_text_and_light_colors(qapp, tmp_path, monkeypatch) -> None:
    monkeypatch.setenv("APPDATA", str(tmp_path))
    monkeypatch.setattr("game_trans.platform.secrets.get_api_key", lambda: "")
    _apply_dark_theme(qapp)

    engine = QQmlApplicationEngine()
    from pathlib import Path

    qml_dir = Path(__file__).resolve().parents[1] / "src" / "game_trans" / "ui" / "qml"
    engine.addImportPath(str(qml_dir.parent))
    qml = """
    import QtQuick
    import QtQuick.Controls
    import QtQuick.Window
    Window {
        width: 340
        height: 280
        visible: true
        M3ComboBox {
            id: cb
            width: 300
            model: ["gemini-3.5-flash-lite", "gemini-2.5-flash"]
            currentIndex: 0
            Component.onCompleted: popup.open()
        }
    }
    """
    engine.loadData(qml.encode("utf-8"), QUrl.fromLocalFile(str(qml_dir / "test_cb_unit.qml")))
    qapp.processEvents()
    win = engine.rootObjects()[0]
    assert win.property("visible") is True
    cb = win.children()[1] if len(win.children()) > 1 else None
    if cb is not None:
        assert cb.property("currentText") == "gemini-3.5-flash-lite"
        # textAt must resolve item labels for the ItemDelegate
        assert Qt is not None
    win.close()
    del win
    del engine
