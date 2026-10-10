# Task: Stable identities for each native QA kind

Status: in-progress
Next action: Finish approval reuse for the remaining QA kinds and after Codex restart, plus stable-path installer acceptance.

## Objective and scope

- Preserve a fixed ID, path and signing requirement for each native QA kind so
  saved Computer Use approvals can be reused across builds.
- Keep new per-run fixtures/preferences/event logs and all existing sandbox gates.
- The previous ZIP/DMG changes were committed first as `c04f6ac`.
  The QA changes form a separate local commit; no push or release was requested.

## Selected context

- Owning workflow: [HARNESS](../../specs/HARNESS.md#native-qa-application-identity),
  [Native QA](../../specs/verification/native-qa.md).
- Boundaries: [Distribution](../../specs/domains/distribution.md),
  [Startup](../../specs/domains/startup.md),
  [Finder/permissions](../../specs/domains/finder-permissions.md).
- Entry points: native QA builders, native QA publisher, sandbox fixture data paths.

## Decisions and progress

- Preserve existing fixed fixture IDs. Remove randomized suffixes from Design QA
  and Upgrade QA. Publish verified apps at one stable path per kind.
- Use one local Developer ID identity without changing production credentials;
  keep previous runtime flags and entitlements on each fixture.
- Signing/publishing must not replace a running QA app or its receiver, and must
  preserve the prior good app when a build/signature/publish check fails.
- All eight builders now publish signed apps to their per-kind stable paths.
  Sandbox move state and update-event logs use per-build run IDs. Generic signing
  preserves prior sandbox entitlements and runtime flags; the updater's pre-signed
  host is copied without breaking its ephemeral signed archive session.
- The creation/opening runner now obtains its allowed path from the QA identity
  registry. It accepts the builder's stable output and rejects staging/other apps
  before registration. Offline tests run the real shell wrapper with a fixture
  registrar/host and cover opening mode, exit status and bounded cleanup.

## Evidence

Tested worktree: primary checkout based on `c04f6ac`; QA changes tested before the local commit.
Environment: local arm64 Mac, macOS 27.2 for the review and opening-runner repair.

| Check | Status | Observed result |
| --- | --- | --- |
| Offline regressions / `make verify` | passed | Existing suite plus 12 QA regressions, including the opening-runner path and cleanup cases; log `/private/tmp/filemint-qa-fix-verify.log`. |
| Native builds and repeated identity comparisons | passed | All eight builders pass. Rebuilding file-tools-settings and sparkle-installation preserves ID/path/designated requirement while run IDs differ; logs `/private/tmp/filemint-stable-qa-builds.log`, `/private/tmp/filemint-stable-qa-repeat.log`. |
| Native icons/template scheduler | passed | Fixed signed paths pass native icon pixel checks and template/automatic-update regressions. |
| Real running-app protection | passed | Actual running Tools QA blocks replacement and preserves the current executable; log `/private/tmp/filemint-stable-qa-running.log`. |
| Repeated Computer Use approval: Tools UI / Design QA | passed | Review directly accessed both apps before and after rebuilding, by stable path and bundle ID, without a new authorization request. Tools UI also passed after resetting the Computer Use REPL; record `/private/tmp/filemint-qa-review-result.json`. This does not prove reuse after restarting Codex. |
| Other six kinds / Codex restart | not-run | Identity/signature checks alone do not prove approval reuse. |
| Stable-path creation/opening runner | passed | Explicit/default native receivers, 12 saved-action quick/panel routes, 6 collision receipts, cancellation and error/retry guards pass; log `/private/tmp/filemint-qa-fix-native-opening.log`. |

## Handoff

- Remaining work: observe approval reuse for the other QA kinds and after Codex
  restart, and complete stable-path installer acceptance. Publisher migration,
  per-run data isolation and the opening-runner repair are implemented.
- First use of a migrated identity may still require a user approval in Codex.
  The task does not change saved approvals, system privacy grants or shell policy.
