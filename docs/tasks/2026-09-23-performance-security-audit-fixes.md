# Task: Performance and security audit fixes

Status: in-progress
Next action: Await the user's decision on a temporary 0.5.10 QA installation for installed Finder callback acceptance.

## Objective and scope

- User-visible outcome: Finder actions stay inside configured folders, destructive actions never operate on a replacement item, and large configurations/selections remain responsive.
- In scope: creation and file-operation scope, move/deletion identity, preferences recovery, batch validation, Finder menu caching, Open with App bundle validation, and Pages workflow action pins.
- Out of scope: new product features, release publication, and changing macOS permissions automatically.
- Acceptance criteria: each audited issue has a code fix and regression coverage or a focused static assertion; applicable Core, app build, native and website checks are reported separately. The installed Finder callback remains a separate acceptance step.

## Selected context

- Domain contracts: [Creation](../../specs/domains/creation.md), [Templates](../../specs/domains/templates.md), [Finder](../../specs/domains/finder-permissions.md), [File tools](../../specs/domains/file-tools.md), [Open with App](../../specs/domains/open-with.md), [Resource tools](../../specs/domains/resource-tools.md), [Startup](../../specs/domains/startup.md), [Distribution](../../specs/domains/distribution.md).
- Implementation entry points: `FolderScope`, ticket stores, `PendingFileMove`, `FileDeletion`, `FileOperationCoordinator`, `Preferences`, `FinderSync`, `OpenWithApplicationAccess`, `OpenWithSettingsView`, and `.github/workflows/deploy-pages.yml`.
- Verification: [HARNESS](../../specs/HARNESS.md), [Core](../../specs/verification/core.md), [Finder/native](../../specs/verification/finder.md).
- Load additional context when: updater code or release artifact semantics change.

## Decisions and progress

1. **Scope boundary — implemented.** Finder menu construction keeps lexical checks. App execution resolves configured roots and selected-item parents or destination directories, rejects symlink escapes, and still permits operations on a selected symlink itself. Quick creation and resource publishing also recheck resolved scope.
2. **Destructive identity — implemented.** Deletion and moves exclusively claim each item into private sibling staging, verify its captured identity, then delete or publish. Unexpected replacements are restored exclusively or retained at a reported recovery path. Cross-volume fallback copies into private destination staging before exclusive publication; a forced copy-path test covers links and collision restoration.
3. **Preferences recovery — implemented.** Missing settings retain first-run defaults. Existing invalid settings disable Finder scope; saves refuse to overwrite them. Explicit settings import preserves the invalid file as a unique backup and replaces it with bounded validated data.
4. **Batch performance — implemented.** Selection overlap validation uses canonical path sets and ancestor walks. Execution-time policy rechecks use the current item while preserving full-batch checks before the first irreversible action.
5. **Menu and application metadata — implemented.** Finder caches the last preference snapshot and icons with bounded storage; click-time policy still loads current settings. Settings import and app bundle validation run off the main actor, with 32 MiB settings and 1 MiB Info.plist limits.
6. **Workflow trust — implemented.** Pages workflow references six full commit IDs verified against their official tags, and checkout no longer persists credentials.

## Evidence

Tested commit/worktree: uncommitted implementation on `79c2c457e799453b823b372c481f1f64349c27b1`.
Environment: macOS, local Xcode toolchain.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| Targeted Swift symlink-path diagnostic | passed | `standardizedFileURL` retained `/tmp/.../inside/hosts` while resolved path was `/etc/hosts`. |
| `make verify` | passed | Context, 148 Core tests, 13 image tests, JSON Harness and script checks passed on the final code change. Log: `/private/tmp/filemint-audit-verify-final.log`. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Universal unsigned Release app and Finder extension compiled. Log: `/private/tmp/filemint-audit-build-final.log`. |
| `SITE_BASE=/FileMint/ pnpm run site:build` | passed | Local Pages build succeeded; not a deployment check. |
| Pages action pin assertion and `git diff --check` | passed | Six full commit IDs; no whitespace errors. |
| Isolated Open with App sandbox smoke | passed | Native receiver received the full selection; ticket, source bytes and clipboard were preserved; oversized app metadata was rejected. |
| Isolated move sandbox smoke | passed | After explicit user approval, native pickers granted only the generated `source` and `target` folders. Two items moved; pending count reached zero, source became empty, and file/package bytes matched the fixtures. |
| Isolated Resource Tools native smoke | passed | Convert, compress, resize, icons, stitch and OCR each completed a two-image batch in Chinese/light and English/dark. Original image and clipboard remained unchanged. |
| Physical cross-volume move | passed | A disposable HFS+ disk image exposed a distinct device (`16777232` → `16777253`). Files, symlinks and packages moved with exact data; an occupied destination preserved both entries; private staging was cleaned. The image was detached and removed. This used a Core CLI, not the sandboxed Finder extension. |
| Installed Finder callback | not-run | The registered `/Applications/FileMint.app` and Finder extension are 0.5.9; the changed source builds 0.5.10. A separate ad-hoc QA DMG was packaged and verified at `build/security-qa-candidate.r8Anfi/FileMint-0.5.10.dmg` (SHA-256 `f18375f903028d9edecfd22f6b30adebf923b250e0440f70f2b8abc1d99cc113`). Current 0.5.9 was backed up without modifying the installation at `build/local-install-backups/20260923-security-qa.LOOfI3/FileMint-before-qa.zip`; temporary replacement awaits user approval. |

## Handoff

- Remaining work: installed Finder callback acceptance requires the user's decision on temporary installation of the prepared 0.5.10 QA candidate, then restoration of the signed 0.5.9 app. The candidate has not been installed.
- Files in this change: domain SPECs, Core policies and tests, app/Finder adapters, Pages workflow, acceptance evidence, and this task record. No push, tag, release publication or QA installation has occurred.
- Known limitations: a process crash between claiming and completing a destructive item can leave that item in the private sibling staging directory; ordinary quit and updater relaunch are guarded. The isolated QA does not prove installed Finder callbacks.
- Next action and the minimum context required: if the user approves temporary installation, use the verified QA DMG and 0.5.9 backup above; check actual PluginKit status and have the user confirm any Finder extension enablement in System Settings. Do not silently enable it. If declined, record installed Finder as not run and close this implementation task with that evidence boundary.
