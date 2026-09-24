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

## Sparkle installation checks

Routine releases do not repeat isolated production-update acceptance. The owner
confirmed public update acceptance across three recent small releases. Use the
checks below when changing the updater, signing, packaging, installer permissions
or appcast behavior, when investigating an update regression, or when explicitly
requested. Exact remote release-asset readback remains required for every release.

Manual signing resolves entitlement variables before codesign. Both signing and
bundle verification read the actual embedded DER/XML entitlements through Security
and reject unresolved variables or incorrect installer Mach service names.
`make verify-signing-entitlements` covers resolution, unchanged Finder permissions
and invalid-input rejection without signing keys.

`bash scripts/build_sparkle_installation_harness.sh` creates an isolated sandbox
host and signed update, using the production signing script and an in-memory
fixture-only Ed25519 key. Serve its `server` directory on the loopback port in
`fixture.json`, launch `installation/UpgradeQA.app`, and choose Run isolated update.
The QA driver accepts download/install for that explicit test action. Require a running build 2 at the same
installation path, with both launch PIDs recorded in that fixture's private
container (also displayed in the QA window). It uses a minimal QA driver and an inert extension bundle;
it proves sandbox installer replacement/relaunch, not FileMint's custom driver,
public-feed restrictions, installed Finder callbacks or clean-Mac permissions.

`UpdateInstallationTests` binds the selected release version, URL and size,
rejects informational/delta updates and covers restart protection. The Python
appcast tests reject mismatched metadata, unexpected payloads and malformed
signatures. These run offline in `make verify`.
After the app build, `make verify-sparkle-driver` compiles the production driver
against the real Sparkle framework with test UI sinks. It exercises callbacks,
Objective-C delegate selectors, cancellation, progress, restart deferral and
errors without starting network requests or installing anything. It does not
replace the signed sandbox installation acceptance below.

For targeted release acceptance, use two signed sandbox builds in an isolated installation:

1. Confirm automatic discovery never downloads or opens windows; disabling it
   cancels only discovery. Manual checks remain available.
2. Choose Update and Restart. Show progress; cancel during checking/download and
   retry. No save dialog or Finder installation step should appear.
3. Alter the appcast version/URL/size, archive bytes or signing key. Each must fail
   without replacing the installed app. Retry a valid release afterward.
4. Open a creation draft or begin quick creation while downloading. Installation
   must preserve work and require retry after it is finished; no forced quit.
5. Complete a valid upgrade. Verify the actual running bundle path, new version,
   old process exit and helper cleanup. Check Finder creation, preferences,
   bookmarks, login and menu bar settings. Do not claim helper replacement or
   rollback from download success alone.
6. Test a readonly DMG and an installation owned by another user; report the
   actual authorization/failure behavior. No quarantine bypass is permitted.

## Legacy client compatibility

The following checks cover the retained manual downloader only; they do not
exercise the production Sparkle installer or establish auto-update acceptance.

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
