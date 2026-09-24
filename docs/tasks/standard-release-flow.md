# Task: Standard local release flow

Status: complete
Next action: Use the standard procedure for the next authorized stable release.

## Objective and scope

- Make “构建发布” map to the same two-stage stable release procedure every time.
- Use `project.yml` for version/build, require signed Sparkle contents and a
  verified appcast, check the exact remote asset set, and await remote verification.
- Do not publish a new release as part of implementing this workflow.

## Selected context

- [Distribution contract](../../specs/domains/distribution.md) and
  [update contract](../../specs/domains/updates.md).
- [Release procedure](../DISTRIBUTION.md), [verification matrix](../../specs/HARNESS.md),
  [update acceptance](../../specs/verification/updates.md).
- Implementation: release scripts, artifact checks, `Makefile`, and published
  release workflow. Agent routing: [AGENTS](../../AGENTS.md).

## Decisions and progress

- The original workflow separated local build and public upload for candidate
  native acceptance. The owner's 2026-09-24 decision supersedes that gate for
  routine releases; see the current [Distribution procedure](../DISTRIBUTION.md).
- Preserve the existing local source manifest for retry after remote failure.
- Require the signed app's installer configuration and three matching assets;
  absence of Sparkle must fail closed.

## Evidence

Tested commit/worktree: current uncommitted main worktree.
Environment: owner's macOS development machine.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 139 Core tests, 13 image tests, public/CLI harness, appcast, metadata, notarization resume and entitlement tests; final worktree. |
| Ad-hoc `make package` to private temp output | passed | Universal Release build, Sparkle driver, signed app/extension permissions, DMG integrity and portable checksum. No notarization or publication. |
| Existing v0.5.9 release workflow waiter | passed | Read-only check selected the release-tag run for commit `6f9c306` and observed its successful conclusion. |
| Mismatched version preflight | passed | `APP_VERSION=0.5.10 BUILD_NUMBER=18 make release-local` failed before build because `project.yml` still says 0.5.9 (17). |
| `make verify-context`, shell syntax, `git diff --check` | passed | Context and static checks passed. |
| Public release | not-run | Intentionally no version, tag or upload for this task. |

## Handoff

- Remaining work: none for workflow implementation.
- Known limitations: a future tagged, notarized candidate and remote release
  are required to prove the complete live workflow. Ad-hoc packaging does not
  establish production installation or Finder activation.
