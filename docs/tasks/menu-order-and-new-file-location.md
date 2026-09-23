# Task: App order and New File menu location

Status: complete
Next action: Observe the changed controls and menu placement in an installed Finder build when available.

## Objective and scope

- User-visible outcome: Drag apps in settings to set their Finder menu order; choose whether New File actions appear in the main or second-level menu, with submenu as the default.
- In scope: Open with App settings/order, New File preference/settings/Finder rendering, bilingual copy and regression coverage.
- Acceptance criteria: Order and placement persist; each menu contains the applicable entries exactly once; old settings keep the second-level New File menu.

## Selected context

- Domain contracts: [Open with App](../../specs/domains/open-with.md), [creation](../../specs/domains/creation.md), [Finder](../../specs/domains/finder-permissions.md), [startup](../../specs/domains/startup.md), [presentation](../../specs/domains/presentation.md).
- Implementation entry points: `OpenWithApplication.swift`, `Preferences.swift`, `OpenWithSettingsView.swift`, `SettingsSections.swift`, `FinderSync.swift`, `Localization.swift`.
- Verification: Core and App/Finder rows in [HARNESS](../../specs/HARNESS.md); [Core](../../specs/verification/core.md), [Finder/native](../../specs/verification/finder.md), affected [Finder QA](../FINDER_QA.md) scenarios.
- Load additional context when: Template ordering or creation routes change.

## Decisions and progress

- Keep New File in its current submenu by default; main placement shows its actions directly.
- Keep App menu levels independently configurable; reordering changes relative order within each level.
- Added drag handles and keyboard reorder buttons; the saved array remains the menu order.

## Evidence

Tested commit/worktree: current uncommitted worktree on `main`
Environment: local macOS workspace, Xcode release build without code signing

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | Context, 141 Swift tests, five public Harness cases, CLI regression and update/signing script checks passed. SwiftPM required execution outside the restricted sandbox. |
| `make verify-context` | passed | Rechecked links and entry size after the final contract edits. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Release App and Finder extension build succeeded outside the restricted sandbox; `/private/tmp/filemint-menu-build.log`. |
| Installed Finder menu QA | not-run | This build was not installed as the active Finder extension. Follow the affected scenarios in `docs/FINDER_QA.md` with an installed build. |

## Handoff

- Remaining work: installed Finder observation if native acceptance is needed.
- Files currently changed: implementation, regression tests, domain contracts, Finder QA and this task record.
- Known limitations / native checks still needed: installed Finder callback observation.
- Next action and the minimum context required: follow the Open with App and Finder sections of `docs/FINDER_QA.md` with an installed build.
