# Task: ZIP distribution with compatible DMG updates

Status: complete
Next action: Review local changes. For a requested release, select a fresh version
and run the six-asset release gates and targeted real FileMint update acceptance.

## Objective and scope

- New clients use a signed ZIP for Update and Restart. Existing clients continue
  to discover and install the DMG of the same latest version with no manual reinstall.
- Retain both formats and their own immutable appcasts on every future stable
  release. Source changes and local verification are in scope; version bump,
  commit, push, production installation and public release are separate actions.
- Reject incomplete ZIP sets, mismatched feeds, changed candidates and unverified
  archives. Retain existing keys, sandbox permissions and restart protection.

## Selected context

- Contracts: [Updates](../../specs/domains/updates.md),
  [Distribution](../../specs/domains/distribution.md).
- Entry points: `AppUpdate`, `UpdateInstallationPolicy`, packaging/release scripts,
  appcast generator and the draft verification workflow.
- Verification: [HARNESS](../../specs/HARNESS.md),
  [Update checks](../../specs/verification/updates.md),
  [Distribution procedure](../DISTRIBUTION.md).
- Load presentation rules only if website/download UI changes become necessary.

## Decisions and progress

- Keep legacy `appcast.xml` pointing at DMG; add `appcast-zip.xml` for new clients.
  A single transitional release cannot support users who skip it, because old
  clients discover Latest rather than walking every intermediate release.
- Generate ZIP from the accepted DMG's application and staple that app's ticket.
  Preserve one signed payload and the existing resumable DMG notarization flow.
- Update both owning contracts before implementation.
- Implemented ZIP preference with strict metadata validation and historical DMG
  fallback, two separately signed feeds, six-asset draft publication, four bound
  archive/feed hashes, and verified app-code-hash equality across the archives.
- Added immutable ZIP packaging checkpoints, safe ZIP layout validation and
  regression coverage for malformed/partial sets, wrong feeds, changed payloads,
  interrupted packaging and old-client Latest compatibility.
- The isolated installer harness now includes the compression framework required
  by the production signing script; both its bundles use the existing Developer ID
  identity and an ephemeral in-memory update key.

## Evidence

Tested commit/worktree: primary checkout, uncommitted changes based on
`96b18b66215ba87dee32ea4087e7a8268106a65a`.
Environment: arm64 macOS 27.2, Xcode 27.0 (27A266a), 2026-10-10.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 222 Core tests, 22 image tests, Harness/CLI, appcast, ZIP, resume, publication and entitlement checks; log: `/private/tmp/filemint-zip-verify.log`. |
| Unsigned Release `make build` | passed | Actual App/Finder/Sparkle build; log: `/private/tmp/filemint-zip-build.log`. |
| `make verify-sparkle-driver` | passed | Production driver against actual Sparkle, with UI sinks; log: `/private/tmp/filemint-zip-driver.log`. |
| Compiled old/new update policies | passed | Unmodified pre-change source chooses DMG/appcast.xml; current source chooses ZIP/appcast-zip.xml from identical six-asset Latest data, including skipped versions; log: `/private/tmp/filemint-zip-legacy.log`. |
| Notarized artifact ZIP/pair check | passed | Derived ZIP from a private copy of existing 0.6.8/build 27 DMG. App ticket, final EdDSA signature, both feeds and identical code hashes verified; log: `/private/tmp/filemint-zip-package.log`. Used 0.6.8's original bundle verifier for its historical payload, which predates the compression runtime. Current production checks remain unchanged. |
| Signed sandbox ZIP replacement/relaunch | passed | Native UI showed build 1 PID 14588 → build 2 PID 14657 at the same `run.Fc1VJJ/installation/UpgradeQA.app` path. Download, extraction, replacement and relaunch completed with one test action. The fixture is a minimal host, not FileMint's full UI/Finder runtime. |
| Signed old/new full FileMint installed update | not-run | Must be verified separately for the release candidate; the minimal host and compiled policies do not establish full installed Finder/preferences behavior. |
| Fresh candidate notarization, live Actions/public update | not-run | Implementation request did not include a release/publication. Existing published assets were preserved. |

## Handoff

- Implementation and local verification are complete. Temporary native QA app
  and loopback server were stopped; its own LaunchServices registration was removed.
- At the next requested release, verify the real FileMint old-DMG and new-ZIP
  installation paths, including preserved settings/authorization and Finder behavior,
  then run normal draft-first candidate checks before public availability.
- Known limitation: clients without working Sparkle (including 0.5.7/0.5.8) retain
  their documented manual migration requirement; incompatible hardware/OS cannot upgrade.
