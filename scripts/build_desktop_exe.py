"""Generate Game Trans app icon (.ico) and compile the native Desktop launcher .exe."""

from __future__ import annotations

import argparse
import os
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PySide6.QtCore import QBuffer, QIODevice, QPointF, QRectF, Qt
from PySide6.QtGui import (
    QColor,
    QGuiApplication,
    QImage,
    QLinearGradient,
    QPainter,
    QPainterPath,
    QPen,
    QRadialGradient,
)

ROOT_DIR = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT_DIR / "src" / "game_trans" / "assets"
ICO_PATH = ASSETS_DIR / "game_trans.ico"
ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)


def _sparkle_path(cx: float, cy: float, radius: float, pinch: float = 0.16) -> QPainterPath:
    k = radius * pinch
    path = QPainterPath()
    path.moveTo(cx, cy - radius)
    path.cubicTo(cx + k, cy - k, cx + k, cy - k, cx + radius, cy)
    path.cubicTo(cx + k, cy + k, cx + k, cy + k, cx, cy + radius)
    path.cubicTo(cx - k, cy + k, cx - k, cy + k, cx - radius, cy)
    path.cubicTo(cx - k, cy - k, cx - k, cy - k, cx, cy - radius)
    path.closeSubpath()
    return path


def render_master_icon(size: int = 1024) -> QImage:
    """Render an Antigravity / Gemini dark-glass squircle icon with caption capsule & sparkle."""
    img = QImage(size, size, QImage.Format.Format_RGBA8888_Premultiplied)
    img.fill(Qt.GlobalColor.transparent)

    p = QPainter(img)
    p.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)

    s = size / 1024.0
    p.scale(s, s)

    # Outer squircle geometry
    tile_rect = QRectF(56.0, 56.0, 912.0, 912.0)
    tile_radius = 224.0
    tile_path = QPainterPath()
    tile_path.addRoundedRect(tile_rect, tile_radius, tile_radius)

    # Dark obsidian base fill
    base_grad = QLinearGradient(120.0, 60.0, 900.0, 960.0)
    base_grad.setColorAt(0.0, QColor("#181A20"))
    base_grad.setColorAt(0.55, QColor("#111216"))
    base_grad.setColorAt(1.0, QColor("#0B0C0F"))
    p.save()
    p.setClipPath(tile_path)
    p.fillRect(tile_rect, base_grad)

    # Subtle top-right & bottom-left Gemini ambient aurora glow inside tile
    glow_tr = QRadialGradient(QPointF(735.0, 290.0), 470.0)
    glow_tr.setColorAt(0.0, QColor(66, 133, 244, 62))
    glow_tr.setColorAt(0.45, QColor(155, 114, 203, 28))
    glow_tr.setColorAt(1.0, QColor(15, 16, 20, 0))
    p.fillRect(tile_rect, glow_tr)

    glow_bl = QRadialGradient(QPointF(260.0, 770.0), 420.0)
    glow_bl.setColorAt(0.0, QColor(217, 101, 112, 24))
    glow_bl.setColorAt(1.0, QColor(15, 16, 20, 0))
    p.fillRect(tile_rect, glow_bl)

    # Subtle top edge glass sheen
    sheen = QLinearGradient(512.0, 56.0, 512.0, 220.0)
    sheen.setColorAt(0.0, QColor(255, 255, 255, 22))
    sheen.setColorAt(1.0, QColor(255, 255, 255, 0))
    p.fillRect(QRectF(56.0, 56.0, 912.0, 170.0), sheen)
    p.restore()

    # Crisp glass rim outline
    rim_pen = QPen(QColor(255, 255, 255, 34), 6.0)
    p.setPen(rim_pen)
    p.setBrush(Qt.BrushStyle.NoBrush)
    p.drawRoundedRect(QRectF(59.0, 59.0, 906.0, 906.0), tile_radius - 3.0, tile_radius - 3.0)

    # Frosted minimalist caption / chat capsule rendered onto separate layer so sparkle creates a clean cutout
    bx, by, bw, bh = 188.0, 342.0, 526.0, 366.0
    br = 88.0
    bubble_layer = QImage(size, size, QImage.Format.Format_RGBA8888_Premultiplied)
    bubble_layer.fill(Qt.GlobalColor.transparent)
    bp = QPainter(bubble_layer)
    bp.setRenderHint(QPainter.RenderHint.Antialiasing, True)
    bp.scale(s, s)

    bubble = QPainterPath()
    bubble.addRoundedRect(QRectF(bx, by, bw, bh), br, br)
    tail = QPainterPath()
    tail.moveTo(bx + 82.0, by + bh - 10.0)
    tail.quadTo(bx + 54.0, by + bh + 44.0, bx + 28.0, by + bh + 66.0)
    tail.quadTo(bx + 22.0, by + bh + 72.0, bx + 34.0, by + bh + 70.0)
    tail.quadTo(bx + 98.0, by + bh + 52.0, bx + 168.0, by + bh - 2.0)
    tail.closeSubpath()
    bubble = bubble.united(tail)

    bub_grad = QLinearGradient(bx, by, bx + bw, by + bh)
    bub_grad.setColorAt(0.0, QColor("#252A36"))
    bub_grad.setColorAt(1.0, QColor("#171A21"))
    bp.setPen(
        QPen(
            QColor(168, 199, 250, 78),
            8.0,
            Qt.PenStyle.SolidLine,
            Qt.PenCapStyle.RoundCap,
            Qt.PenJoinStyle.RoundJoin,
        )
    )
    bp.setBrush(bub_grad)
    bp.drawPath(bubble)

    # Monochrome + soft blue caption bars inside the speech capsule
    bp.setPen(Qt.PenStyle.NoPen)
    bp.setBrush(QColor("#A8C7FA"))
    bp.drawRoundedRect(QRectF(bx + 74.0, by + 94.0, 214.0, 34.0), 17.0, 17.0)

    bp.setBrush(QColor("#ECEEF2"))
    bp.drawRoundedRect(QRectF(bx + 74.0, by + 166.0, 366.0, 40.0), 20.0, 20.0)

    bp.setBrush(QColor("#8E95A3"))
    bp.drawRoundedRect(QRectF(bx + 74.0, by + 240.0, 266.0, 34.0), 17.0, 17.0)

    # Punch out clean gap around top-right Gemini sparkle without leaving a black halo ring on the tile
    sx, sy = 716.0, 324.0
    bp.setCompositionMode(QPainter.CompositionMode.CompositionMode_Clear)
    bp.setBrush(Qt.GlobalColor.transparent)
    bp.drawPath(_sparkle_path(sx, sy, 184.0, pinch=0.175))
    bp.end()

    p.drawImage(0, 0, bubble_layer)

    # Gemini 4-point sparkle hero centerpiece
    star_path = _sparkle_path(sx, sy, 152.0, pinch=0.155)
    star_grad = QLinearGradient(sx - 130.0, sy - 130.0, sx + 130.0, sy + 130.0)
    star_grad.setColorAt(0.0, QColor("#4285F4"))
    star_grad.setColorAt(0.5, QColor("#9B72CB"))
    star_grad.setColorAt(1.0, QColor("#D96570"))
    p.setPen(Qt.PenStyle.NoPen)
    p.setBrush(star_grad)
    p.drawPath(star_path)

    # Tiny companion sparkle accent
    mini_path = _sparkle_path(836.0, 466.0, 40.0, pinch=0.18)
    p.setBrush(QColor("#A8C7FA"))
    p.drawPath(mini_path)

    p.end()
    return img


def save_ico(master: QImage, ico_path: Path, sizes: tuple[int, ...] = ICO_SIZES) -> None:
    """Pack scaled RGBA PNG frames into a standard Windows multi-resolution .ico file."""
    ico_path.parent.mkdir(parents=True, exist_ok=True)
    frames: list[tuple[int, bytes]] = []
    for sz in sizes:
        scaled = master.scaled(
            sz,
            sz,
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        )
        buf = QBuffer()
        buf.open(QIODevice.OpenModeFlag.WriteOnly)
        scaled.save(buf, "PNG")
        frames.append((sz, bytes(buf.data())))

    header = struct.pack("<HHH", 0, 1, len(frames))
    offset = 6 + 16 * len(frames)
    entries = []
    blobs = []
    for sz, png in frames:
        dim = 0 if sz >= 256 else sz
        entries.append(struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset))
        blobs.append(png)
        offset += len(png)

    ico_path.write_bytes(header + b"".join(entries) + b"".join(blobs))


def compile_desktop_exe(desktop_exe: Path, ico_path: Path) -> None:
    """Compile a zero-console Windows launcher .exe pointing to this project's .venv."""
    csc = Path(r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe")
    if not csc.exists():
        raise FileNotFoundError(f"C# compiler not found: {csc}")

    repo_literal = str(ROOT_DIR).replace("\\", "\\\\")
    cs_source = f'''using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Program
{{
    [STAThread]
    private static void Main()
    {{
        string root = "{repo_literal}";
        string pyw = Path.Combine(root, ".venv", "Scripts", "pythonw.exe");
        string py = Path.Combine(root, ".venv", "Scripts", "python.exe");
        string exe = File.Exists(pyw) ? pyw : py;

        if (!File.Exists(exe))
        {{
            MessageBox.Show(
                "Game Trans 가상환경(.venv)을 찾지 못했습니다:\\n" + exe,
                "Game Trans",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error
            );
            return;
        }}

        var psi = new ProcessStartInfo
        {{
            FileName = exe,
            Arguments = "-m game_trans",
            WorkingDirectory = root,
            UseShellExecute = false,
            CreateNoWindow = true
        }};
        Process.Start(psi);
    }}
}}
'''
    desktop_exe.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        cs_path = Path(tmp) / "Launcher.cs"
        cs_path.write_text(cs_source, encoding="utf-8")
        subprocess.run(
            [
                str(csc),
                "/nologo",
                "/target:winexe",
                "/optimize+",
                f"/win32icon:{ico_path}",
                f"/out:{desktop_exe}",
                str(cs_path),
            ],
            check=True,
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Game Trans icon and desktop launcher .exe")
    parser.add_argument("--preview", type=Path, default=None, help="Optional PNG path to save a 256x256 icon preview")
    parser.add_argument("--build-exe", type=Path, default=None, help="Output .exe path (e.g. Desktop\\Game Trans.exe)")
    args = parser.parse_args()

    _app = QGuiApplication(sys.argv[:1])
    master = render_master_icon(1024)
    save_ico(master, ICO_PATH)

    if args.preview is not None:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        master.scaled(
            256,
            256,
            Qt.AspectRatioMode.KeepAspectRatio,
            Qt.TransformationMode.SmoothTransformation,
        ).save(str(args.preview), "PNG")

    if args.build_exe is not None:
        compile_desktop_exe(args.build_exe, ICO_PATH)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
