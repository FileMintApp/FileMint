# Task: Open with App

Status: complete
Next action: Installed Finder acceptance when testing an installed build; implementation is complete.

## Objective and scope

- Add a native settings entry for choosing apps to open selected Finder files/folders.
- Per-app placement defaults to submenu; hide empty submenu roots, retain main entries.
- Review the complete changed flow and inspect native appearance and interactions.

## Selected context

- Contracts: [Open with App](../../specs/domains/open-with.md),
  [Finder](../../specs/domains/finder-permissions.md),
  [file operations](../../specs/domains/file-tools.md),
  [startup](../../specs/domains/startup.md), [presentation](../../specs/domains/presentation.md).
- Checks: [matrix](../../specs/HARNESS.md), [Core](../../specs/verification/core.md),
  [native](../../specs/verification/finder.md).

## Decisions and progress

- Adding an app is sufficient to enable its entry; no redundant module switch.
- Reuse native application selection, private tickets and serialized main-app operations.
- Preserve user settings; use an isolated fixture for visual and interaction QA.
- Updated the entry to a shared `square.stack.3d.up` symbol after user feedback.
  Both Finder placement levels use the application's own non-template native icon.
- Reviewed persistence, malformed records, duplicate repair, whole-selection scope,
  captured app identity, expiring tickets, authorization, callback isolation and
  busy/access lifetime. Stale configuration now produces a localized message.
- Save failures roll back the displayed application configuration. Re-adding an
  app preserves its ID/order/placement; selecting multiple apps validates all first.
- Platform API: [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace)
  opens the complete URL selection with the specified application asynchronously.

## Evidence

Tested worktree: uncommitted implementation based on `55d9a1f`, 2026-09-22.
Environment: macOS 27.2, Apple silicon; `/Applications/Xcode.app/Contents/Developer`.

| Check | Status | Result |
| --- | --- | --- |
| `make verify` | passed | 127 Core + 12 image tests, 5 public cases, 10 CLI regressions, 3 appcast tests; `/tmp/filemint-open-with-verify.log` |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | arm64/x86_64 app and extension after final icon changes; `/tmp/filemint-open-with-build.log` |
| Native settings | passed | Real VS Code selection, default submenu, main placement, duplicate repair, removal and JSON readback. Chinese light/dark and English dark at minimum size inspected; final replacement icon inspected in Chinese/light |
| Sandboxed native opening | passed | Production coordinator, private tickets, bookmark resolution and NSWorkspace delivered a Unicode file plus folder to a real fixture app in order. Wrong app identity and non-app selection rejected; source bytes, folder and clipboard preserved. Busy guard held and released; ticket replay rejected. `/tmp/filemint-open-with-native.log` |
| Installed Finder callback/menu and actual third-party app support | not-run | Installed FileMint was not replaced or enabled; the sandbox fixture receiver is not VS Code |
| Keyboard-only navigation; macOS 13 and Intel runtime; external-folder authorization cancellation | not-run | Source/build checked; these native scenarios remain separate |

## Handoff

- Native fixture entry points: `bash scripts/build_design_ui_harness.sh` then
  its app with `--open-with`; `bash scripts/build_open_with_harness.sh` then its
  `Contents/MacOS/OpenWithSmoke` executable. Each uses disposable settings/files.
- Remaining checks are the explicitly unrun native scenarios above. The user
  subsequently requested a direct source commit, without further build or publication.
