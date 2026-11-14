"""Application bootstrap: Qt + qasync + QML overlays + tray icon + global hotkeys."""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from collections.abc import Callable
from pathlib import Path

os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

import qasync
from PySide6.QtCore import Qt
from PySide6.QtGui import (
    QAction,
    QColor,
    QFont,
    QIcon,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPalette,
    QPixmap,
)
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon

from . import __version__
from .ai.usage import UsageMeter, UsageStore
from .config import app_dir, load_config
from .platform.hotkeys import HotkeyManager
from .ui.bridge import Backend

log = logging.getLogger(__name__)
_SINGLE_INSTANCE_NAME = "GameTransSingleInstance_v1"


def _create_sparkle_icon() -> QIcon:
    ico_path = Path(__file__).resolve().parent / "assets" / "game_trans.ico"
    if ico_path.exists():
        icon = QIcon(str(ico_path))
        if not icon.isNull():
            return icon

    size = 64
    pm = QPixmap(size, size)
    pm.fill(Qt.GlobalColor.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)

    # Dark rounded pill background
    p.setBrush(QColor("#1E1F20"))
    p.setPen(QColor("#444746"))
    p.drawRoundedRect(2, 2, size - 4, size - 4, 16, 16)

    # 4-point Gemini-inspired sparkle
    cx = cy = size / 2.0
    r = size * 0.34
    k = r * 0.14
    path = QPainterPath()
    path.moveTo(cx, cy - r)
    path.cubicTo(cx + k, cy - k, cx + k, cy - k, cx + r, cy)
    path.cubicTo(cx + k, cy + k, cx + k, cy + k, cx, cy + r)
    path.cubicTo(cx - k, cy + k, cx - k, cy + k, cx - r, cy)
    path.cubicTo(cx - k, cy - k, cx - k, cy - k, cx, cy - r)
    path.closeSubpath()

    grad = QLinearGradient(8, 8, size - 8, size - 8)
    grad.setColorAt(0.0, QColor("#4285F4"))
    grad.setColorAt(0.5, QColor("#9B72CB"))
    grad.setColorAt(1.0, QColor("#D96570"))
    p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(grad)
    p.drawPath(path)
    p.end()
    return QIcon(pm)


def _setup_logging() -> None:
    log_dir = app_dir() / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.FileHandler(log_dir / "game_trans.log", encoding="utf-8"),
            logging.StreamHandler(),
        ],
    )


def _register_hotkeys(hotkeys: HotkeyManager, backend: Backend, cfg) -> None:
    hotkeys.register(cfg.hotkeys.toggle_input, backend.toggleComposer)
    hotkeys.register(cfg.hotkeys.toggle_listen, backend.toggleListening)
    hotkeys.register(cfg.hotkeys.repeat_last, backend.repeatLastOutgoing)
    hotkeys.register(cfg.hotkeys.history, backend.toggleHistory)
    hotkeys.register(cfg.hotkeys.edit_overlay, backend.toggleEditMode)
    for i in range(1, 10):
        hotkeys.register(f"Ctrl+Shift+{i}", lambda idx=i - 1: backend.triggerQuickPhrase(idx))


def _apply_dark_theme(app: QApplication) -> None:
    """Force dark palette and Qt color scheme so Windows light theme never leaks black text."""
    try:
        app.styleHints().setColorScheme(Qt.ColorScheme.Dark)
    except Exception as exc:  # noqa: BLE001
        log.debug("setColorScheme Dark unsupported: %s", exc)

    pal = QPalette()
    pal.setColor(QPalette.ColorRole.Window, QColor("#131314"))
    pal.setColor(QPalette.ColorRole.WindowText, QColor("#E3E3E3"))
    pal.setColor(QPalette.ColorRole.Base, QColor("#1E1F20"))
    pal.setColor(QPalette.ColorRole.AlternateBase, QColor("#282A2C"))
    pal.setColor(QPalette.ColorRole.ToolTipBase, QColor("#282A2C"))
    pal.setColor(QPalette.ColorRole.ToolTipText, QColor("#E3E3E3"))
    pal.setColor(QPalette.ColorRole.Text, QColor("#E3E3E3"))
    pal.setColor(QPalette.ColorRole.Button, QColor("#1E1F20"))
    pal.setColor(QPalette.ColorRole.ButtonText, QColor("#E3E3E3"))
    pal.setColor(QPalette.ColorRole.BrightText, QColor("#FFFFFF"))
    pal.setColor(QPalette.ColorRole.PlaceholderText, QColor("#8E918F"))
    pal.setColor(QPalette.ColorRole.Highlight, QColor("#004A77"))
    pal.setColor(QPalette.ColorRole.HighlightedText, QColor("#E3E3E3"))
    pal.setColor(QPalette.ColorRole.Link, QColor("#A8C7FA"))
    app.setPalette(pal)


def _notify_existing_instance(server_name: str = _SINGLE_INSTANCE_NAME) -> bool:
    sock = QLocalSocket()
    sock.connectToServer(server_name)
    if not sock.waitForConnected(250):
        return False
    sock.write(b"WAKE_SETTINGS\n")
    sock.flush()
    sock.waitForBytesWritten(250)
    sock.disconnectFromServer()
    return True


def _start_single_instance_server(
    on_wake: Callable[[], None],
    server_name: str = _SINGLE_INSTANCE_NAME,
) -> QLocalServer:
    QLocalServer.removeServer(server_name)
    server = QLocalServer()

    def _accept() -> None:
        while server.hasPendingConnections():
            conn = server.nextPendingConnection()
            if conn is not None:
                conn.waitForReadyRead(100)
                conn.close()
                conn.deleteLater()
                on_wake()

    server.newConnection.connect(_accept)
    if not server.listen(server_name):
        log.warning("Could not listen on local single-instance server %s", server_name)
    return server


def _create_tray(app: QApplication, icon: QIcon, backend: Backend, cfg) -> QSystemTrayIcon:
    tray = QSystemTrayIcon(icon, app)
    tray.setToolTip(f"Game Trans v{__version__}")

    menu = QMenu()
    menu.setStyleSheet(
        """
        QMenu {
            background-color: #1E1F20;
            color: #E3E3E3;
            border: 1px solid #3C4043;
            border-radius: 8px;
            padding: 6px 4px;
        }
        QMenu::item {
            padding: 7px 18px;
            border-radius: 5px;
            color: #E3E3E3;
            background-color: transparent;
        }
        QMenu::item:selected {
            background-color: #282A2C;
            color: #A8C7FA;
        }
        QMenu::separator {
            height: 1px;
            background-color: #3C4043;
            margin: 4px 10px;
        }
        """
    )
    act_input = QAction(f"입력 바 열기 ({cfg.hotkeys.toggle_input})", menu)
    act_input.triggered.connect(backend.openComposer)
    menu.addAction(act_input)

    act_listen = QAction(f"듣기 시작/일시정지 ({cfg.hotkeys.toggle_listen})", menu)
    act_listen.triggered.connect(backend.toggleListening)
    menu.addAction(act_listen)

    act_hist = QAction(f"자막 기록 ({cfg.hotkeys.history})", menu)
    act_hist.triggered.connect(backend.toggleHistory)
    menu.addAction(act_hist)

    act_edit = QAction(f"오버레이 위치 편집 ({cfg.hotkeys.edit_overlay})", menu)
    act_edit.triggered.connect(backend.toggleEditMode)
    menu.addAction(act_edit)

    menu.addSeparator()

    act_settings = QAction("설정 열기", menu)
    act_settings.triggered.connect(backend.openSettings)
    menu.addAction(act_settings)

    act_quit = QAction("종료", menu)
    act_quit.triggered.connect(app.quit)
    menu.addAction(act_quit)

    tray.setContextMenu(menu)
    tray.activated.connect(
        lambda reason: backend.openSettings()
        if reason == QSystemTrayIcon.ActivationReason.DoubleClick
        else None
    )
    tray.show()
    return tray


def run() -> int:
    _setup_logging()
    cfg = load_config()

    app = QApplication(sys.argv)
    app.setApplicationName("Game Trans")
    app.setQuitOnLastWindowClosed(False)
    _apply_dark_theme(app)

    if _notify_existing_instance():
        log.info("Existing Game Trans instance notified; exiting duplicate launch")
        return 0

    QFont.insertSubstitutions("Pretendard", ["Malgun Gothic", "Segoe UI", "Noto Sans KR"])
    app.setFont(QFont("Pretendard", 10))
    icon = _create_sparkle_icon()
    app.setWindowIcon(icon)

    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    store = UsageStore(app_dir() / "usage.sqlite")
    meter = UsageMeter(
        input_per_mtok=cfg.ai.pricing.input_per_mtok,
        output_per_mtok=cfg.ai.pricing.output_per_mtok,
        monthly_budget_usd=cfg.budget.monthly_budget_usd,
        warn_ratio=cfg.budget.warn_ratio,
        store=store,
    )
    backend = Backend(cfg, meter, store, loop)

    engine = QQmlApplicationEngine()
    qml_dir = Path(__file__).resolve().parent / "ui" / "qml"
    engine.addImportPath(str(qml_dir.parent))
    engine.rootContext().setContextProperty("backend", backend)

    for qml_file in ("StatusPill.qml", "CaptionOverlay.qml", "InputBar.qml", "HistoryWindow.qml", "SettingsWindow.qml"):
        engine.load(str(qml_dir / qml_file))

    if not engine.rootObjects():
        log.error("Failed to load QML views from %s", qml_dir)
        backend.shutdown()
        return 1

    hotkeys = HotkeyManager(app)
    _register_hotkeys(hotkeys, backend, cfg)
    tray = _create_tray(app, icon, backend, cfg)
    single_server = _start_single_instance_server(
        lambda: (backend.openSettings(), backend.show_toast("이미 실행 중이라 설정 창을 열었습니다"))
    )
    _keepalive = (tray, hotkeys, single_server)  # prevent GC

    backend.start_background()
    app.aboutToQuit.connect(lambda: (single_server.close(), hotkeys.unregister_all(), backend.shutdown()))

    with loop:
        return loop.run_forever()
