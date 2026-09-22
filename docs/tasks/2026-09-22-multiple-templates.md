# Task: 同格式多模板

Status: complete
Next action: Implement Office document templates; keep installed Finder/platform acceptance separate.

## Objective and scope

- Save and create multiple named templates for one extension, each with independent initial content and default filename.
- Second task, after [clipboard images](2026-09-22-clipboard-image.md); provides the selection model for [Office templates](2026-09-22-document-templates.md).
- Implement the T1 scope from [the earlier workflow plan](2026-09-17-template-creation-workflow.md) here. That plan's copy/preview, filename variables and post-creation opening remain planned separately.
- Preserve existing IDs, content, enabled/order settings and drafts. Specific template selection must work in Finder and the creation panel; extension-only selection has a deterministic default.
- User follow-up: explicit Tab/Shift-Tab focus traversal in the creation panel, including image mode and the content editor, without requiring a system setting.

## Selected context

- Contracts: [templates](../../specs/domains/templates.md), [creation](../../specs/domains/creation.md), [startup](../../specs/domains/startup.md), [Finder](../../specs/domains/finder-permissions.md), [appearance](../../specs/domains/presentation.md).
- FileTemplate, CustomFileDraft, Preferences, TypesPane, PreferencesModel, creation panel and Finder menu labels.
- Checks: [HARNESS](../../specs/HARNESS.md); migration/selection/creation regressions, unsigned build, native settings and draft interaction.

## Evidence

| Check | Status | Result |
| --- | --- | --- |
| `make verify` | passed | 133 Core + 13 image tests, 5 public cases, 10 CLI and 3 appcast tests; `/tmp/filemint-multiple-templates-verify.log`. |
| Unsigned universal build | passed | Includes explicit keyboard traversal; `/tmp/filemint-multiple-templates-build.log`. |
| Native template selection | passed | `run.EHtQma`: default chosen/read back, editor shows independent name/content, name search selects a nondefault meeting template, real `会议.md` has exact expected content. |
| Native Tab / Shift-Tab | passed | `run.PxVofZ`: PNG skips disabled format, wraps and reverses; text name → format → destination → content → Paste and reverse; Cmd-Return preserves exact `Tab keeps this text.` bytes. |
| Installed Finder and macOS 13/Intel runtime | not-run | No installed app replacement in this task. |

## Handoff

- Next: implement the third task. Tested uncommitted 2026-09-22 worktree on macOS/Apple silicon; fixtures use private configuration and synthetic files.
