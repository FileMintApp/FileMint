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

The isolated template fixture also exercises the production `UpdateModel` with
native sheets, app-modal dialogs and real one-shot timers. Build it with
`bash scripts/build_template_workflow_harness.sh`, then run its executable with
`FILEMINT_TEMPLATE_QA_MODE=review-fixes`. The fixture uses temporary preferences,
an accelerated startup delay and an injected metadata response, with no network
or installation. It checks unchanged settings/import revisions while a sheet is
active (including a previously armed timer), single resumption after dismissal
or app-modal order-out,
disabling deferred checks, manual checks with discovery off, and in-flight
cancellation. This proves local scheduling, not a public update installation.

`AppUpdateTests` covers numeric stable-version comparison, no downgrades, release
and asset validation, trusted download/redirect URLs, exact checksum filenames,
digest mismatches, sandbox no-user-consent quarantine rejection, and bilingual
About/update text, including the exact special-thanks nickname and GitHub link. Network and native installer
opening remain app responsibilities; record live checks, download/cancel/retry
and installation handoff evidence in `docs/ACCEPTANCE.md`.

## Sparkle installation checks

Routine releases do not repeat old-to-new installation acceptance. UpgradeQA is
an optional installer diagnostic, not a standard release step. Omitting that
fixture does not remove `make release-local`, `make publish-local` or checks
selected by [HARNESS](../HARNESS.md) for updater, signing, packaging, installer
permissions or appcast changes. When actual installation behavior needs proof,
use signed old/new FileMint runtime evidence; UpgradeQA's minimal host cannot
stand in for it. Publication uses the locally verified signed candidate and
uploads a draft Release. Following the owner's 2026-10-08 policy, it omits local
remote-asset downloads and content comparisons. Source CI, remote candidate
verification and applicable website builds must pass before stable/Latest
publication; website deployment follows afterward. The candidate job invokes the
full artifact verifier with the expected build, including nested Sparkle signatures,
installer configuration, resolved Mach permissions, public-key/EdDSA validation,
final URLs and sizes. Public metadata must still satisfy the existing client's
Latest DMG discovery contract, while new clients select ZIP and `appcast-zip.xml`.
The candidate contains both archives/checksums and both feeds. Verify each
archive's signature and ticket; the signed app code hash must be identical across
DMG and ZIP. ZIP validation rejects escaping paths/links and oversized expansion
before extraction. A website failure must not relabel a public app as
unpublished. These checks do not by themselves prove an installed upgrade.

Manual signing resolves entitlement variables before codesign. Both signing and
bundle verification read the actual embedded DER/XML entitlements through Security
and reject unresolved variables or incorrect installer Mach service names.
`make verify-signing-entitlements` covers resolution, unchanged Finder permissions
and invalid-input rejection without signing keys.

`bash scripts/build_sparkle_installation_harness.sh` creates an isolated sandbox
host and signed update, using the production signing script and an in-memory
fixture-only Ed25519 key. Run the unsigned app build first; the fixture copies
its compression framework so the production signing path covers that dependency.
Serve its `server` directory on the loopback port in
`fixture.json`, launch `installation/UpgradeQA.app`, and choose Run isolated update.
The QA driver accepts download/install for that explicit test action. Require a running build 2 at the same
installation path, with both launch PIDs recorded in that fixture's private
container (also displayed in the QA window). It uses a minimal QA driver and an inert extension bundle;
it proves sandbox installer replacement/relaunch, not FileMint's custom driver,
public-feed restrictions, installed Finder callbacks or clean-Mac permissions.
On macOS 27.2, the default ad-hoc fixture was rejected because its process and
embedded Sparkle framework had different Team IDs. A diagnostic run there needs
the existing local Developer ID identity; a failed fixture launch is not evidence
of a defect in the published FileMint app.

`UpdateInstallationTests` binds the selected release version, URL and size,
rejects informational/delta updates and covers restart protection. The Python
appcast tests reject mismatched metadata, crossed DMG/ZIP feeds, unexpected payloads
and malformed signatures. ZIP tests exercise real ditto symlink/permission
round-trips, offline ticket adapters, immutable resume and both artifact checks.
`AppUpdateTests` covers ZIP preference, historical DMG fallback and rejection of
partial/duplicate/untrusted ZIP sets. These run offline in `make verify`.
After the app build, `make verify-sparkle-driver` compiles the production driver
against the real Sparkle framework with test UI sinks. It exercises callbacks,
Objective-C delegate selectors, cancellation, progress, restart deferral and
errors without starting network requests or installing anything. It does not
prove installer replacement or relaunch on its own.

When a signed old-to-new native update check is selected for changed behavior,
a regression or an explicit request, use two sandbox builds in an isolated
installation:

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
   For ZIP migration, cover an existing DMG client using the unchanged legacy feed
   and a new client using the ZIP feed; also cover a client that skips intervening
   versions. Preserve the same application identity, signing key and permissions.
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
