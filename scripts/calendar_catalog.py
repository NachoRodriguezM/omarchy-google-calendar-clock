#!/usr/bin/env python3
"""Provider-neutral local Caldir calendar catalog."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
COLOR_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")


class CalendarCatalogError(Exception):
    pass


def caldir_binary() -> Path:
    return SCRIPT_DIR / "calendar-caldir"


def caldir_config() -> dict:
    binary = caldir_binary()
    if not os.access(binary, os.X_OK):
        raise CalendarCatalogError("Caldir is not installed")
    try:
        result = subprocess.run(
            [str(binary), "config", "--json"],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return json.loads(result.stdout)["config"]
    except (OSError, subprocess.CalledProcessError, KeyError, json.JSONDecodeError) as error:
        raise CalendarCatalogError("Could not read the Caldir configuration") from error


def calendar_root(config: dict) -> Path:
    try:
        return Path(str(config["calendar_dir"])).expanduser().resolve()
    except KeyError as error:
        raise CalendarCatalogError("Caldir does not define a calendar directory") from error


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as error:
        raise CalendarCatalogError(f"Could not read {path}") from error


def _toml_string(text: str, key: str) -> str:
    match = re.search(rf'(?m)^{re.escape(key)}\s*=\s*"([^"\r\n]*)"\s*$', text)
    return match.group(1) if match else ""


def _toml_bool(text: str, key: str) -> bool:
    match = re.search(rf"(?m)^{re.escape(key)}\s*=\s*(true|false)\s*$", text)
    return match is not None and match.group(1) == "true"


def load_calendar_catalog() -> dict:
    config = caldir_config()
    root = calendar_root(config)
    default_calendar = str(config.get("default_calendar") or "")
    calendars = []

    if root.exists():
        for calendar_path in sorted(path for path in root.iterdir() if path.is_dir()):
            config_path = calendar_path / ".caldir" / "config.toml"
            if not config_path.is_file():
                continue
            text = _read_text(config_path)
            color = _toml_string(text, "color")
            calendars.append({
                "slug": calendar_path.name,
                "name": _toml_string(text, "name") or calendar_path.name,
                "provider": _toml_string(text, "provider"),
                "color": color if COLOR_PATTERN.fullmatch(color) else "",
                "read_only": _toml_bool(text, "read_only"),
                "is_default": calendar_path.name == default_calendar,
            })

    return {
        "calendar_dir": str(root),
        "default_calendar": default_calendar,
        "calendars": calendars,
    }


def calendar_map(catalog: dict) -> dict[str, dict]:
    return {str(entry["slug"]): entry for entry in catalog.get("calendars", [])}


def resolve_calendar(catalog: dict, slug: str) -> dict:
    entry = calendar_map(catalog).get(str(slug))
    if not entry:
        raise CalendarCatalogError("The selected calendar does not exist")
    return entry


def writable_calendar(catalog: dict, slug: str) -> dict:
    entry = resolve_calendar(catalog, slug)
    if entry.get("read_only"):
        raise CalendarCatalogError("This calendar is read-only")
    return entry


def calendar_path(catalog: dict, slug: str) -> Path:
    root = Path(str(catalog["calendar_dir"]))
    return (root / str(slug)).resolve()


def default_writable_calendar_slug(catalog: dict) -> str:
    default_calendar = str(catalog.get("default_calendar") or "")
    if default_calendar:
        entry = calendar_map(catalog).get(default_calendar)
        if entry and not entry.get("read_only"):
            return default_calendar
    for entry in catalog.get("calendars", []):
        if not entry.get("read_only"):
            return str(entry["slug"])
    raise CalendarCatalogError("No writable calendars are configured")


def main() -> None:
    try:
        json.dump(load_calendar_catalog(), sys.stdout)
        sys.stdout.write("\n")
    except CalendarCatalogError as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
