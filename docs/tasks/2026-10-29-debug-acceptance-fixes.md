# Debug acceptance fixes — 2026-10-29

Status: complete
Next action: None; the user accepted the installed Debug fixes on 2026-10-29.

## Scope and decisions

- App, menu-bar and search creation entries open the existing single draft directly.
  Save Location owns destination changes; missing write permission still requires
  macOS authorization. Finder keeps its captured destination and ticket/scope checks.
- Fit the native creation window to visible content, including clipboard images,
  Office templates and the optional post-creation action row.
- Keep settings sidebar keyboard selection synchronous across rapid arrow input;
  scroll only when the selected row leaves the viewport.

## Selected context

- [Creation contract](../../specs/domains/creation.md),
  [startup/settings](../../specs/domains/startup.md),
  [Finder permissions](../../specs/domains/finder-permissions.md).
- [Harness](../../specs/HARNESS.md),
  [native QA](../../specs/verification/native-qa.md),
  [installed Debug procedure](../DEVELOPMENT.md).
- Implementation: `PreferencesModel.swift`, `ContentView.swift`,
  `CustomFileSavePanelController.swift`; regression fixture: `design_ui_smoke.swift`.

## Evidence

Source: primary `34372a3ab617` plus this working-tree change.

Environment: arm64 macOS 27.2, Xcode 27.1, Swift 6.4.

| Check | Result |
| --- | --- |
| `make verify` | passed; final log `build/acceptance-fixes.noindex/20261029-yastnugn/verify-final.log` |
| Unsigned Release App/Finder build | passed; `release-build.log` in the same run directory |
| `template-workflow`, `creation-opening` | passed; `build/native-checks.noindex/run.dc7w5qke/report.json` |
| `design-ui`, `quick-search` final run | passed; `build/native-checks.noindex/run.ia54rlq1/report.json` |
| Signed Debug build/install | passed; `debug-build.log`, `signing.log`, `installation.json` in the acceptance run directory |
| Installed New File action | observed through CUA: directly opened the draft with Save Location; Cancel returned to settings without a file write |

Creation regressions cover direct opening/cancellation, nondefault Markdown
preselection, preserving an existing clipboard draft, exact bytes on Create and
unchanged folder preferences. Layout checks cover Chinese/English image, text
and Office panels, including the opening-action toggle. Image content height is
494pt with actions off; measured footer gap stays 23pt in all tested variants.
Navigation checks deliver native mouse/key events in bursts and assert selection,
visible-row scroll stability, boundaries and offscreen-row reveal at minimum size.

The first interface run exposed two fixture prerequisites: SwiftUI AX elements
must be traversed through their supported getters, and the preceding draft must
finish its natural asynchronous activation before an independent search scenario.
Tests now observe those states without forcing focus. The installed app also had
the default shortcut registered; it was normally quit for the isolated search
check and restarted after installation, without changing its settings.

The shared-file plan includes unrelated update checks; reviewed native scope was
`template-workflow`, `creation-opening`, `design-ui`, `quick-search`. Final test-only
changes did not alter the product binaries covered by the earlier creation runs.
The user accepted all three reported corrections, including rapid keyboard
navigation, on 2026-10-29. External-folder authorization persistence and older
macOS versions were not separately re-tested.

Installed `/Applications/FileMint.app` is Debug 0.8.0/build 29 from the above
commit plus product changes. Main executable SHA-256 starts `b65c041e35b132c9`;
the prior app is archived as `FileMint.before-fixes.zip` in the acceptance run.
The user authorized committing and pushing this fix after acceptance.
