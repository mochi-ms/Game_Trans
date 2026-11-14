from __future__ import annotations

from game_trans.config import load_config
from game_trans.ui.bridge import Backend


def test_overlay_v2_defaults(tmp_path) -> None:
    cfg = load_config(tmp_path / "missing.toml")
    assert cfg.overlay.position == "top-right"
    assert cfg.overlay.max_captions == 4
    assert cfg.overlay.click_through is False
    assert cfg.overlay.layout_version == 2


def test_overlay_migrates_legacy_v1_centered_offset(tmp_path) -> None:
    p = tmp_path / "config.toml"
    p.write_text(
        '[overlay]\nposition = "bottom-center"\nfont_size = 27\nopacity = 0.35\noffset_x = 36\noffset_y = -597\n',
        encoding="utf-8",
    )
    cfg = load_config(p)
    assert cfg.overlay.position == "top-right"
    assert cfg.overlay.offset_x == 0
    assert cfg.overlay.offset_y == 0
    assert cfg.overlay.opacity >= 0.78
    assert cfg.overlay.max_captions >= 4
    assert cfg.overlay.layout_version == 2


def test_overlay_v2_preserves_explicit_custom_layout(tmp_path) -> None:
    p = tmp_path / "config.toml"
    p.write_text(
        '[overlay]\nlayout_version = 2\nposition = "bottom-left"\nopacity = 0.5\noffset_x = 12\noffset_y = -20\n',
        encoding="utf-8",
    )
    cfg = load_config(p)
    assert cfg.overlay.position == "bottom-left"
    assert cfg.overlay.opacity == 0.5
    assert cfg.overlay.offset_x == 12
    assert cfg.overlay.offset_y == -20


def test_overlay_base_pos_top_right_aligns_below_status_pill() -> None:
    bx, by = Backend._overlay_base_pos("top-right", 1920, 1080, 410, 320)
    assert bx == 1920 - 410 - 28
    assert by == 66.0

    lx, ly = Backend._overlay_base_pos("top-left", 1920, 1080, 410, 320)
    assert (lx, ly) == (24.0, 24.0)
