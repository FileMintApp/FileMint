# Hide and unhide selected Finder items — 2026-10-29

## Current state

Selection-scoped implementation, applicable automated/native checks and website
guide/privacy-copy build passed. The installed
app has not been replaced, and installed Finder callbacks/external-folder grants
remain a separate acceptance boundary.

## Confirmed user requirements

- Operate on the currently selected files/folders in Finder's right-click menu.
- Read their hidden state where possible. Uniform selections offer one explicitly
  named action; mixed or unknown states offer both Hide and Unhide.
- Use “隐藏此项目 / 取消隐藏此项目”, with plural labels for multi-selection.
  “显示隐藏文件” would describe Finder-wide visibility and is not this action.
- The earlier permission-flow repair addressed the original global display-toggle
  design. The user clarified that this design did not match the intended behavior;
  it has been replaced, including its settings/menu-bar action and permission code.

## Scope and implementation

- Owning contracts: [file tools](../../specs/domains/file-tools.md#hide-and-unhide-selected-items),
  [Finder/permissions](../../specs/domains/finder-permissions.md), and
  [startup/settings](../../specs/domains/startup.md), and
  [presentation](../../specs/domains/presentation.md) for guide/privacy copy and icons. Finder transport follows the
  existing [creation](../../specs/domains/creation.md) and single-use ticket rules.
- Hide & Unhide is an opt-in File & Folder Tools child with submenu/main placement.
  New/missing/invalid settings leave it off. No production preferences were changed.
- Finder reads only selected-entry metadata to choose one or two menu actions.
  A click captures item/real-parent identities and the explicit requested state;
  the main app authorizes the exact parents and serializes the operation.
- The Core service pins no-follow metadata descriptors, changes the BSD hidden bit
  and clears the legacy FinderInfo invisible bit on Unhide, preserving other
  flags/metadata, names, bytes and directory descendants.
  Recheck identities, current switches and resolved scope before mutation.
  Whole-batch preflight precedes writes; later failures report processed/total.
- Names beginning with a period remain name-hidden. Unhide rejects the complete
  batch before changes if it contains one; FileMint never renames such a file.
  Other known hidden mechanisms that the BSD bit cannot clear fail explicitly.
- Success is silent. Finder's ⌘⇧. is documented as a manual way to temporarily
  reveal hidden entries for selecting Unhide. No Accessibility permission, key
  injection, Finder preference change, crawling or Finder restart is involved.

## Verification

Worktree: primary `a49a75ac614ffe7f501c72b0f22c8c19b59504ec` plus this change;
arm64 macOS 27.2 / Xcode 27.1 / Swift 6.4.

| Check | Status | Evidence |
| --- | --- | --- |
| Native API diagnostic with private temporary files | passed | O_EVTONLY descriptors support BSD hidden flag changes on files/directories; dot names stay hidden. `build/file-visibility-checks.noindex/probe.swift` |
| `make verify` | passed | 381 Core + 23 image tests, 5 public Harness cases, all script/subprocess regressions; `build/file-visibility-checks.noindex/verify.log` |
| Unsigned Release App/Finder build | passed | `build/file-visibility-checks.noindex/build.log` |
| Signed sandbox `file-visibility` | passed | Final report `build/native-checks.noindex/run.4wnlxkab/report.json`, fixture `template-workflow-harness.zZUKnT`; actual BSD and FinderInfo hide/unhide through the production coordinator. |
| `file-tools-settings` and `design-ui` | passed | Individual UI/icon checks in `build/native-checks.noindex/run.l0e8d3ee/report.json`; its then-failing visibility assertion was corrected and replaced by the final report above. UI/icon code was unchanged in that follow-up. |
| `SITE_BASE=/FileMint/ pnpm run site:build` | passed | Bilingual guide/privacy copy and base-path build; `build/file-visibility-checks.noindex/site.log` |
| Installed Finder callbacks and external write grants | not-run | Needs a signed installed candidate and the affected [Finder scenario](../FINDER_QA.md#finder). |

The diagnostic also confirmed that macOS checks read access when opening an
O_EVTONLY descriptor. This flag is not a byte-read security boundary; production
only calls metadata APIs on the handles. Capture-only read denial and authorized
mutation are separate checks, using the existing read/write parent grant. The
positive mutation profile denies content writes and host readback checks bytes.

Coverage includes state-driven naming, real attribute round-trips, non-hidden
flags and FinderInfo fields, immutable selection/action snapshots, stale identities, dot-name failure,
revocation/partial counts and one-use tickets. The new restricted subprocess check
must demonstrate successful metadata-only writes and denied-write preservation;
the existing signed sandbox fixture exercises the production coordinator, including
legacy FinderInfo invisibility. Both executables exist in the unsigned Release
app. Guide screenshots/instructions for the removed global toggle were replaced
with the new selection-based workflow; privacy copy now describes metadata access.
No installation, DMG/ZIP, release or remote publication was requested.

## API references

- [Apple isHiddenKey](https://developer.apple.com/documentation/foundation/urlresourcekey/ishiddenkey):
  metadata is read/write; changing it does not reveal names beginning with a period.
- [Apple file-system flags](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemDetails/FileSystemDetails.html):
  UF_HIDDEN is the GUI hidden flag; unrelated flags must be preserved.
- [Apple Finder information flags](https://developer.apple.com/library/archive/technotes/tn/tn1150.html):
  legacy kIsInvisible is separate from the BSD flag. Read and change only that bit
  within the fixed-size FinderInfo metadata; never read resource forks.
