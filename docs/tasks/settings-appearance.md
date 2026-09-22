# Task: Settings appearance and consistency

Status: complete
Next action: None for this implementation; installation and release remain separate work.

## Objective and scope

- Align General pickers with switches; add Follow System / Light / Dark, defaulting to the system.
- Review all settings pages and app-owned panels for consistent adaptive colors, control sizes, spacing and interactions.
- Preserve file operations, authorization, startup and update behavior.

## Selected context

- Contracts: [Startup](../../specs/domains/startup.md), [Presentation](../../specs/domains/presentation.md).
- Entry points: Preferences, PreferencesModel, DesignSystem, SettingsSections and the settings panes.
- Verification: [HARNESS](../../specs/HARNESS.md), [Core](../../specs/verification/core.md), [native](../../specs/verification/finder.md).

## Decisions and progress

- Use an app-level native appearance override; returning to Follow System clears it.
  This follows [Apple's NSApplication appearance contract](https://developer.apple.com/documentation/appkit/nsapplication/appearance).
- Persist only the theme choice, never a snapshot of the current system appearance.
- Reuse the disposable native design fixture for visual checks without touching owner preferences.
- Added the theme selector inside General's Appearance section beside language.
  New/missing/invalid saved choices follow the system; explicit choices persist.
- Reused small trailing native pickers across General, Creation, file tools and
  Open with App. Shared section headings, button hover/focus/disabled feedback,
  supporting text and muted disabled icons; About links retain native link styling.
- Theme changes update the SwiftUI settings, AppKit creation panel, resource
  processing window and editor sheets through the application appearance.
- First Core run exposed an invalid test fixture (array reversal without template
  rank changes). The fixture now changes a valid saved enabled flag; production
  template ordering was not changed.

## Evidence

Tested worktree: `e2202df` plus this uncommitted implementation, 2026-09-22.
Environment: macOS 27.2 (26B5086k), Apple silicon, Xcode toolchain selected by Makefile.

| Check | Status | Result |
| --- | --- | --- |
| `make verify` | passed | 139 Core tests in 16 suites plus 13 image tests, 5 public cases, 10 CLI regressions, 3 appcast tests and context checks. [Local log](/tmp/filemint-settings-verify.log). |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Final universal Release app/extension built. [Local log](/tmp/filemint-settings-build.log). |
| `bash scripts/build_design_ui_harness.sh` | passed | Production views with an isolated store. [Local log](/tmp/filemint-settings-ui-build-final.log). |
| Fixture `--general --minimum --english --dark --check-appearance` | passed | Immediate native window changes, clearing the override, store persistence, model reload and failed-save rollback. [Local log](/tmp/filemint-settings-native-final.log). |
| Native settings inspection | passed | All eight pages in English/light and Chinese/dark at 840×600; trailing picker/switch alignment, long-page scrolling, sidebar Up/Down, tool disabled state, and populated/empty Open with App. |
| Native panels and relaunch | passed | Open creation/resource windows changed light/dark immediately; template editor and creation Escape cancellation worked. Actual fixture relaunch retained Dark and English; choosing Follow System saved `system` and returned to the current system appearance. |
| OS appearance toggle while following system | not-run | Verified the native override is nil and current-system restoration; did not change the owner's global appearance preference. |
| macOS 13 / Intel runtime | not-run | No such runtime was available; universal compilation is not execution evidence. |

The initial sandboxed build/check attempts were blocked by Swift cache access.
The same commands succeeded with approved cache access. All native interaction
used disposable fixture files; the installed app and owner preferences were untouched.
