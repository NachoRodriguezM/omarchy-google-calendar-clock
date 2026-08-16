# Omarchy Google Calendar and Clock

An Omarchy bar clock with a local-first calendar. It reads standard `.ics`
files through [Caldir](https://github.com/t4t5/caldir), supports local event
creation and editing, and can pull from or push to Google Calendar on demand.

Calendar data and OAuth credentials stay in Caldir's local directories. This
repository contains no calendar data, credentials, account names, or telemetry.

## Requirements

- Omarchy with the Quattro plugin API
- An x86-64 or ARM64 Linux system
- A Google account and your own Google Desktop OAuth client

The installer supplies the patched Caldir CLI and Google provider. Rust and a
separate Caldir installation are not required. Other tools used by setup—Bash,
Python, `curl`, `jq`, `tar`, and `sha256sum`—are already included with Omarchy.

## Install

Review the repository, then run its bootstrap command:

```bash
curl -fsSL https://raw.githubusercontent.com/NachoRodriguezM/omarchy-google-calendar-clock/main/install | bash -s -- https://github.com/NachoRodriguezM/omarchy-google-calendar-clock
```

It installs the plugin disabled, downloads a checksum-verified Caldir build for
your architecture, and waits while you complete Google's OAuth flow. The flow
asks for your own Google OAuth client ID and secret, so authentication happens
directly between this machine and Google; caldir.org is not involved.

If you prefer to run each trusted step yourself:

```bash
omarchy plugin add https://github.com/NachoRodriguezM/omarchy-google-calendar-clock --yes
~/.config/omarchy/plugins/omarchy-google-calendar-clock/setup
omarchy plugin disable omarchy.clock
omarchy plugin enable omarchy-google-calendar-clock center
```

Setup validates the release checksum, archive contents, binary version, OAuth
session, selected Google calendars, first pull, and local cache before the
bootstrap enables the plugin. A failure before OAuth completion restores the
previous binaries and removes only Google credentials created by that attempt.
It never deletes calendar files. A failure after successful authorization
preserves the setup so it can be retried safely with `./setup`.

## Use

Click the clock to open the calendar. The toolbar provides:

- `+` create an event
- `✓` preview local and remote differences
- `↓` pull the latest changes from Google
- `↑` push local changes to Google (with confirmation)

In the agenda, the next timed event of the day is highlighted, events with a
meeting link show a link button that opens it in your browser, and the
expanded description keeps its full text.

Timed events fire two desktop notifications: one five minutes before the
start and one at the start itself. Clicking a notification reopens the
calendar. Set `"eventNotifications": false` in the widget's `shell.json`
entry to disable them; fired reminders are remembered per event so a shell
restart cannot double-notify.

The plugin reads a local cache immediately, refreshes it in the background at
shell startup, and pulls again every 30 minutes. Automatic refresh is
pull-only: it never uploads local changes. The cache is stored with owner-only
permissions at `~/.local/state/omarchy/calendar-cache.json`.

Every pull also re-reads the current calendar colors from Google, because
Caldir only records them when a calendar is connected and would otherwise
keep showing the old palette forever. Colors that changed on the Google side
appear in the agenda and the month grid after the next pull.

The installed binaries live in `~/.local/share/omarchy-google-calendar-clock/bin` and are used
only by this plugin. Existing system Caldir installations are left untouched.
The release is built from pinned Caldir source plus the included compatibility
patch, so recurring-instance changes and supported edits
work without a local Rust toolchain.

## Update or remove

```bash
omarchy plugin update omarchy-google-calendar-clock
~/.config/omarchy/plugins/omarchy-google-calendar-clock/setup
omarchy plugin remove omarchy-google-calendar-clock
omarchy plugin enable omarchy.clock
```

Removing the plugin does not delete Caldir's `.ics` files, OAuth credentials,
the downloaded Caldir binaries, or the local cache. Delete those separately
only if you intend to remove your calendar data.

To remove everything the plugin installed, run its uninstall script before
removing the plugin:

```bash
~/.config/omarchy/plugins/omarchy-google-calendar-clock/uninstall
```

It removes the verified Caldir binaries and the local event cache, asks
separately about deleting your Google OAuth credentials and Caldir calendar
data, and re-enables the built-in `omarchy.clock` widget afterwards. Pass
`--yes` to skip the prompts after reviewing the script itself.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
