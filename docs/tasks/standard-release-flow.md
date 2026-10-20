# Task: Standard local release flow

Status: complete
Next action: Use the standard procedure for the next authorized stable release; full live default-stage publication remains to be observed on that release.

## Objective and scope

- Make “构建发布” map to the same two-stage stable release procedure every time.
- Include official Homebrew synchronization and exact-commit tap CI by default
  after app publication and applicable website deployment.
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
- The owner's 2026-09-29 decision also removes standalone UpgradeQA from the
  standard release procedure. It remains an optional installer diagnostic;
  tagged-source, local build/sign/notarize and remote publication gates stay,
  as do affected-surface checks selected through HARNESS.
- Preserve the existing local source manifest for retry after remote failure.
- Require the signed app's installer configuration and the exact six DMG/ZIP assets;
  absence of Sparkle must fail closed.

## Initial implementation evidence (historical)

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

## Standard Homebrew stage — 2026-10-20

The owner's standing instruction adds Homebrew synchronization to every future
standard release. The current implementation is based on main `78b132f`; no
version/tag change or new release is part of this workflow update.

- Default `publish-local` persists the Homebrew requirement before remote work,
  including older completed journals. An explicit app-only override cannot
  erase an already persisted requirement.
- The helper waits for `validate.yml` push CI for the exact tap commit on main,
  rechecks identity and records its run ID/attempt. Missing or unsuccessful CI
  reports partial success and preserves app assets and the published Cask.
- A failed/unfinished tap stage can resume without app upload or website work;
  retries of an unchanged Cask do not push it again, and a completed verified
  tap stage is skipped.
- Regression coverage uses isolated Git repositories and API fixtures. The
  read-only live CI lookup is separate from a full new publication; native
  installation/upgrade/Finder acceptance remains outside these checks.

| Check | Status | Evidence |
| --- | --- | --- |
| Default/saved requirement, sequencing and resume | passed | 48 publication regressions, including structured helper receipts and already-completed/legacy-stage handling; included in the final full-suite log below. |
| Exact tap CI binding, timeout/failure and Git retry | passed | 53 Homebrew regressions, including real isolated Git push/retry fixtures; included in the final full-suite log below. |
| Full offline suite and documentation checks | passed | `make verify`: 337 Core tests, 22 image tests, the 48 publication / 53 Homebrew regressions and all existing Harness/script checks. [Log](../../build/release-0.8.0.noindex/homebrew/default-sync-verify.log). Context links and `git diff --check` passed. |
| Read-only existing tap CI lookup | passed | New waiter verified main `c79c7dce1a1f9653a921397b8f5f43c0bf503b89`, [run 39356246267](https://github.com/FileMintApp/homebrew-tap/actions/runs/39356246267), attempt 1. [Record](../../build/release-0.8.0.noindex/homebrew/default-sync-live-ci.json). No push, release or workflow dispatch. |
| New live release / native installation | not-run | This task changes future workflow only. |

## Handoff

- Remaining work: none for workflow implementation.
- Known limitations: a future tagged, notarized candidate and remote release
  are required to prove the complete live workflow. Ad-hoc packaging does not
  establish production installation or Finder activation.
