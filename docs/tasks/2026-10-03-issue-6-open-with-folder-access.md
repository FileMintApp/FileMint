# Task: Issue #6 — Remember Open with App folder access

Status: complete
Next action: Local implementation and applicable checks are complete; perform installed signed Finder → Terminal acceptance before release.

## Objective and scope

- Source: [Issue #6](https://github.com/FileMintApp/FileMint/issues/6).
- The screenshots show FileMint's exact-folder picker, whose wording matches
  `fileOperationAuthorize`, rather than a Terminal automation permission dialog.
- Code diagnosis: both `openWith` and `openDirectory` start with a new bookmark
  dictionary; `authorize` captures a bookmark but the caller discards it. A
  successful second use in one process does not prove access survives relaunch.
- First-use consent can still be necessary in the sandbox. Use Apple's
  [persistent sandbox access APIs](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)
  to remember the granted folder without broadening Finder scope.
- In scope: private read-only grant persistence/reuse for directory and selection
  opening, clearer picker text, folder-settings guidance and regression coverage.
- Out of scope: terminal launch modes/adapters, changing system permissions,
  installing or publishing a release, posting to or closing the GitHub issue.
- Acceptance: same authorized folder works after relaunch; an authorized ancestor
  can cover descendants in current scope; invalid/moved grants never authorize a
  replacement target; cancel/wrong folder/revoked scope never dispatch; settings,
  clipboard and source contents stay unchanged.

## Selected context

- Domains: [Open with App](../../specs/domains/open-with.md),
  [Finder and permissions](../../specs/domains/finder-permissions.md).
- Entry points: `FileOperationCoordinator`, `OpenWithApplicationAccess`,
  `OpenWithSettingsView`, `OpenWithTests`, the Open with App sandbox fixture.
- Verification: [HARNESS](../../specs/HARNESS.md),
  [Core](../../specs/verification/core.md),
  [Finder/native](../../specs/verification/finder.md),
  [Open with App QA](../FINDER_QA.md#open-with-app).
- Load startup only if preferences migration becomes necessary; no preferences
  schema or terminal adapter change is planned.

## Decisions and progress

- [x] Read issue body, existing comment and both attached screenshots.
- [x] Trace the exact picker and the lifetime of captured bookmarks.
- [x] Define the authorization contract before implementing the change.
- [x] Add bounded private storage and current-scope ancestor selection in Core.
- [x] Restore/capture/release read-only grants in the main app; persist only after
  the existing target, configuration and application checks succeed.
- [x] Add localized first-use guidance and a folder-settings shortcut.
- [x] Verify persistence, scope boundaries, cancellation and native transport.
- Native negative testing reproduced a path-only bookmark check accepting a
  replacement at the saved path. The final implementation compares captured file
  identity, volume and creation date with fresh metadata and requires explicit
  reauthorization after an identity mismatch. The moved/replaced case now passes.
- Grants live in `open-with-folder-access.json`, separate from preferences and
  Finder scope. The store is bounded to 4 MiB / 1,024 grants, uses private file
  permissions, rejects symlink/malformed storage and preserves it on failure.
- No preferences migration, terminal adapter, clipboard or association change.

## Evidence

Tested commit/worktree: `ea46b7c` plus this uncommitted issue #6 worktree; initially clean.
Environment: macOS 27.2, arm64, 2026-10-03 (Asia/Shanghai).

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| Issue screenshots and code trace | passed | Original picker wording matches; original opening grants were discarded. |
| `make verify` | passed | 186 Core tests (including five new grant-store cases), 14 image tests, 5/5 Harness cases, 10 CLI regressions and offline release checks. [Log](../../build/issue-6.noindex/verify.log). |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Final Release App and Finder extension. [Log](../../build/issue-6.noindex/build.log). |
| Sandbox first use (`grant`) | passed | Actual picker consent; cancellation, wrong folder and deferred persistence checked. [Log](../../build/issue-6.noindex/grant.log). |
| Sandbox new process (`restore`) | passed | No picker; same folder and descendants readable, writes denied, narrowed scope rejected, access released. [Log](../../build/issue-6.noindex/restore.log). |
| Sandbox replaced folder (`moved`) | passed | Moved bookmark rejected; cancelled repair preserves store. [Log](../../build/issue-6.noindex/moved.log). |
| Sandbox production coordinator/receiver | passed | Complete selection and directory delivered; ticket, source bytes, clipboard and busy guard preserved. [Log](../../build/issue-6.noindex/transport.log). |
| Native settings UI | passed | Chinese light guidance/navigation and final English dark 960×680 layout observed in isolated fixtures. [Notes](../../build/issue-6.noindex/native-ui.txt), [size](../../build/issue-6.noindex/ui-window-size.txt). |
| Installed signed Finder → Terminal, cwd and mode | not-run | Requires installed-build acceptance; fixture evidence cannot replace it. |

The initial restricted-shell SwiftPM/Xcode attempts were blocked by sandbox/cache
access. The checks above passed when rerun with approved build access. No product
sandbox entitlement was changed. Evidence logs are local ignored build artifacts.

## Handoff

- Remaining implementation work: none. Installed signed Finder/Terminal acceptance
  remains a release check; GitHub issue #6 remains open pending delivery.
- Changed paths: the Open with App domain; Core grant store, errors, localized
  text and tests; native grant lifecycle and coordinator integration; settings
  guidance; isolated native fixtures and QA documentation.
- Known limitation: initial explicit sandbox authorization is still required when
  no usable access exists; the fix must not promise to suppress system prompts.
- Delivery: include the implementation, regression coverage and task/acceptance
  records in a local commit referencing `FileMintApp/FileMint#6`.
- Next action: when preparing delivery, run the installed Finder/Terminal
  scenarios in the linked QA checklist. No installation, issue message or
  release was performed by this task.
