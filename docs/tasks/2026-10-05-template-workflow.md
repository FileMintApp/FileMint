# Task: Template copying, preview, post-creation actions and template exchange

Status: implemented; some installed and native checks remain open.
Next action: When this workflow is under test again, select the unverified checks
in [Handoff](#handoff). The early implementation and review runs below describe
their own revisions and configurations.

## Scope and current contracts

This iteration added template copying and preview, per-template and per-draft
post-creation actions, and local template package exchange. The optional gates
start off. See [Templates](../../specs/domains/templates.md#copy-preview-and-template-exchange),
[Creation](../../specs/domains/creation.md#frozen-content-and-post-creation-actions),
[Startup](../../specs/domains/startup.md#optional-creation-features-and-template-recovery)
and the later [post-creation application fix](2026-10-08-creation-opening.md).
Dynamic filenames remain in the [roadmap](../ROADMAP.md#文件名规则).

For the original proposal, acceptance case definitions A01–A35 and planning
prototype checks, see the [historical plan](https://github.com/FileMintApp/FileMint/blob/46882c07d1eee100cb6c200a89e72201c78a36c8/docs/tasks/2026-10-05-template-workflow.md#acceptance-matrix).
Choose current checks from the [Finder verification guide](../../specs/verification/finder.md).

## Implementation evidence — 2026-10-05

Checkout: `/Users/daigua/Documents/Ray/FileMint`, `main`, base `64820a9` plus
uncommitted implementation. The initial `564d/FileMint` worktree was migrated with
15-file byte verification and then removed at the user's request. AGENTS now
requires an explicit request before using a worktree. The primary checkout's
existing planning edits were preserved.

Environment: macOS 27.2 (26B5091g), arm64, Xcode's Swift 6.4, deployment target 13.0.
Code snapshot SHA-256: `4c81e26c9f5e5192eeb55fa99dfa55eeea1d4addae61d146a3f6961314385d1e`.
The [source digest](../../build/template-workflow-qa-2026-10-05/source.sha256)
covers App/SharedUI/Core source and tests, project/Info and the native fixture.
The final Core refinement and validation-cancel UI are covered by the full run/build.
The last matching native fixture run is in [native-final.log](../../build/template-workflow-qa-2026-10-05/native-final.log);
view-cache images are from the preceding render pass and are partial evidence.

| Check | Status | Current evidence and boundary |
| --- | --- | --- |
| `make verify` | passed | [Log](../../build/template-workflow-qa-2026-10-05/verify.log): 210 Core tests, 14 image tests, 5/5 public JSON cases, 10 CLI regressions, appcast/release/notarization/resume/entitlement checks. No public Harness schema expansion. |
| `make project`; `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | [Build log](../../build/template-workflow-qa-2026-10-05/build.log). Main app and Finder extension build; `project.yml` owns the exported package type, and generated `Config/AppInfo.plist` reflects it. Version/build and entitlements unchanged. |
| `bash scripts/build_template_workflow_harness.sh` | passed | [Build log](../../build/template-workflow-qa-2026-10-05/native-build.log). Disposable sandboxed application uses production model, panel, preview and executor; receiver is a unique fixture identity with test-only policy injection. |
| `FILEMINT_TEMPLATE_QA_MODE=screenshots <fixture>/Contents/MacOS/TemplateWorkflowSmoke` | passed with explicit environment limits | [Native log](../../build/template-workflow-qa-2026-10-05/native.log): four gate combinations/persistence, failed preference save without generation advance, Office copy and last/shared-reference cleanup, hidden-action preservation, real receiver handoff, stale/off-origin gates, duplicate completion and replacement rejection. |
| TextEdit signing profile | passed | Native Security API validates Apple's signed `com.apple.TextEdit`. This establishes the publisher profile, not visible editor content. |
| VS Code signing profile | blocked | The installed `com.microsoft.VSCode` declares Microsoft team `UBF8T346G9` but strict verification reports its sealed `workbench.html` modified. The production executor rejects this route and retains the saved file. No repair or installation performed. |
| Office native content preview | blocked | Both valid bundled DOCX/XLSX return unavailable from the system thumbnail provider in the sandbox fixture. Metadata fallback, invalid/missing-asset state, source-byte preservation, stale-result cancellation and owned-snapshot cleanup passed. Native document rendering/offline provider behavior is not claimed. |
| Bilingual/native layout | partial | 24 native view-cache renders cover four gate combinations in settings/types/creation, with light/dark variants. SwiftUI layouts and full metadata fallback inspected. AppKit cached panel renders are incomplete; these are not live screen captures or keyboard/VoiceOver proof. |
| Desktop interaction automation | blocked | `cua_repl` failed to start its Node runtime with `No such file or directory`. No live clicking, typing or VoiceOver/keyboard acceptance can be inferred from the view-cache images. |
| Installed signed Finder, macOS 13, actual editor rendering, quit/update interaction | not-run | No installation requested; minimum-target compilation and isolated receiver success do not prove these scenarios. |
| Final diff/privacy review | passed | No dependencies, folder crawling, clipboard monitoring, user-file content logging, Finder transport changes, installation, commit or publication. Existing clipboard/image paths retain their fallback; Core receipts distinguish actual text from binary bytes. |

Acceptance coverage is intentionally split by evidence type:

| Acceptance IDs | Current coverage | Outstanding evidence |
| --- | --- | --- |
| A01, A03–A05 | Core migration/generation plus production-model save-failure and hidden-action fixtures | Ordinary installed-app relaunch UI remains unobserved. |
| A02, A34 | Source visibility/focus order and four-combination native renders | Live keyboard, minimum-size interaction, VoiceOver and Reduce Motion. |
| A06, A22 | Bounded validated snapshots, invalid/missing states, cancellation and unavailable-provider cleanup | Successful Quick Look content rendering, read-only/offline behavior on supported systems. |
| A07–A11 | Complete-field Core copies, restoration/migration and production Office reference cleanup | Live Copy editor cancel/failure/source-removal UI. |
| A12–A15 | Fixed UTC boundaries, independent byte expectations (BOM/CRLF/Unicode/literal tokens), actual collision names, exact-ID action rules | Live template switching/quick Finder routes. |
| A16–A21 | Immutable follow-up provenance, sticky selections, receipt identity, native receiver and rejected/duplicate routes; existing termination policies plus extended pending-work accounting | Actual supported editor content, picker/permission retry UI, moved app cases and ordinary quit/updater interaction. |
| A23–A27 | Independent V1 ZIP fixture, text/Office round trips, strict schema/CRC/header/path/flag/count/UTF-8 checks, deterministic merge/default rules and bounded-file tests | Native package picker/save-panel overwrite paths and maximal combined Office expansion stress. |
| A28–A31 | Immutable Data snapshot, semantic revision canonicalization, compatible stale-review choices; save rollback and fresh recovery at journal/staged/published/before-save/after-save/cleanup checkpoints, replaced-file/corrupt-journal and mid-commit corrupt-preferences preservation | Actual process termination/power-loss and replaced-stage native fixtures. |
| A32–A33 | Atomic export implementation, asset validation, inert app hints, unchanged gates and no automatic app discovery/launch | Interactive export cancellation/overwrite and local app repair. |
| A35 | Existing focused creation/clipboard/image tests retained; common panel/executor compiled, actual byte-kind receipts and untemplated fallback connected | Installed cold/warm/repeated Finder and clipboard interactions. |

Implementation decisions:

- Preserve the effective default when a disabled source's enabled copy would
  otherwise precede the old implicit default; pin the old ID only in that case.
  Existing explicit defaults and ordinary copies stay unchanged.
- Keep a semantic preferences revision. Set iteration order in existing resource
  and file-tool preferences is normalized only for hashing, preventing spurious
  stale-import decisions without changing saved settings semantics.
- Require actual text receipts and trusted publisher signatures for the initial
  TextEdit/VS Code editing profiles. Office and binary routes without a verified
  editing profile keep the saved file and present a follow-up failure/Reveal path.
- Give imported selected-app hints no authority. Resolve only matching existing
  local references that were freshly validated; no imported gates or bookmarks.
- The snapshot read/write guards extend through post-creation completion. A saved
  receipt can retry opening only; the executor has no file writer.

## Code-review fixes — 2026-10-05

The four findings from the review of this uncommitted implementation are fixed
in the primary checkout. These restore the existing contracts; no installation,
commit, push or publication was performed.

- Preferences: serialize store writes and atomic read/modify/save operations;
  compare model saves with their committed baseline. Block and roll back ordinary
  model saves during template work. The import revision check, settings commit
  and journal reconciliation share the same lock; folder authorization updates
  preserve the latest template configuration. Reload after import completion.
- Export: use Foundation's same-volume item replacement directory instead of
  creating a sibling directory that a file-only save-panel grant cannot authorize.
  Publish by atomic rename after writing and checking cancellation.
- Import review: resolve each conflict against the preceding accepted choices,
  retain explicit Copy choices when an earlier row is skipped, and invalidate
  the old executable plan throughout rebuilding and after failure. Both the
  button and the commit entry point require a valid current plan.
- Selected applications: reject saving an action without a valid portable app
  identity, disable Save for that draft, and migrate malformed persisted actions
  to the existing reveal fallback. Valid imported hints remain saveable/exportable
  without a local application grant.

Current source identity is recorded in the
[source manifest](../../build/template-workflow-bugfix-2026-10-05/source.sha256).
Results below apply to that uncommitted snapshot, macOS 27.2 arm64, Xcode Swift 6.4.

| Check | Status | Evidence |
| --- | --- | --- |
| `make verify` | passed | [Log](../../build/template-workflow-bugfix-2026-10-05/verify.log): 214 Core tests, 14 image tests, 5/5 public cases, 10 CLI regressions and release/appcast/signing checks. Initial restricted execution was blocked by Swift cache permissions; the approved standard-cache run passed. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | [Log](../../build/template-workflow-bugfix-2026-10-05/build.log): unsigned app and Finder extension built. |
| Native production-model regression fixture | passed | [Build](../../build/template-workflow-bugfix-2026-10-05/native-build.log), [run](../../build/template-workflow-bugfix-2026-10-05/native.log): ordinary saves roll back while busy, invalid app actions preserve settings, an actual size-limit replan failure blocks submission, and a corrected review imports successfully. Existing gate/copy/receiver/receipt checks also pass. |
| File-only sandbox export | passed | [Log](../../build/template-workflow-bugfix-2026-10-05/export-sandbox.log): the production codec creates and atomically overwrites the exact allowed destination while sibling writes are denied. [Probe](../../build/template-workflow-bugfix-2026-10-05/ExportProbe.swift) and [profile](../../build/template-workflow-bugfix-2026-10-05/export.sb) retained. This models the file grant; it is not a live Save-panel interaction. |

The earlier native limitations remain: the installed VS Code signature is rejected,
Office providers return unavailable, and installed Finder/live keyboard/VoiceOver
acceptance has not been completed. These checks do not claim full product QA.

## Commit QA and selected-application icons — 2026-10-05

The requested revision is `51e49db28dd0e342b5c84f40bf86b4ecb5af46af`;
HEAD matched and the primary checkout was clean when verification started.
Environment: macOS 27.2 (26B5091g), arm64, Swift 6.4. The installed 0.6.6/build 25
app was not replaced or used as a fixture. Its real preferences SHA-256 remained
unchanged. Only disposable sandbox fixtures and owned test files were used.

During QA the user requested native application icons after selecting a creation
application, including temporary choices. That narrow follow-up is uncommitted
on top of the requested revision. Its rule is in [Presentation](../../specs/domains/presentation.md).
Template editing and the panel show the selected icon/name, keep accessible text,
use a generic icon for an unavailable local reference, and cancel icon work when
hidden or closed. Imported hints never cause application discovery.

| Check | Status | Current evidence |
| --- | --- | --- |
| Original revision `make verify` | passed | [Log](../../build/qa-51e49db-2026-10-05/verify.log): 214 Core tests, 14 image tests, 5/5 JSON cases, 10 CLI regressions and offline release checks. Initial restricted-cache failure was resolved with the approved standard-cache run. |
| Original unsigned app/extension build | passed | [Build](../../build/qa-51e49db-2026-10-05/build.log); generated from project.yml. |
| Original sandboxed native fixture | passed | [Run](../../build/qa-51e49db-2026-10-05/native-ui.log): model/save/review regressions, copy/asset lifetime, gate generation, receiver dispatch, duplicate/replaced-file rejection and preview cleanup. |
| Live copy and text preview | passed | Office copy canceled without adding an entry. Markdown copy saved after its source with a fresh ID, enabled state and unchanged default. Editor preview displayed the exact fixed 2026-01-01 UTC example. [Readback](../../build/qa-51e49db-2026-10-05/ui-readback.json). |
| Live creation and TextEdit content | passed | Filename-to-suffix synchronization, Tab from content to Paste, plain paste/undo and Command-Return observed. The actual saved bytes matched Unicode, emoji and literal tokens. System TextEdit opened the exact created URL and visibly displayed the expected text. [Created text](../../build/qa-51e49db-2026-10-05/ui-textedit.txt). No editing policy was injected for this handoff. |
| Native package export/import | passed | Native Save panel wrote the [package](../../build/qa-51e49db-2026-10-05/ui-export.filemint-templates); independent ZIP inspection confirmed exact payload/digest, portable app hint, and no local path/bookmark/registry ID. Native import review defaulted the duplicate to Skip with Import disabled; Save as copy then added an independent 18th row. Existing 17 rows, defaults, gates and app registry were unchanged. |
| Icon follow-up automatic/build checks | passed | [Verify](../../build/qa-51e49db-2026-10-05/icons-verify.log), [build](../../build/qa-51e49db-2026-10-05/icons-build.log), [native regression](../../build/qa-51e49db-2026-10-05/icons-native-ui.log). Native icon bitmap/name, invalid identity, disable/hide and re-enable restoration checked. |
| Icon follow-up live UI | passed | Actual temporary TextEdit selection displayed icon/name; Cancel left the registry and template actions unchanged. Template editor displayed the icon immediately and after save/reopen. A fresh panel following that saved template showed the icon/name and Create and Open. Chinese/light layout inspected on screen. |
| Office native content rendering | blocked | Both DOCX and XLSX providers returned unavailable on this machine. Explicit fallback, missing/invalid asset rejection and snapshot cleanup passed; content rendering is not a pass. |
| Installed VS Code editing profile | blocked | Current strict signing validation rejects the installed bundle. The route remains denied; no repair or installation attempted. |
| Installed signed Finder, macOS 13, full keyboard/VoiceOver/Reduce Motion and bilingual appearance matrix, actual quit/update lifecycle | not-run | Isolated source QA does not prove these remaining environments/interactions. Live automation was usable but had transient AX/timeouts; native cache images were not substituted for live evidence. |

No new confirmed defect was found in the exercised original-revision paths.
This is a bounded QA result, not full A01–A35 native acceptance or release approval.
Source digests and fixture readbacks are retained in
`build/qa-51e49db-2026-10-05/`. No commit, installation or publication was performed.

## Handoff

- TextEdit and the editor, creation and package flows had bounded live evidence,
  as described above. Full keyboard/VoiceOver, Reduce Motion and bilingual
  appearance checks, Office rendering providers, trusted VS Code, and installed
  Finder authorization/creation still need their respective environments.
- macOS 13 runtime, actual quit/update lifecycle and interruption/recovery tests
  were outside the observed acceptance. Use the matching fixture or installed
  build; the historical results do not prove those paths on another revision.
