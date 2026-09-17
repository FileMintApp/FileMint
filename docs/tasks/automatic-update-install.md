# Task: Automatic update installation

Status: complete
Next action: Before release, increase version/build and run signed sandbox old-to-new installation acceptance.

## Objective and scope

- One Update and Restart action downloads, installs and relaunches FileMint.
- Preserve weekly metadata checks, sandboxing, preferences and local signing.
- No release publication or changes to installed user applications in this task.

## Selected context

- Contracts: [updates](../../specs/domains/updates.md), [distribution](../../specs/domains/distribution.md), [startup](../../specs/domains/startup.md), [creation](../../specs/domains/creation.md), [Finder](../../specs/domains/finder-permissions.md), [presentation](../../specs/domains/presentation.md).
- Entry points: UpdateModel, AboutPane, project.yml, signing/release scripts.
- Verification: [Harness](../../specs/HARNESS.md), [updates](../../specs/verification/updates.md).

## Decisions and progress

- Pin Sparkle 2.10.0; keep GitHub discovery/scheduling and use a visible custom driver for user-initiated installation.
- Bind each installation to the selected release's immutable appcast, DMG URL, version and size.
- Baseline make verify passed: 79 Swift tests, 5 harness cases, 10 CLI tests.
- Initial sandboxed baseline blocked by Swift cache access; elevated retry passed.

- Added an immutable per-release feed, exact release binding, signed archive verification before extraction, safe restart checks and legacy-client migration copy.
- Generated the FileMint-specific EdDSA key in local Keychain; committed configuration contains only its public key. User completed the system sign_update authorization prompt.
- Local signature generation and public-key verification passed on disposable fixture bytes; no publication or installed application was changed.

## Evidence

Environment: macOS, Xcode toolchain, 2026-09-17 worktree on top of the existing 0.5.4 source. No commit, tag, publication or installed-app replacement was performed.

| Check | Status | Observed result |
| --- | --- | --- |
| Baseline make verify | passed | 79 Swift tests, 5 JSON cases, 10 CLI tests |
| Final make verify | passed | 82 Swift tests in 7 suites, 5 JSON cases, 10 CLI tests, 3 appcast tests |
| Unsigned make build | passed | arm64 + x86_64 app and Finder extension; real pinned Sparkle dependency |
| make verify-sparkle-driver | passed | Production driver with real framework and test UI sinks; selectors, cancellation including late ready callback, progress, safe restart, retry, errors |
| sign_app.sh + verify_bundle.sh | passed | Local ad-hoc nested signatures, universal helpers/framework/app/extension and packaged third-party license; not Developer ID/notarization proof |
| EdDSA generation and verification | passed | Actual Keychain signing on disposable fixture; public-key verification passes; equal-size modified content rejected |
| Website build | passed | SITE_BASE=/FileMint/ pnpm run site:build |
| Shell syntax / context / diff whitespace | passed | Updated scripts parse, context links valid, git diff --check clean |
| Signed sandbox replacement/relaunch + Finder refresh | not-run | Requires isolated old/new signed release builds and update hosting; no production publication authorized |

Logs for this run are in `/private/tmp/filemint-sparkle-{build,verify,sign,site}.log`.

The first test build hit a Swift callback naming mismatch and one Testing macro
required an inner throwing expression to be split; both were corrected before
successful final checks. Signing waited for macOS Keychain consent; the user
completed it and the same pending attempt succeeded.

## Handoff

- Implementation complete. Before publication: bump marketing version and build, prepare signed/notarized artifacts and run native upgrade acceptance.
- Real signed sandbox replacement/relaunch and Finder refresh remain native acceptance checks; do not represent the callback harness as this proof.
- Public update key is in project.yml; private key remains in local Keychain. Never rotate it merely to repeat testing.
