# Task: Repeatable native QA selected by changed scope

Status: complete — 2026-10-31 acceptance-efficiency follow-up verified
Next action: Select only affected suites; matching verified builds are reused automatically. Use NATIVE_QA_REBUILD=1 only when a fresh build is needed for diagnosis. User-assisted rounds follow HARNESS's 15–30 minute budget.

## Objective and scope

- Connect existing self-checking native fixtures to one plan/run interface.
- Select suites from working changes or an explicit base commit; allow explicit suites after reviewing shared-file behavior.
- Preserve stable QA identities, local Developer ID signing, sandbox entitlements and isolated stores.
- Accept a runtime check only after a fresh or input/identity-verified fixture build, successful new execution and its expected completion marker.
- Keep installed Finder callbacks, real authorization pickers, installer replacement and access migration as separate acceptance evidence.
- No production installation, release publication, permission-database changes or signing keys in CI.

## Selected context

- Workflow: [AI Playbook](../AI_PLAYBOOK.md), [HARNESS](../../specs/HARNESS.md).
- Native identities and execution: [Native QA](../../specs/verification/native-qa.md), [Finder/native checks](../../specs/verification/finder.md).
- Domains for fixture adapters: [Creation](../../specs/domains/creation.md), [File tools](../../specs/domains/file-tools.md), [Startup/preferences](../../specs/domains/startup.md), [Updates](../../specs/domains/updates.md).
- Entry points: `scripts/native_qa.py`, existing `build_*_harness.sh` and `*_smoke.swift`, `Makefile`.
- Load additional product contracts before changing their assertions or runtime behavior.

## Decisions and progress

- 2026-10-31: User requested committing the compatibility correction first, then
  optimizing acceptance. `6e936ee` is that local commit on `main`; no push.
  This follow-up changes only workflow/test infrastructure. Scope: per-kind input
  fingerprints, verified build reuse with an explicit rebuild override, fresh
  runtime data, bounded user participation and independent technical/experience/
  material states. Preserve failure logs, native identity and release gates.
  Earlier evidence below remains historical; no full GUI replay is required for
  this follow-up. Planned checks: `make verify`, representative repeated native
  modes for fresh/reused builds and fixture-data isolation, and document checks.
- 2026-10-31: 35 offline runner regressions and final `make verify` passed.
  Three signed fixture kinds were exercised freshly and by reuse with distinct
  runtime roots. Task-document changes during a native batch did not invalidate
  unrelated passing checks. No product code, signing identity or publication
  workflow was changed; the optimization is not committed or pushed.

- `make verify` keeps running offline infrastructure tests. Actual signed GUI fixtures use a separate local command.
- Nine automatic modes cover batch rename, template workflow/opening/update scheduling, open-with delivery, native icons, resource tools, design/settings and the headless favorite model.
- The favorite-model probe is an additional headless native check.
- Plans must retain manual boundaries and unknown runtime paths for review, rather than silently declaring them covered.
- The first actual run caught a fixture startup race: appearance edits overlapped the production model's asynchronous template recovery. The automated design mode now waits for the same bounded ready state as the existing settings check, preserving all persistence, rollback and immediate-appearance assertions. Its focused rerun and the final full run passed.
- Build-only project/CI edits do not start GUI checks. Config/entitlement changes still require scope review.
- Actual checks reverify signatures before execution; fresh builds require a new
  build ID, while reuse records the existing build ID and executes with new data.
  Failed rebuilds invalidate their cache receipt and never launch retained apps.
  Exit status, completion markers, timeouts, manual requirements and affected
  input changes all participate in the result.

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

## 2026-10-31 acceptance-efficiency verification

Primary checkout `main`, based on committed compatibility correction `6e936ee`
plus these workflow/test-infrastructure edits. Environment: arm64 macOS 27.2,
Xcode 27.1. Only documentation was completed after the final executable checks.

Changes:

- Per-kind conservative input manifests replace whole-worktree invalidation.
  Product/App/Shared/Core code, resources, compiler configuration and the kind's
  own adapters are covered. Ordinary docs and other QA adapters are excluded;
  fixture data such as the About release-notes Markdown remains an explicit input.
- Verified build reuse checks compiler/build environment, pinned signing identity
  and complete app contents. Requested rebuilds invalidate their cache receipt
  before compilation, so failure cannot fall back now or on the next invocation.
  `NATIVE_QA_REBUILD=1` / `--rebuild` remains available.
- Design, resource and icon QA now use separate runtime roots per execution;
  the design seed icon is inside the signed bundle. Existing other automatic
  fixtures already create isolated runtime workspaces. A build ID identifies
  code, while report IDs/data roots identify new executions.
- Runner-only changes rely on offline subprocess regressions and representative
  native cases. The default plan does not launch every GUI fixture for these edits.
- HARNESS and AI Playbook define a prepared manual scope, explicit completion
  condition, a 15–30 minute user-assisted budget and separate technical,
  user-research and publicity phases. Prior agreed release/safety gates remain.

| Check | Status / evidence |
| --- | --- |
| Final `make verify` | **passed**: 403 Core tests / 41 suites, 23 image tests / 2 suites, 35 runner regressions and all other offline checks; `build/acceptance-efficiency-verification.noindex/2026-10-31/make-verify-final.log`. |
| File-tools-settings and resource-tools, fresh then reused | **passed** per suite in `run.bplhqxo2` and `run.n02jma99`; same signed builds, new runtime roots. Both batches retained their separate design-ui failure. Final input comparison confirms these two kinds remain unchanged. |
| Design-ui and update-summary, final fresh then reused | **passed** in `run.7r0z8mk2` and `run.8zhge10d`; same signed build and source inputs, four distinct short temporary data roots. First run rebuilt only design; second reused it. |
| Documentation edit during execution | **passed**: `run.n02jma99` has differing before/after whole-worktree digests while its unaffected icon/resource results remain passed. Its design failure is a layout assertion, not source invalidation. |
| Recorded comparison | Both final design modes passed with identical inputs: fresh batch **54.528 s**, reused batch **22.003 s** on this host. This one observation includes preparation, validation and execution; it is not a speed guarantee or a cache of passing results. |

Machine-readable current-input comparisons, artifact identities, distinct runtime
roots and all report links are in
`build/acceptance-efficiency-verification.noindex/2026-10-31/verification-report.json`.
Each check still runs anew and needs exit 0 plus its completion marker.

Retained limitation: the initial long UUID workspace path triggered the existing
creation-panel 560-point width assertion in both `run.bplhqxo2` and `run.n02jma99`.
For the ordinary-layout fixture, data isolation now uses a short owned directory
under `/private/tmp`; its production layout code and all assertions are unchanged.
The long-path layout result remains failed and is outside this workflow change;
revisit it with creation-layout work or explicit long-path acceptance. Neither
rerun erases that evidence or proves the full launcher product accepted.

Scope limits: build input sets intentionally include conservative shared product
inputs rather than infer exact semantic dependencies. Manual Shortcuts/Raycast,
installed Finder, external persistent permissions and installed updates retain
their original boundaries. Their builders/evidence are not silently reused by
this automatic runner cache.

## Handoff

- Remaining implementation work: none for the connected automatic modes.
- Known limits: injected fixtures do not prove installed Finder callbacks, persistent external grants or installed updates.
- Interactive move/update authorization, isolated Sparkle replacement and access migration remain separate scenarios; no production installation, permission change, publication or remote CI execution was performed in this task.
- Commands and scope rules are in the [native execution checklist](../../specs/verification/native-qa.md#automated-local-checks).
