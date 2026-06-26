from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class AppConfig:
    database_path: str | None = None
    stockfish_path: str | None = None
    allow_cloud_fallback: bool = False


def _coerce_bool(value: Any, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return default

    parsed = str(value).strip().lower()
    if parsed in {"1", "true", "yes", "on"}:
        return True
    if parsed in {"0", "false", "no", "off"}:
        return False
    return default


def load_app_config(config_path: Path | None = None) -> AppConfig:
    root = Path(__file__).resolve().parent.parent
    path = config_path or (root / "config.json")

    if not path.exists():
        return AppConfig()

    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return AppConfig()

    if not isinstance(payload, dict):
        return AppConfig()

    database_path = str(payload.get("database_path") or "").strip() or None
    legacy_url = str(payload.get("database_url") or "").strip()
    if database_path is None and legacy_url.startswith("sqlite:///"):
        database_path = legacy_url.removeprefix("sqlite:///") or None
    if database_path is None and legacy_url and not legacy_url.startswith("postgres"):
        database_path = legacy_url
    stockfish_path = str(payload.get("stockfish_path") or "").strip() or None
    allow_cloud_fallback = _coerce_bool(payload.get("allow_cloud_fallback"), False)

    return AppConfig(
        database_path=database_path,
        stockfish_path=stockfish_path,
        allow_cloud_fallback=allow_cloud_fallback,
    )