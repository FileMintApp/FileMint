# Task: Settings setup and template interaction

Status: complete
Next action: Installed-app permission and Finder acceptance remains a separate manual check.

## Objective and scope

- Show an exact insertion line while reordering Open with App entries.
- Put actionable Finder extension and Full Disk Access guidance on General at first launch.
- Replace the saturated template list selection and allow built-in templates to be edited and removed persistently.
- Keep native authorization user controlled; preserve existing custom templates and saved settings.

## Selected context

- Domain contracts: [templates](../../specs/domains/templates.md), [Open with App](../../specs/domains/open-with.md), [Finder permissions](../../specs/domains/finder-permissions.md), [startup](../../specs/domains/startup.md), [appearance](../../specs/domains/presentation.md).
- Implementation: `TypesPane`, `OpenWithSettingsView`, `GeneralPane`, `PreferencesModel`, `FileTemplate`, `Preferences`, localization.
- Verification: [HARNESS](../../specs/HARNESS.md), [Core](../../specs/verification/core.md), [Finder/native](../../specs/verification/finder.md), affected [Finder QA](../FINDER_QA.md#types-and-preferences).

## Decisions and progress

- Use the existing supported system settings entry points. Full Disk Access has no readable status API in the app, so its guidance must never assert a grant.
- Record explicit removal of stable built-in IDs in preferences so migration cannot silently restore them.
- User follow-up: animate drag feedback and row settling; respect Reduce Motion.

## Evidence

Tested worktree: `7a482bb` plus uncommitted changes on 2026-09-24.
Environment: macOS 27.2, Apple silicon; isolated native settings fixtures.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 150 Core and 13 image tests, 5 public cases, 10 CLI tests, context and release script checks. Log: `/private/tmp/filemint-settings-verify-final.log`. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Universal app and extension compiled. Log: `/private/tmp/filemint-settings-build-final.log`. |
| Native template settings | passed | At 840×600, built-in row selection used muted mint; editor saved a new name/default filename/content, and removal reduced 14 to 13 templates. Isolated JSON recorded `removedBuiltInTemplateIDs: ["plain-text"]`. |
| Native General setup | passed | At 840×600, both manual extension setup and Full Disk Access guidance/actions were visible. No OS permission was changed. |
| Native app reordering | passed | Isolated populated list showed a blue insertion guide; final build drag changed row order with a visible settling transition. Saved JSON readback matched the settled order. |
| Installed Finder / privacy / Reduce Motion / macOS 13 / Intel | not-run | Fixture cannot prove installed extension callbacks, real permission grants, platform coverage or the OS Reduce Motion presentation. |

## Handoff

- Remaining work: none for the requested source change.
- Files currently changed: see the task worktree; no installed app or owner preferences were changed.
- Known limitations / native checks still needed: installed Finder, actual permission grants, Reduce Motion, macOS 13 and Intel remain untested.
- Next action and minimum context: if requested, validate an installed candidate using the affected [Finder QA](../FINDER_QA.md#types-and-preferences) scenarios.
