# Batch rename confirmation, lifecycle and notices — 2026-10-16

Result: **passed for the requested fixes and local installed acceptance**.
The latest signed Debug is installed at `/Applications/FileMint.app`.
This follow-up closes the live sorting-confirmation gap in the
[earlier installation check](2026-10-16-batch-rename-installed-debug.md).

Parent: [batch rename](../2026-10-14-batch-rename.md).
UI task: [workspace redesign](../2026-10-16-batch-rename-design.md).

## Scope and findings

The user authorized investigating the checking-state stall, directly fixing
problems, rebuilding and reinstalling. During acceptance the user additionally
requested a compact confirmation sheet and prominent guidance above the preview.
The owning [presentation contract](../../../specs/domains/presentation.md#batch-rename-presentation)
was updated before the notice-layout change.

- A minimal signed native regression failed against the original controller:
  after closing an editing panel, a late editor callback still changed its draft
  and started a preview without a source session. No worker could finish that
  ownerless checking state. `reproduce-transitions.log` records the failure.
- Editing now requires the active source session/panel and rejects closed,
  running, undo/recovery and pending-confirmation input. Byte-identical text and
  unchanged rule callbacks do not start redundant checks.
- Preview tasks, close continuations and reassignment completions are bound to
  their owning presentation. Old work cannot clear a newer worker, close a later
  panel or invalidate its undo preview.
- Reassignment no longer runs a synchronous application-modal loop from a Picker
  binding. A deferred, owned native sheet retains the current mapping until an
  explicit choice. Cancel/default Return/Escape preserve mapping and mode;
  explicit Reassign retains the text and recomputes against the requested order.
- Native checks caught the default-button/Escape conflict in NSAlert. The final
  sheet owns its key handling; no global key monitor is used. A subsequent user
  screenshot exposed excessive fixed-height whitespace. The final height follows
  the measured native labels/buttons, with a regression for the action-row gap.
- Readiness, counts, concrete issues, next-step guidance and the protected-name
  reminder now occupy a prominent bordered notice above the right-hand table.
  The fixed footer holds actions. Errors show the first concrete reason and a
  nearby Show First Issue button; ready, checking, pending confirmation and
  results use distinct copy. Chinese/English and minimum-size previews were read.

The original one-off installed stall was not reproduced with its identical
event sequence, which included accessibility/stale-window failures. The separate
ownerless-checking defect was reproduced and fixed. The final real result-page
undo and five automatic rename/undo cycles completed without the stall; this
does not retroactively turn the earlier anomalous observation into a pass.

## Final source and checks

Base: primary checkout `c97f01ba15acc82fd06642f01921fee3fd898ac0` plus the recorded
local changes. Product changes are limited to `BatchRenameController.swift`,
`BatchRenameView.swift` and `BatchRenameText.swift`; the native fixture, owning
SPEC and evidence were updated. Version remains 0.7.0/build 28.
Environment: arm64 macOS 27.2 (`26B5101f`), Xcode 27.1 (`27A9275`), Swift 6.4.

Final logs and source hashes: `.local/batch-rename-followup-20261016/`.

| Check | Final observation |
| --- | --- |
| `PYTHONDONTWRITEBYTECODE=1 make verify` | passed; Core 328/33 suites, Images 22/2 and the complete standard offline checks; `notice-final-verify.log` |
| Unsigned App/Finder build | passed; `notice-final-build-unsigned.log` |
| Signed native batch-rename scope | passed **156 assertions**, including **38** focused confirmation/lifecycle/layout checks and five real rename/undo cycles; `build/native-checks.noindex/run.aoewe2so/report.json` |
| Chinese/light, English/dark and minimum-size native renders | passed for the inspected scope; `notice-previews.log`, `workspace-*.png`; composited AppKit layers may be absent from offscreen captures |
| Direct Debug build | passed with `ENABLE_DEBUG_DYLIB=NO`; `notice-final-build-debug.log` |
| Signing and installed bundle checks | passed with the original Developer ID team `8S66M2ZLD5`, production sandbox, arm64, Sparkle services and compression runtime; `notice-final-sign.log`, `notice-final-verify-installed.log` |
| Installed/build comparison | all 89 files/links match; `installation.json` binds `source-hashes.json` and the final binary hashes |

Main SHA-256: `9825b18e6b7523b2b7333aaf0bd1c1468244b8e00a117cf85048dde656d88470`.
Finder SHA-256: `3d752298fbff0f39e25fb4c0d80dc07b437348403196a59dbbcf49088130c360`.
Previous and intermediate installed bundles were preserved under the ignored
evidence directory. Each replacement followed normal main-app exit. The existing
Finder extension switch was restored to its original on state; final main PID
4267 and extension PID 4285 mapped the final installed executables.

## Final actual Finder acceptance

Used the existing synthetic `02-swap` parent under
`build/installed-rename-qa-20261016/`; its saved exact-parent authorization was
reused. The final installed application, not the QA fixture, performed these steps:

1. Actual Finder selection opened the new preview-top notice. Duplicate list
   entries displayed a prominent concrete conflict, disabled submission and
   supported Show First Issue plus full-name details.
2. Replaced the list with `名单甲` / `名单乙`. Default Return and Escape separately
   cancelled descending-order reassignment; the workspace and ascending mapping
   remained intact. Actual native capture confirmed the compact sheet layout.
3. Explicit Reassign retained the text and mapped descending `beta.txt` to
   `名单甲.txt`, `alpha.txt` to `名单乙.txt`.
4. Switched to Rules and changed ordering to ascending. Returning to the populated
   list requested confirmation; Escape preserved Rules, and a later explicit
   Reassign returned to the retained list with the ascending mapping.
5. Clicked Rename 2 Items. Host readback verified `alpha.txt` → `名单甲.txt` and
   `beta.txt` → `名单乙.txt`, with original inodes/content. `installed-rename.json`.
6. Clicked result-page Undo. The reverse preview was ready rather than stuck in
   checking. Clicking Undo 2 Items restored both originals. Closed the result
   and quit normally, confirming operation ownership was released.

Computer Use sometimes returned an accessibility failure after a successful
window transition. Those actions were reconciled by reading the new window and
filesystem state; no mutation was blindly retried or inferred from a click alone.

Final readback at **20:48:56 Asia/Shanghai** (`final-state.json`): all 22 original
entries, including 16 regular files, retain their original names, inodes and
contents. The private rename store is empty; the main process exited normally.
Finder added only `.DS_Store` inside the fixture root. Saved preferences/menu
scope remain byte-identical, SHA-256
`c6ca47c27c191110cfe9d2f57e793b3e3b842784971b02cddd30592f846529fa`.
Independent parent grants were retained, not reset.

VoiceOver, older macOS, actual reboot/remount and other storage providers were
not revalidated. No commit, push, public release or notarization ran in this scope.
