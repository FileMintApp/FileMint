# Task: Send Finder aliases to Desktop

Status: in-progress
Next action: Validate the installed Finder menu when the user chooses to exercise it.
Implementation and the local Debug install are complete; the real Finder action remains user acceptance.

## Objective and scope

Create real Finder aliases for selected resources on Desktop. Preserve originals,
use existing sandbox authorization, avoid overwrites and support multiple items.
No competitor implementation, scripts controlling Finder, publication or install.

## Selected context

- Contracts: [tools](../../specs/domains/file-tools.md),
  [Finder](../../specs/domains/finder-permissions.md),
  [startup](../../specs/domains/startup.md),
  [presentation](../../specs/domains/presentation.md).
- Entry points: FileTools, FileOperationTicket, FinderSync,
  FileOperationCoordinator, FileToolsSettingsView, FileToolAppearance.
- Verification: [matrix](../../specs/HARNESS.md),
  [Core](../../specs/verification/core.md),
  [native](../../specs/verification/finder.md).

## Decisions and progress

- Apple calls the Finder shortcut an alias / 替身. Screenshot appearance alone
  does not establish the other app's implementation.
- [Apple user guide](https://support.apple.com/zh-cn/guide/mac-help/mchlp1046/mac):
  an alias opens the original and can be placed on Desktop.
- [Foundation API](https://developer.apple.com/documentation/foundation/url/writebookmarkdata(_:to:)):
  creates Finder alias files; overwrites existing destinations, so stage and
  publish exclusively rather than call it on a final Desktop name.
- [Bookmark options](https://developer.apple.com/documentation/foundation/nsurl/bookmarkcreationoptions/withsecurityscope):
  alias data and persistent sandbox grants cannot use the same creation flags.
- [Sandbox access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox):
  exact-folder NSOpenPanel grants and balanced scoped access remain necessary.
- Source grants and Desktop grants are private operation state, independent of
  the Finder menu scope and the user's saved creation preferences.

## Evidence

Tested worktree: `41067c3` plus the desktop-alias changes (uncommitted).
Environment: macOS 27.0 (26A428), Apple silicon, Xcode 27 toolchain.
Logs and reproducible disposable sandbox fixture sources: `build/desktop-alias-evidence/`.

| Check | Status | Result |
| --- | --- | --- |
| `make verify` | passed | 112 Swift tests, 5 Harness cases, 10 CLI regressions, 3 appcast tests and context checks. Initial sandbox cache failure was resolved by rerunning with approved compiler-cache access. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Release app and Finder extension, arm64 and x86_64. Only existing AppIntents metadata notices remain. |
| Isolated native settings | passed | Chinese/light and English/dark at minimum detail width; alias toggle, submenu/main placement, disabled controls with master off. |
| Isolated sandbox coordinator | passed | Initially unreadable source/unwritable fixture Desktop; cancellation created zero entries; exact-folder grants produced 2 aliases; relaunch reused saved grants and produced numbered aliases without another picker. Original bytes unchanged. |
| Finder alias files | passed | Get Info reports Kind: Alias, correct original folder and native arrow. Opening the folder alias enters the original folder and shows its child. |
| Local Debug install | passed | Clean arm64 Debug `0.5.6 (14)` installed at `/Applications/FileMint.app`; deep signature, App Sandbox, `get-task-allow`, and the single installed Finder extension registration verified. Rollback archive: `build/local-install-backups/20260918-174004-desktop-alias-debug-clean/FileMint-before-debug.zip`. |
| Installed settings entry | passed | After the clean rebuild, the actual installed settings page showed `发送替身到桌面` with its opt-in switch and menu placement; no user preference was changed. |
| Test alias cleanup | passed | Removed the four aliases created under `build/desktop-alias-native.iS7cSz/Desktop`; the directory is empty. |
| Installed Finder action / real Desktop | not-run | The actual Finder right-click callback, real Desktop/iCloud and removable-volume integration still need user acceptance. |

## Handoff

- Remaining work: installed Finder menu integration; real Desktop/iCloud/removable-volume scenarios.
- Implementation: new `DesktopAlias.swift` and tests, file-tools preferences/localization,
  ticket payload, Finder dispatch, main-app coordinator, settings hint/icon and owning SPECs.
- Isolated sandbox fixture: `build/desktop-alias-native.iS7cSz/`; settings fixture:
  `build/file-tools-settings-harness.noindex/run.FOZWRL/`. Only fixture files and
  fixture app authorization were changed. Test windows were closed afterward.
- The installed settings entry is verified, but the real Finder callback has not
  been exercised in this installation pass.
- Known limits: alias resolution follows macOS; no guarantee across deleted
  originals, disconnected volumes or every file-provider migration.
