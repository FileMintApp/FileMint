# Task: 图片粘贴为文件

Status: complete
Next action: Implement the second task; installed Finder and supported-platform acceptance remain release checks.

## Objective and scope

- Save a copied screenshot/image as PNG in the chosen Finder folder, with preview, naming and collision increments.
- First of three tasks: this task → [multiple templates](2026-09-22-multiple-templates.md) → [Office document templates](2026-09-22-document-templates.md).
- Read one PNG/TIFF bitmap only on an explicit action. No monitoring, file-reference loading, animation, other output formats or automatic writes.
- Preserve existing drafts, transparent pixels, source dimensions and existing files. Cancel writes nothing.

## Selected context

- Contracts: [creation](../../specs/domains/creation.md), [Finder](../../specs/domains/finder-permissions.md), [startup](../../specs/domains/startup.md), [appearance](../../specs/domains/presentation.md), [distribution](../../specs/domains/distribution.md).
- Core creation/tickets; app clipboard capture; app-only image encoder; SharedUI creation panel; Finder New File menu.
- Checks: [HARNESS](../../specs/HARNESS.md), Core regression, real image encoding, unsigned universal build and isolated native panel interaction.

## Decisions and progress

- 2026-09-22: User authorized planning all three tasks and implementing them sequentially. No publication requested.
- Reuse private single-use creation tickets and the existing single draft panel; main app owns clipboard access and decoding.

## Evidence

Tested worktree: 2026-09-22 uncommitted clipboard-image implementation. Native fixture uses its own settings, synthetic image and named pasteboard.

| Check | Status | Result |
| --- | --- | --- |
| `make verify` | passed | 129 Core + 13 image tests, 5 public cases, 10 CLI and 3 appcast tests; `/tmp/filemint-clipboard-verify.log`. |
| Unsigned universal build | passed | Final UI correction included; `/tmp/filemint-clipboard-build.log`. |
| Native preview/create/repeat/cancel | passed | `build/design-ui-harness.noindex/run.fmRZXO/`: complete centered image, 1600×1000 PNG, identical numbered second copy, cancelled draft writes nothing. Preview clipping discovered and fixed. |
| Installed Finder; macOS 13/Intel runtime; external-folder permission cancellation | not-run | No installed app replacement or permission changes in this development task. |

## Handoff

- Next: implement the second task. Existing installed-Finder/platform checks remain separate from fixture evidence.
