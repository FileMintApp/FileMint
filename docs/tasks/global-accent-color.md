# FileMint accent color

Status: complete

## Objective and scope

Let users choose a FileMint accent in General → Appearance. Keep the current Mint
default and add Ocean Blue, Soft Purple and Amber, with light and dark variants.
The saved preference updates settings, Quick Search, favorites, the file drawer,
creation and tool panels without closing them or restarting FileMint. Finder
menu icon customization and macOS controls retain their own appearance rules.

## Selected context

- Contracts: [Startup and settings](../../specs/domains/startup.md#startup-and-menu-bar),
  [Appearance](../../specs/domains/presentation.md#appearance).
- Entry points: `FileMintPreferences`, `PreferencesModel`, `DesignSystem`,
  `GeneralPane` and the SwiftUI and AppKit window hosts.
- Verification: [Harness](../../specs/HARNESS.md#choose-checks-by-change),
  [native scope selection](../../specs/verification/native-qa.md#automated-local-checks).

## Decisions and progress

- Use preset accent palettes and the existing settings document. Keep the light/dark
  appearance setting independent. Apply theme changes after a successful save.
- SwiftUI window roots share the committed palette. The AppKit creation panel
  uses the same palette when it opens and when preferences change. The drawer
  recolors existing native items in place.

## Evidence

Working tree based on `940d980958366c3c6c41999c88febb01a6b8abb9` on arm64 macOS
27.2.1 with Xcode 27.2. Native runs used signed fixtures with synthetic data.

| Check | Status | Observed result |
| --- | --- | --- |
| `make verify` | passed | 431 Swift tests, five JSON Harness cases and offline regressions. Accent coverage includes invalid defaults, restoration with other preferences and both languages. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Release build produced both the FileMint and embedded Finder extension executables. Xcode needed access to its SwiftPM and compiler caches. |
| `design-ui` | passed | Tested all four colors in light and dark, persistence and rollback, and live native creation controls with the same open draft and its original text. |
| `file-drawer` | failed | The first run passed live icon and selection-fill repaint while retaining the row and selection, then failed to find the location settings controls. The retry failed at Command-L. |
| `quick-search` | failed | The first run missed fixture text input. The retry failed the check for restoring Templates scope and replacing the selected query after reopening. |
| Live Design QA | passed | Selected Amber using the Chinese picker. The settings selection, switch and primary button used Amber. The frontmost creation panel used Amber for Create. Quick Search showed Amber highlights, accepted template scope selection and received `txt` in the search field. The fixture exited normally. |

Native reports are `build/native-checks.noindex/run.0e1tu6uc/report.json` and
`build/native-checks.noindex/run.pahoabu5/report.json`. The Design QA run captured
the light Ocean Blue and dark Soft Purple settings in its `accent-review` folder.

## Verification boundary

The broader drawer and search suites have unresolved interaction failures.
Native coverage here used macOS 27.2.1 and the isolated Design QA app.
The concurrent edit to `App/FileMint/GlobalShortcutSettingsView.swift` appeared
after these runs and is outside their tested snapshot.

## Installed Debug — 2026-11-21

Built Debug 0.8.2 (31) with `ENABLE_DEBUG_DYLIB=NO` from the current theme
working tree, including the binding compiler fix in `77289dc`. The installed
app and Finder extension match the Developer ID signed build byte for byte.
The main app ran from `/Applications/FileMint.app`, and the running Finder
extension mapped the new installed executable. Finder menu actions were outside
this installation check.

The backup and verification logs are in
`build/local-debug-install.noindex/theme.jRmI0V/`. The previous bundle archive
passed its integrity check before the replacement.

## Expanded presets and custom colors — 2026-11-21

Added Teal, Indigo, Moss, Coral, Rose and Slate. The editor accepts the system
color well or a six-digit sRGB hex value and previews the proposed button color.
Apply saves one original swatch and updates the global palette. Switching presets
keeps the swatch available under Custom.

The working tree based on `77289dc` passed `make verify` with 436 Swift tests,
the unsigned application and extension build, and `design-ui` on arm64 macOS
27.2.1. An initial test compilation failed when Swift Testing expanded assertions
around mutating calls. Assigning the return values before asserting resolved it.
The [native evidence](../../build/native-checks.noindex/run.l8jrkr0z/report.json)
covers the open creation draft, repeated custom edits, light and dark palettes,
save rollback and exact swatch restoration.

Live Design QA showed ten presets, rejected an invalid hex value, and updated the
color well from valid input. Cancel retained Mint. Applying `#A657D8` recolored the
settings sidebar and primary button. Switching to Slate and back to Custom restored
`#A657D8`. The separate system color window was outside the observed app-window
snapshot. Testing used the isolated fixture and unsigned build.

### Installed Debug with custom colors

Built Debug 0.8.2 (31) from the expanded-palette working tree based on `77289dc`.
Signed with the existing Developer ID and verified the bundle before and after
replacing `/Applications/FileMint.app`. Both installed executables matched the
signed build. The launched FileMint process and the mapped Finder extension came
from the new installation. The prior bundle archive and checks are in
`build/local-debug-install.noindex/custom-accent.rS8Zt7/`.
