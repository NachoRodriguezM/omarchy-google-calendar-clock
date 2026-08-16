# Repository Guidelines

## Project Structure & Module Organization

This is an Omarchy Quickshell bar-widget plugin. `manifest.json` defines the
published plugin identity and entry point. `BarWidget.qml` owns the bar label
and popup host; `Panel.qml` contains the calendar UI and process orchestration.
`Model.js` and `CalendarModel.js` hold pure date, formatting, and event-indexing
logic. The `scripts/` directory is the local bridge to Caldir; keep shell and
Python helpers portable and relative to their own directory. `patches/` holds
the pinned Caldir Google-provider patch. Release automation lives in
`.github/workflows/release.yml`.

## Build, Test, and Development Commands

Run these from the repository root:

```bash
omarchy plugin validate .              # validate manifest and plugin layout
bash -n install setup scripts/*         # shell syntax checks
python3 -c 'compile(open("scripts/calendar-create").read(), "calendar-create", "exec")'
```

For Google-provider changes, test the pinned Caldir checkout separately:

```bash
cargo test --manifest-path /path/to/caldir/Cargo.toml -p caldir-provider-google
```

User plugin changes hot-reload. Use `omarchy restart shell` only when a reload
does not apply cleanly. Never edit `/usr/share/omarchy`.

## Coding Style & Naming Conventions

Use two-space QML/JavaScript indentation and four-space Python indentation.
Keep QML state on `root`, use lowerCamelCase properties/functions, and name
processes descriptively (for example, `calendarPullProcess`). Shell scripts use
`set -euo pipefail`, uppercase constants, and hyphenated filenames such as
`calendar-cache-update`. Preserve JSON bridge contracts and validate external
input before using it in filesystem or provider commands.

## Testing & Security

Do not commit `.ics` files, calendar cache, OAuth tokens, account names, or
locally built binaries. Use generic fixture names only. Pull operations may
read remote data; push remains explicit and confirmed. Keep release binaries
out of Git: the workflow builds them from the pinned Caldir commit and verifies
the patch.

## Commits & Pull Requests

This repository has no committed history yet, so no existing message convention
applies. Use short imperative subjects, e.g. `Fix status pull range`. Keep each
commit focused. Pull requests should explain user-visible behavior, list checks
run, link relevant issues, and include screenshots for QML layout changes.
