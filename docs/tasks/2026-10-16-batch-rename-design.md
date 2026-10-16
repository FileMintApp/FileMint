# Batch rename workspace redesign

Status: complete for implementation and automated acceptance; manual limits below
Next action: Requested installed follow-up and notice refinements are complete; review further design feedback when requested. See the follow-up evidence below.

## Objective and scope

- Make batch rename feel composed and easy to scan: ordered editing on the left,
  clear before/after names on the right, and fixed status/actions below.
- Scope: native rename view, presentation copy, window styling and focused UI
  regression coverage. Keep rule semantics, filesystem execution, authorization,
  Finder routing and saved preferences unchanged.
- Acceptance: useful empty state, clear rule hierarchy and inline problems,
  complete previews, bilingual light/dark layout, minimum-size usability, and
  preserved keyboard/undo/recovery behavior.

## Selected context

- Contracts: [Presentation](../../specs/domains/presentation.md#batch-rename-presentation)
  and [File tools](../../specs/domains/file-tools.md#batch-rename).
- Source: `BatchRenameView.swift`, `BatchRenameController.swift`,
  `BatchRenameText.swift`, existing shared `DesignSystem.swift` tokens.
- Verification: [HARNESS](../../specs/HARNESS.md),
  [native QA](../../specs/verification/native-qa.md#automated-local-checks),
  production-view `scripts/batch_rename_smoke.swift` fixture.

## Decisions and progress

- Adopt the existing native porcelain/graphite and mint palette, stronger name
  contrast, restrained rule cards and persistent action hierarchy. No new assets
  or dependencies. Add-rule starting actions use the existing draft mechanism.
- Move sort beside preview; expose first-problem selection while preserving every
  selected item and the existing asynchronous submission gate.
- Work in the primary checkout on `9833b19`; initial worktree was clean.
- Implemented common-rule starting actions, numbered rule cards with contextual
  operations, field focus/scroll on insertion, adjacent preview ordering, text and
  symbol row states, full-name details, first-issue navigation and fixed status/actions.
- Use the existing semantic colors in both appearances. Keep all 1,000 rows in
  the native virtualized table; no preview filter or filesystem changes.
- Minimum-size inspection exposed the previous `NSHostingView.sizingOptions = []`
  clearing the window minimum during layout. The root now provides an explicit
  screen-bounded minimum and exports `.minSize` only, preserving user resizing.
  This follows [Apple's hosting sizing contract](https://developer.apple.com/documentation/swiftui/nshostingview/sizingoptions).
  The fixture asserts the window minimum before rendering at 900 × 560 points.
- The QA window has an explicit identifier. Early layout failures were retained
  in `build/native-checks.noindex/run.z4ydue0a`, `run.p7tae3cc` and `run.v05eoumy`;
  they are not passed evidence. An intermediate build was blocked while Computer
  Use had launched the previous fixture; no running bundle was replaced.

## Evidence

### Installed follow-up and notice placement

The subsequent user request authorized fixes and installed acceptance, including
compact reassignment confirmation and prominent guidance above the right-hand
preview. The final local changes passed full verification, App/Finder builds and
156 signed native assertions; actual Finder sorting cancel/confirm, mode return,
conflict navigation and result-page undo passed. See the
[follow-up evidence](evidence/2026-10-16-batch-rename-workspace-followup.md).
The original UI-only observations below retain their original scope and limits.

### Original UI implementation checks

Tested worktree: `9833b19` plus this task's changes. Environment: arm64 macOS 27.2,
Xcode 27.1 (27A9275), Swift 6.4. Source hashes and local logs are under
`.local/verification/batch-rename-design/` (ignored, synthetic samples only).

| Check | Status | Evidence |
| --- | --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 make verify` | passed | Core 328 / 33 suites, Images 22 / 2, public Harness 5/5, CLI 10 and existing offline checks; `verify.log` |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | App and embedded Finder extension compile; `build.log`. Existing unrelated TemplatePreview async and AppIntents metadata warnings remain |
| `make native-qa-plan` / `make verify-native-affected` | passed | Final run `build/native-checks.noindex/run.ig8p78sd/report.json`, copied to `native-report.json`; only batch rename selected. 118 assertions include minimum dimensions, ordered rules, retained drafts, first-issue selection, stale previews, 1,000 rows, Return / Command-Return / Escape and existing sandbox operations |
| Native layout renders | passed | `FILEMINT_BATCH_RENAME_MODE=workspace-preview FILEMINT_BATCH_RENAME_EXPORT_ARTIFACTS=1` on the same signed fixture exports Chinese/light and English/dark empty, rules, minimum-size and conflict views; `layout-captures.log` |
| Live Computer Use | passed for listed scope | Real light/dark windows, selected-row full names, invalid-number error banner, disabled commit and first-issue navigation observed; `workspace-light.png`, `workspace-dark.png`, `workspace-error.png` |
| Live contextual rule removal | blocked | Menu expansion and labels observed; subsequent action/state retrieval timed out in Computer Use. Not counted as a completed removal interaction. The owned interactive fixture was terminated with SIGTERM after verifying its exact PID/path; no production app was touched |
| VoiceOver, older macOS, installed Finder/provider acceptance | not-run | Outside this UI verification environment; prior evidence is not reasserted |

The layout PNGs are native AppKit view-cache renders; live screenshots separately
confirmed the normal rendered controls. Interactive inspection uses
`FILEMINT_BATCH_RENAME_MODE=workspace-preview FILEMINT_BATCH_RENAME_INTERACTIVE=1`
and stops at the Chinese and English windows; closing each proceeds to the next.
No production files, preferences, folder grants or clipboard history are used.

## Handoff

- Remaining implementation: none. Design feedback and the manually blocked menu
  interaction can be revisited separately.
- Changed files: rename view/controller/text, its native smoke fixture, owning
  presentation contract, this task and the acceptance entry.
- Native limits: no installed Finder, older macOS, VoiceOver or provider evidence
  is implied by this UI task.
- Delivery: the user's follow-up authorizes a scoped commit and ordinary push to
  the existing `origin/main`. Installation and public release are outside this request.
