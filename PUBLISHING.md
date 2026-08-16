# Publishing

Omarchy Google Calendar and Clock uses GitHub Releases to provide patched
Caldir binaries without requiring users to install Rust.

Safe install and removal are both shipped in the repository: `install` clones
and enables the plugin after `setup` finishes, and `uninstall` removes the
downloaded binaries and cache, asks separately before deleting OAuth
credentials or calendar data, and re-enables the built-in `omarchy.clock`.

## First release

1. Review and commit the repository using the public Git identity you want.
2. Push the `main` branch to a public GitHub repository.
3. Confirm GitHub Actions are enabled.
4. Tag the manifest version and push it:

   ```bash
   git tag v0.1.0
   git push origin main v0.1.0
   ```

The release workflow verifies that the tag matches `manifest.json`, builds the
pinned and patched Caldir CLI and Google provider on native x86-64 and ARM64
runners, creates SHA-256 checksums, and attaches the assets to a GitHub release.
The public installer is usable after both build jobs finish.

## Updating

For each release:

1. Update `manifest.json` and test the plugin.
2. If the Caldir base changes, update the commit and version in `setup` and
   `.github/workflows/release.yml`, regenerate the patch, and run provider tests.
3. Commit, tag the exact plugin version with a leading `v`, and push.

Never upload locally built binaries, calendar files, OAuth configuration, cache
files, or session data to the repository. Release binaries must come from the
auditable GitHub Actions workflow.
