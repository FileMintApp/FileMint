# Task: Repeatable native QA selected by changed scope

Status: complete
Next action: Use `make native-qa-plan` for the next native interaction change, then run its reviewed scope.

## Objective and scope

- Connect existing self-checking native fixtures to one plan/run interface.
- Select suites from working changes or an explicit base commit; allow explicit suites after reviewing shared-file behavior.
- Preserve stable QA identities, local Developer ID signing, sandbox entitlements and isolated stores.
- Accept a runtime check only after a fresh fixture build, successful exit and its expected completion marker.
- Keep installed Finder callbacks, real authorization pickers, installer replacement and access migration as separate acceptance evidence.
- No production installation, release publication, permission-database changes or signing keys in CI.

## Selected context

- Workflow: [AI Playbook](../AI_PLAYBOOK.md), [HARNESS](../../specs/HARNESS.md).
- Native identities and execution: [Native QA](../../specs/verification/native-qa.md), [Finder/native checks](../../specs/verification/finder.md).
- Domains for fixture adapters: [Creation](../../specs/domains/creation.md), [File tools](../../specs/domains/file-tools.md), [Startup/preferences](../../specs/domains/startup.md), [Updates](../../specs/domains/updates.md).
- Entry points: `scripts/native_qa.py`, existing `build_*_harness.sh` and `*_smoke.swift`, `Makefile`.
- Load additional product contracts before changing their assertions or runtime behavior.

## Decisions and progress

- `make verify` keeps running offline infrastructure tests. Actual signed GUI fixtures use a separate local command.
- Nine automatic modes cover batch rename, template workflow/opening/update scheduling, open-with delivery, native icons, resource tools, design/settings and the headless favorite model.
- The favorite-model probe is an additional headless native check.
- Plans must retain manual boundaries and unknown runtime paths for review, rather than silently declaring them covered.
- The first actual run caught a fixture startup race: appearance edits overlapped the production model's asynchronous template recovery. The automated design mode now waits for the same bounded ready state as the existing settings check, preserving all persistence, rollback and immediate-appearance assertions. Its focused rerun and the final full run passed.
- Build-only project/CI edits do not start GUI checks. Config/entitlement changes still require scope review.
- Actual run checks verify signatures and a new fixture build ID before execution; failed builds never launch retained bundles. Exit status, completion marker, timeout, manual requirements and source changes all participate in the result.

## Evidence

Tested commit/worktree: primary checkout based on `a0e86bf` plus the local implementation; only verification documentation was completed afterward.
Environment: arm64 macOS 27.2, Xcode 27.1 (`27A9275`), Swift 6.4.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| Offline runner regressions and final `make verify` | passed | 20 runner regressions; existing Core/Images/Harness/CLI and offline checks passed. Log: `build/native-qa-automation-20261016/verify-final.log` |
| Initial native run | failed | 8 passed, design readiness failed; preserved report: `build/native-checks.noindex/run.thvg3bkt/report.json` |
| Focused design rerun | passed | Appearance, persisted settings/rollback, native captures and window dimensions; `build/native-checks.noindex/run.0t2f8uy6/report.json` |
| Final selected native run | passed | 9/9 modes; six Developer ID signed QA app kinds, plus headless favorite-model check. Report: `build/native-checks.noindex/run.j298ucf_/report.json` |
| Repeated representative builds/runs | passed | Batch rename, native icons and design: same IDs/paths/designated requirements; different build run IDs and data roots. `build/native-qa-automation-20261016/repeatability.json` |

The nine final check commands took 50.33 seconds in total. GUI-fixture compilation,
dependency preparation and preflight are recorded separately; the headless
favorite-model command includes its compilation. This is one local observation,
not a runtime guarantee. Office preview provider availability is recorded in the
template log; a graceful unavailable-provider result does not prove rendering in
an Office editor.

## Handoff

- Remaining implementation work: none for the connected automatic modes.
- Known limits: injected fixtures do not prove installed Finder callbacks, persistent external grants or installed updates.
- Interactive move/update authorization, isolated Sparkle replacement and access migration remain separate scenarios; no production installation, permission change, publication or remote CI execution was performed in this task.
- Commands and scope rules are in the [native execution checklist](../../specs/verification/native-qa.md#automated-local-checks).
