# Task: Change the default application for a file type

Status: complete
Next action: For installed-app acceptance, exercise the visible Finder menu and an external folder using the scoped Finder QA scenario.

## Objective and scope

- Add a Finder command for one ordinary, in-scope file with a known, concrete content type. The File & Folder Tools switch and menu placement control the command.
- Show every compatible application in one searchable list with the current default first. Keep the panel compact, with about four rows visible and only the list scrolling. Match localized and original application names. Keep the native application picker as a fallback for an explicitly chosen compatible app.
- Show the affected type and macOS account scope before confirmation. Confirm once in FileMint, let macOS request consent when needed, and close with brief feedback only after reading back the new default. Preserve the selection on failure.

## Selected context

- [File tools](../../specs/domains/file-tools.md), [Finder and permissions](../../specs/domains/finder-permissions.md), [Open with App](../../specs/domains/open-with.md), [Presentation](../../specs/domains/presentation.md), and the file-tools preference rules in [Startup](../../specs/domains/startup.md).
- `FileTools`, `FinderSync`, `FileOperationTicketStore`, `FileOperationCoordinator`, the main app's picker, and `NSWorkspace`.
- [HARNESS](../../specs/HARNESS.md) for Core, unsigned build and affected native fixtures. The new system boundary is tested with a disposable content type and fixture apps.

## Decisions and progress

- Reuse the single-use Finder ticket and metadata identity capture. Freeze the content type on the click, then recheck the item, resolved scope and current switch before presenting and before committing. Reuse read access only when metadata access requires it.
- Use AppKit `NSWorkspace` by content type for the registered candidates, current default, and system write. Keep the association outside FileMint preferences. Hold the operation guard through system consent and readback.
- Keep the existing Open with App command and saved app list independent. No new dependency or entitlement is planned.
- Review passed on macOS 27.2.1: an ad-hoc signed App Sandbox app queried two registered test viewers, requested the type-wide change, and macOS presented a consent dialog naming only the synthetic extension. An independent process then resolved both the type and a sample file to the second viewer. The first probe's incomplete document declaration registered no candidates; the fixture was corrected before the write.
- Use the existing default-off tool switch and submenu/main placement. The native picker verifies membership in the system's refreshed compatibility list before selecting an app. A write uses the frozen type; it never edits the file or stores a parallel association.
- Implemented the Core eligibility/capture and ticket, Finder entry, and main-app picker. Native visual review removed the unused window controls and tightened the height. Search uses the existing input component without changing that component or Quick Search.

## Evidence

| Check | Status | Observed result |
| --- | --- | --- |
| Sandboxed type association probe | Passed | System consent, type-wide write and independent file/type readback on a unique synthetic type. |
| `make verify` | Passed | Core Swift run: 402 tests in 43 suites. Offline Harness and context checks passed. |
| Unsigned `make build` | Passed | Final Release build produced the main app and embedded Finder extension, targeting macOS 13.0. |
| Signed automatic native checks | Passed | `default-application` passed on final worktree (`build/native-checks.noindex/run.5c_wo3tg/report.json`). `file-tools-settings` and `open-with` passed before the picker-only layout adjustment (`run.1zi4smf0`). |
| Signed interactive fixture, macOS 27.2.1 | Passed | From the real panel, search, Down and Return opened the macOS dialog. Accepting switched the disposable type and file; denying kept the pending selection and showed feedback. Closing after denial preserved the original default and file bytes. |
| Existing `quick-search` fixture | Failed | Both runs stopped at the first window-focus assertion. The panel was visible and the field editor existed, but it did not become key. Shared search source has no diff on the final worktree (`run.ur828w1j`). |

## Handoff

- Installed Finder menu delivery and protected-folder authorization were not exercised. The signed fixture starts at the actual main-app ticket route; it does not install or replace the Finder extension. Use [Finder QA](../FINDER_QA.md#file-and-folder-tools) for those checks.
