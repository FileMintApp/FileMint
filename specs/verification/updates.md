# Update verification

Load when planning or performing About/updater verification. See the
[update contract](../domains/updates.md) and [verification matrix](../HARNESS.md).

`AutomaticUpdateTests` covers default-on migration, saved off/attempt persistence,
the seven-day boundary, re-enabling without resetting the cooldown, clock
rollback recovery, and bilingual automatic-update and extension setup guidance.
Native checks should exercise the first delayed check, disabling during an
automatic check, manual checks with the switch off, and quiet update discovery
with settings closed. No-update/failure outcomes must not open a window; an
available update must appear in settings and the menu without starting a download.

`AppUpdateTests` covers numeric stable-version comparison, no downgrades, release
and asset validation, trusted download/redirect URLs, exact checksum filenames,
digest mismatches, sandbox no-user-consent quarantine rejection, and bilingual
About/update text, including the exact special-thanks nickname and GitHub link. Network and native installer
opening remain app responsibilities; record live checks, download/cancel/retry
and installation handoff evidence in `docs/ACCEPTANCE.md`.

`make verify-updates` is an opt-in network smoke check using the real app client.
It queries the public release, verifies the equal-version result, cancels after
download bytes arrive, checks cleanup, retries the complete download, and checks
SHA-256, size and macOS quarantine. It removes temporary artifacts and never
opens the DMG or installs an app. This command requires macOS and GitHub access;
ordinary `make verify` stays offline.

The command-line smoke also preserves an existing destination on cancellation
and rejects a saved installer modified before reopening. It does not run in App
Sandbox and cannot prove a downloaded installer will launch.

`make update-sandbox-harness` builds an interactive, ad-hoc-signed app with App
Sandbox, outbound networking and user-selected file access. It uses the actual
`UpdateClient` and does not open an installer automatically. Launch the printed
app, then:

1. Check the release.
2. Choose “Reject unapproved save”; the client must reject the private-container
   installer with the sandbox no-user-consent execution bit.
3. Cancel “Save with system dialog”; no download should start.
4. Save with the system dialog into a disposable directory. Download, checksum
   validation and quarantine preflight must pass, with internet quarantine
   present and no sandbox execution-block bit.
5. Complete a real Finder copy/eject/relaunch check using the approved installer.
   Verify saved bytes, running app version and Finder menu before recording it
   as a successful installation. Close the harness and remove only its temporary
   build and test downloads after inspection.
