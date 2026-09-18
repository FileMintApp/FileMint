# Task: File tools UI polish

Status: complete
Next action: Inspect the installed Finder menus when a build containing these changes is next installed.

## Objective and scope

- Apply the approved UI concept to File & Folder Tools, retaining the sidebar and major sections.
- Native enablement checkboxes, aligned menu-position pickers, local move/deletion options.
- Matching colored icons for each tool in settings and Finder, at either menu level.
- Module off: every child remains visible, grayscale and noninteractive; choices survive re-enabling.
- No new tools, preference migration, installation, signing, release or publication.

## Selected context

- [File tools](../../specs/domains/file-tools.md), [presentation](../../specs/domains/presentation.md), [Finder](../../specs/domains/finder-permissions.md).
- Settings in `App/FileMint/SettingsSections.swift`; menu assembly in `FinderSyncExtension/FileMintFinderSync/FinderSync.swift`; strings in `CorePackage/Sources/FileMintCore/Localization.swift`.
- [HARNESS](../../specs/HARNESS.md), [native checks](../../specs/verification/finder.md), affected file-tools scenarios in [Finder QA](../FINDER_QA.md).

## Decisions and progress

- Use shared AppKit symbol metadata in SharedUI so settings and Finder use the same palette.
- Keep the persisted enablement and placement representation unchanged.
- Verify actual settings controls with an isolated native fixture, without changing user preferences.
- Implemented `FileToolsSettingsView` with five expanded sections and inherited
  native disabled state, plus shared `FileToolAppearance` images for settings/Finder.
- Native readback confirmed disabled pointer/keyboard attempts leave every
  preference untouched, and custom placement/deletion choices survive off/on.
- The fixture first ran at 692 points wide, then at the 632-point detail width
  corresponding to the app's 840-point minimum. Chinese/light and English/dark
  layouts, expanded move/deletion controls and scrolling were inspected.
- Follow-up visual polish changed menu-position values to system control text
  color and strengthened the selected sidebar surface slightly. The arm64 Debug
  package was rebuilt and installed at `/Applications/FileMint.app`; Chinese/light
  settings were inspected there without changing user preferences.

## Evidence

Tested worktree: `559fc8f` plus this task's uncommitted changes, 2026-09-18.
Environment: macOS 27.0 (26A428), Apple silicon, Xcode SDK macOS 27.0.

| Check | Status | Result |
| --- | --- | --- |
| `make verify` | passed | 104 Swift tests, 5 public cases, 10 CLI regressions, 3 appcast tests and context checks. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Universal app and extension, no installation/signing/publication. |
| Native settings and icons | passed | Production view in isolated fixture; disabled AX controls, pointer/keyboard no-op readback, child-only disablement, off/on preservation, bilingual/light/dark/minimum-width layout. Five icons resolve in 16/20-point sizes and contain colored pixels. |
| Installed Finder menu | not-run | Requires a separate right-click acceptance pass; the new extension is loaded, but this turn inspected the settings page only. |

Local evidence: `build/file-tools-verify.log`, `build/file-tools-build.log`,
`build/file-tools-ui-harness.log`; fixture readback in
`build/file-tools-settings-harness.noindex/run.uEY9FK/` and `run.6xCNTP/`.
The initial sandboxed checks were blocked by system Swift cache access; approved
reruns completed successfully. The native fixture never reads user preferences.
Finder menu highlighting and minimum-OS runtime remain unverified.
