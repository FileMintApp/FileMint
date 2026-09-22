# Task: Repair Sparkle sandbox installer entitlements

Status: complete
Next action: Affected users manually install 0.5.9 once; the fix is published and verified.

## Objective and scope

- Fix the user's installed 0.5.7 failure when choosing Update and Restart for 0.5.8.
- Preserve sandboxing, user files/preferences, published release bytes and native permission boundaries.
- Use a future corrected installer; installed broken entitlements require a one-time manual replacement and cannot be repaired by a remote feed.
- User explicitly authorized submitting 0.5.9 to Apple using existing local credentials and publishing to GitHub after accepted notarization.

## Selected context

- [Updates](../../specs/domains/updates.md), [Distribution](../../specs/domains/distribution.md), [Finder permissions](../../specs/domains/finder-permissions.md).
- [Verification matrix](../../specs/HARNESS.md), [native updater checks](../../specs/verification/updates.md).
- Signing and artifact scripts; actual signed sandbox upgrade using Sparkle.

## Diagnosis

- 2026-09-22 unified logs show installed 0.5.7 denied Mach lookups for
  `io.github.daigua.filemint-spki` and `io.github.daigua.filemint-spks`, followed
  by Sparkle reporting an invalidated installer connection.
- Installed 0.5.7 and the exact published 0.5.8 DMG both embed literal
  `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki` in their signed entitlements.
- `sign_app.sh` passed the source entitlements directly to codesign after an
  unsigned Xcode build. Xcode's build-setting substitution was therefore skipped.
- Previous signature/notarization/startup checks passed without checking the
  signed entitlement values or completing a real updater replacement.
- [Sparkle's sandbox guide](https://sparkle-project.org/documentation/sandboxing/)
  specifies that the placeholders are expanded automatically when building in Xcode.

## Evidence

- Exact local failure: `/tmp/filemint-update-failure.log` (bounded FileMint/Sparkle log query).
- `make verify` passed: 139 Core tests, 13 image tests, 5 public cases, 10 CLI,
  3 appcast and 5 entitlement-preparation tests. Unsigned universal build passed.
- New Security-framework validator rejected the installed 0.5.7 with
  `Unresolved build variable in signed entitlements` and accepted corrected
  Developer ID-signed sandbox fixtures before and after installation.
- Actual isolated upgrade: `run.rvcsxI`, bundle ID
  `io.github.daigua.filemint.upgrade-qa.rvcsxi`, using the production signing script
  and a fixture-only key kept in memory. Native evidence shows checking → found →
  download → extract → ready-to-install → installing → relaunched build 2.
  Old PID 60859 exited; new PID 60910 started at 17:55:47 at the same installation
  path. Disk version is 2, and post-install signature/entitlement checks passed.
- The QA UI displays both launch records from its own container. The test uses
  a minimal driver, loopback feed and inert extension; it does not establish
  the production public-feed/custom-driver or Finder refresh acceptance.
- Logs: `/tmp/filemint-sparkle-entitlements-verify.log`,
  `/tmp/filemint-sparkle-entitlements-build.log`,
  `/tmp/filemint-sparkle-installation-build-2.log`.
- Production custom-driver callback smoke also passed: selector wiring, cancellation,
  progress, draft deferral, relaunch choice, retry and errors. This remains separate
  from the native fixture's network/install evidence.
- Complete Developer ID-signed local candidate: `build/entitlements-fix-candidate/FileMint-0.5.9.dmg`,
  version 0.5.9/build 17, 7,585,629 bytes, pre-notarization SHA-256
  `b4675c2553ec7ca025956b26547fd571df442828e043283411eb8919dcf8b706`.
  Mounted-bundle checks passed: both architectures, signed app/extension, and
  exact `io.github.daigua.filemint-spks` / `-spki` permissions.
- Candidate uses the current uncommitted fix with explicit version/build overrides.
  It is not notarized or published; a release must still commit/tag clean source
  and follow the standard notarization/publication procedure. Prepared release copy:
  `/tmp/filemint-release-0.5.9.md`.
- Test app registrations and loopback servers were closed/removed. The user's
  installed FileMint 0.5.7 was inspected, not modified or replaced.
- The final release was rebuilt from clean tag `v0.5.9` at
  `6f9c3061f671e86026cb721a539393aa9a802194`, notarized, stapled and published.
  Uploaded bytes and release description were read back; source CI, published-DMG
  verification and website deployment passed. The pre-release candidate above
  was not uploaded. See [final release evidence](../RELEASE_VERIFICATION_0.5.9.md).
