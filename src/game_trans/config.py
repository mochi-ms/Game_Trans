"""User configuration (TOML <-> dataclasses) and user JSON data.

Location: ``%APPDATA%\\GameTrans\\config.toml``. See ``config.example.toml``.
The API key is *never* stored here – see :mod:`game_trans.platform.secrets`.
"""

from __future__ import annotations

import json
import logging
import os
import tomllib
from dataclasses import asdict, dataclass, field, fields, is_dataclass
from pathlib import Path
from typing import Any

log = logging.getLogger(__name__)


def app_dir() -> Path:
    base = os.environ.get("APPDATA") or str(Path.home() / ".config")
    return Path(base) / "GameTrans"


@dataclass
class General:
    my_language: str = "ko"
    partner_language: str = "auto"
    start_with_windows: bool = False
    auto_listen_on_game_start: bool = True
    onboarding_done: bool = False


@dataclass
class Pricing:
    input_per_mtok: float = 0.30
    output_per_mtok: float = 2.50


@dataclass
class AI:
    model: str = "gemini-3.5-flash-lite"
    mode: str = "cloud"  # "cloud" | "local"
    rpm_limit: int = 10
    fallback_to_local_on_quota: bool = False
    show_pronunciation: bool = True
    tone: str = "casual"
    context_lines: int = 3
    pricing: Pricing = field(default_factory=Pricing)


@dataclass
class Budget:
    monthly_budget_usd: float = 9.0
    warn_ratio: float = 0.8


@dataclass
class Audio:
    capture: str = "process"  # "process" | "device"
    target_processes: list[str] = field(default_factory=lambda: ["RobloxPlayerBeta.exe"])
    speech_threshold: float = 0.5
    min_speech_ms: int = 300
    silence_end_ms: int = 450
    max_segment_s: float = 8.0
    pre_roll_ms: int = 200
    bgm_suppression: bool = False


@dataclass
class VoiceOut:
    enabled: bool = True
    engine: str = "edge"  # "edge" | "gemini" | "sapi"
    output_device: str = "CABLE Input"
    monitor_device: str = ""
    mix_microphone: bool = False
    mic_device: str = ""
    voice: str = "en-US-AndrewNeural"
    rate: str = "+0%"


@dataclass
class Overlay:
    position: str = "top-right"
    font_size: int = 18
    opacity: float = 0.80
    caption_duration_s: int = 6
    max_captions: int = 4
    show_original: bool = True
    reduce_motion: bool = False
    click_through: bool = False
    offset_x: int = 0
    offset_y: int = 0
    layout_version: int = 2


@dataclass
class Hotkeys:
    toggle_input: str = "Ctrl+Shift+Space"
    repeat_last: str = "Ctrl+Shift+S"
    toggle_listen: str = "Ctrl+Shift+L"
    history: str = "Ctrl+Shift+H"
    edit_overlay: str = "Ctrl+Shift+E"


@dataclass
class Config:
    general: General = field(default_factory=General)
    ai: AI = field(default_factory=AI)
    budget: Budget = field(default_factory=Budget)
    audio: Audio = field(default_factory=Audio)
    voice_out: VoiceOut = field(default_factory=VoiceOut)
    overlay: Overlay = field(default_factory=Overlay)
    hotkeys: Hotkeys = field(default_factory=Hotkeys)


DEFAULT_PHRASES: list[dict[str, str]] = [
    {"emoji": "👋", "text": "안녕!"},
    {"emoji": "🙏", "text": "고마워!"},
    {"emoji": "🏃", "text": "따라와!"},
    {"emoji": "🤝", "text": "트레이드 할래?"},
    {"emoji": "⏳", "text": "잠깐만 기다려줘"},
    {"emoji": "🎉", "text": "나이스! 잘했어!"},
]


def _merge(obj: Any, data: dict[str, Any]) -> Any:
    """Recursively apply a TOML dict onto a dataclass instance, ignoring unknown keys."""
    for f in fields(obj):
        if f.name not in data:
            continue
        current = getattr(obj, f.name)
        value = data[f.name]
        if is_dataclass(current) and isinstance(value, dict):
            _merge(current, value)
        else:
            setattr(obj, f.name, value)
    return obj


def _toml_value(val: Any) -> str:
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, (int, float)):
        return repr(val)
    if isinstance(val, str):
        return json.dumps(val, ensure_ascii=False)
    if isinstance(val, list):
        return "[" + ", ".join(_toml_value(item) for item in val) + "]"
    raise TypeError(f"Unsupported TOML value type: {type(val)!r}")


def _dump_toml(data: dict[str, Any], prefix: str = "") -> list[str]:
    lines: list[str] = []
    tables: list[tuple[str, dict[str, Any]]] = []
    for k, v in data.items():
        if isinstance(v, dict):
            tables.append((f"{prefix}.{k}" if prefix else k, v))
        else:
            lines.append(f"{k} = {_toml_value(v)}")
    for table_name, table_dict in tables:
        if lines:
            lines.append("")
        lines.append(f"[{table_name}]")
        lines.extend(_dump_toml(table_dict, table_name))
    return lines


def load_config(path: Path | None = None) -> Config:
    path = path or app_dir() / "config.toml"
    cfg = Config()
    if path.exists():
        with path.open("rb") as fp:
            raw = tomllib.load(fp)
        _merge(cfg, raw)
        overlay_raw = raw.get("overlay")
        if isinstance(overlay_raw, dict) and "layout_version" not in overlay_raw:
            if cfg.overlay.position == "bottom-center" or cfg.overlay.offset_y < -150:
                cfg.overlay.position = "top-right"
                cfg.overlay.offset_x = 0
                cfg.overlay.offset_y = 0
            cfg.overlay.opacity = max(0.78, cfg.overlay.opacity)
            cfg.overlay.font_size = min(22, cfg.overlay.font_size)
            cfg.overlay.max_captions = max(4, cfg.overlay.max_captions)
            cfg.overlay.layout_version = 2
    return cfg


def save_config(cfg: Config, path: Path | None = None) -> Path:
    path = path or app_dir() / "config.toml"
    path.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(_dump_toml(asdict(cfg))) + "\n"
    path.write_text(text, encoding="utf-8")
    return path


def load_phrases(path: Path | None = None) -> list[dict[str, str]]:
    path = path or app_dir() / "phrases.json"
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, list):
                return [
                    {"emoji": str(x.get("emoji", "💬")), "text": str(x.get("text", ""))}
                    for x in data
                    if isinstance(x, dict) and str(x.get("text", "")).strip()
                ]
        except (OSError, json.JSONDecodeError, ValueError, TypeError) as e:
            log.warning("Failed reading %s (%s); using defaults", path, e)
    return [dict(item) for item in DEFAULT_PHRASES]


def save_phrases(phrases: list[dict[str, str]], path: Path | None = None) -> Path:
    path = path or app_dir() / "phrases.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(phrases, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def load_glossary(path: Path | None = None) -> list[str]:
    path = path or app_dir() / "glossary.json"
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, list):
                return [str(x).strip() for x in data if str(x).strip()]
        except (OSError, json.JSONDecodeError, ValueError, TypeError) as e:
            log.warning("Failed reading %s (%s); returning empty glossary", path, e)
    return []


def save_glossary(terms: list[str], path: Path | None = None) -> Path:
    path = path or app_dir() / "glossary.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    cleaned = [t.strip() for t in terms if t.strip()]
    path.write_text(json.dumps(cleaned, ensure_ascii=False, indent=2), encoding="utf-8")
    return path
