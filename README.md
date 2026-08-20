# Omarchy Google Calendar and Clock

An Omarchy bar clock with a local-first calendar. It reads standard `.ics`
files through [Caldir](https://github.com/t4t5/caldir), supports local event
creation and editing, and can pull from or push to Google Calendar on demand.

Source calendar data and OAuth credentials stay in Caldir's local directories;
the plugin keeps only an owner-readable derived event cache. This repository
contains no calendar data, credentials, account names, or telemetry.

This plugin is based on the built-in `omarchy.clock` plugin and is intended as
a replacement that preserves the original clock functionality.

## Requirements

- Omarchy with the Quattro plugin API
- An x86-64 or ARM64 Linux system
- For Google sync: a Google account, plus either hosted OAuth or your own
  Desktop OAuth client for direct mode

The installer supplies the patched Caldir CLI and Google provider. Rust and a
separate Caldir installation are not required. Other tools used by setup—Bash,
Python, `curl`, `jq`, `tar`, and `sha256sum`—are already included with Omarchy.

## Install

Review the repository, then run its bootstrap command:

```bash
curl -fsSL https://raw.githubusercontent.com/NachoRodriguezM/omarchy-google-calendar-clock/main/install | bash -s -- https://github.com/NachoRodriguezM/omarchy-google-calendar-clock
```

Append `--hosted` to the bootstrap command to use caldir.org's hosted OAuth
relay instead of your own Google Cloud client:

```bash
curl -fsSL https://raw.githubusercontent.com/NachoRodriguezM/omarchy-google-calendar-clock/main/install | bash -s -- https://github.com/NachoRodriguezM/omarchy-google-calendar-clock --hosted
```

It installs the plugin disabled, downloads a checksum-verified Caldir build for
your architecture, and waits while you complete Google's OAuth flow.

## Google setup options

Two OAuth modes are available; both give the same Google access, but differ in
who performs the sign-in and how tokens stay fresh:

**Direct (default, recommended).** Setup asks for your own Google OAuth client
ID and secret, so authentication happens directly between this machine and
Google; caldir.org is never involved. Requires creating a Desktop OAuth client
in your Google Cloud project (instructions are shown during setup).

**Hosted.** Setup uses caldir.org's relay with its own Google Cloud client, so
no Google Cloud project is needed — just sign in with your Google account.

The trade-off: with hosted auth, caldir.org relays the sign-in and every
later token refresh. If that service is unreachable or retired, an existing
hosted session can no longer refresh its tokens. With direct auth, nothing
depends on caldir.org at all.

Choose the mode when you run setup:

```bash
./setup              # direct (default)
./setup --hosted     # hosted via caldir.org
```

These options select the mode when creating a new session. Setup reuses an
existing session; use the mode-switch command below to change one.

The full trade-off is also printed by setup at the moment of choosing, so the
decision is always an informed one.

### Switching modes later

You can switch between the two modes at any time without reinstalling:

```bash
~/.config/omarchy/plugins/omarchy-google-calendar-clock/scripts/calendar-auth-mode switch hosted
~/.config/omarchy/plugins/omarchy-google-calendar-clock/scripts/calendar-auth-mode switch direct
```

The switch signs the current session out and re-runs the interactive
sign-in in the chosen mode. Your own OAuth client (client ID and secret) is
never deleted: it is parked aside when you leave direct mode and restored
when you come back, so you can move back and forth freely. Check the current
mode with:

```bash
~/.config/omarchy/plugins/omarchy-google-calendar-clock/scripts/calendar-auth-mode status --json
```

If you prefer to run each trusted step yourself:

```bash
omarchy plugin add https://github.com/NachoRodriguezM/omarchy-google-calendar-clock --yes
~/.config/omarchy/plugins/omarchy-google-calendar-clock/setup
omarchy plugin disable omarchy.clock
omarchy plugin enable omarchy-google-calendar-clock center
```

`omarchy plugin add … --enable` also works directly: the plugin runs as a
plain clock immediately, and when you open the calendar panel it detects the
missing Caldir runtime, shows Direct setup and Hosted setup choices with their
OAuth trade-off, then starts the selected interactive flow in a floating
terminal. Sync actions remain visible; until setup completes, using one shows
a setup-required message.

Setup validates the release checksum, archive contents, binary version, OAuth
session, selected Google calendars, first pull, and local cache before the
bootstrap enables the plugin. Before calendar validation completes, a failure
restores the previous binaries. Google provider configuration created from
scratch is removed; pre-existing provider configuration is left untouched.
Calendar files are never deleted. A failure after successful authorization
preserves the setup so it can be retried safely with `./setup`.

## Use

Click the clock to open the calendar. The toolbar provides:

- `+` create an event
- `✓` preview local and remote differences
- `↓` pull the latest changes from Google
- `↑` push local changes to Google (with confirmation)

The settings button in the calendar's top-right corner opens a separate card
beside the calendar. It can switch between hosted and direct Google OAuth
(using the interactive terminal flow) and choose how calendars are colored:

- **Google** uses each calendar's original Google Calendar color.
- **Theme** alternates calendars between the active Omarchy theme's accent and
  urgent colors, falling back to muted or foreground if those match. These
  update immediately whenever the Omarchy theme changes.

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

The installed binaries live in `~/.local/share/omarchy-google-calendar-clock/bin` and are used
only by this plugin. Existing system Caldir installations are left untouched.
The release is built from pinned Caldir source plus the included compatibility
patch, so recurring-instance changes and supported edits
work without a local Rust toolchain.

## Update or remove

To update:

```bash
omarchy plugin update omarchy-google-calendar-clock
~/.config/omarchy/plugins/omarchy-google-calendar-clock/setup
```

To remove the plugin and its runtime:

```bash
~/.config/omarchy/plugins/omarchy-google-calendar-clock/uninstall
```

Removing the plugin does not delete Caldir's `.ics` files, OAuth credentials,
the downloaded Caldir binaries, or the local cache. Delete those separately
only if you intend to remove your calendar data.

To remove everything the plugin installed, run its uninstall script before
removing the plugin:

```bash
~/.config/omarchy/plugins/omarchy-google-calendar-clock/uninstall
```

It removes the plugin, verified Caldir binaries, and local event cache; restores
the built-in clock to the center of the bar; and asks separately about deleting
your Google OAuth credentials and Caldir calendar
data, and re-enables the built-in `omarchy.clock` widget afterwards. Pass
`--yes` to skip the prompts after reviewing the script itself.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
