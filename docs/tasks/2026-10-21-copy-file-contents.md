# Task: Copy file contents

Status: complete
Next action: None for the requested implementation; installed Finder acceptance remains a separately recorded runtime boundary.

## Objective and scope

- Copy complete code/plain-text contents from Finder without opening an editor.
- RTF is conditional on content integrity and native paste compatibility checks.
- Images, PDF, Office, RTFD, multiple files and directory traversal are excluded.
- Preserve source files and preserve the clipboard on failures before publication.

## Selected context

- Contracts: [File tools](../../specs/domains/file-tools.md#copy-file-contents),
  [Finder permissions](../../specs/domains/finder-permissions.md#file-information-authorization),
  [Startup](../../specs/domains/startup.md#file-information-lifecycle),
  [Updates](../../specs/domains/updates.md) (cancel/wait before restart),
  [Presentation](../../specs/domains/presentation.md#appearance).
- Entry points: `FileTools`, `FileDigestService`, `FileOperationTicket`,
  `FinderSync`, `FileOperationCoordinator`, `FileToolsSettingsView`.
- Verification: [HARNESS](../../specs/HARNESS.md),
  [Core](../../specs/verification/core.md), [Finder](../../specs/verification/finder.md),
  [Native QA](../../specs/verification/native-qa.md).

## Decisions and progress

- Updated the owning SPEC first. Text is exact character content, not a byte-file
  duplicate; only an encoding BOM is removed. Source and output are each bounded.
- RTF retained its original bytes and complete text in the signed native fixture;
  rich/plain NSTextView paste preserved text and font/color/paragraph attributes.
  It is now admitted for text-and-style files; attachment/object-bearing RTF is rejected.
  The initial color assertion used display-dependent RGB; fixed calibrated RGB
  comparison confirmed the source color was preserved. No dependency was added.
- Initial implementation stayed in the primary checkout without installation or
  Git delivery. On 2026-10-22 the user requested committing all related changes.

## Evidence

Tested commit/worktree: primary `1475da6b056a23bc2f6a7b22ba79a1a85b740de3`
plus this uncommitted implementation. Native reports record the tracked diff and
untracked-source hashes; only this evidence text changed after those checks.
Environment: arm64 macOS 27.2 (26B5101f), Xcode 27.1 (27A9275), Swift 6.4.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 357 Core tests, 22 image tests, JSON/CLI harness and required offline/restricted checks; [log](../../build/copy-contents-checks.noindex/verify.log) |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | App and embedded Finder extension executables exist; [log](../../build/copy-contents-checks.noindex/build.log) |
| RTF admission and content-copy fixture | passed | [Final native report](../../build/native-checks.noindex/run.q1eh1xg4/report.json); original bytes, rich/plain paste, attributes, actual RTF reader/controller path and failure/cleanup checks |
| `file-tools-settings`, `update-scheduling`, `open-with` | passed | Fresh stable signed fixtures in the same [report](../../build/native-checks.noindex/run.q1eh1xg4/report.json) |
| `batch-rename` | passed on recheck | First run timed out in the existing Return-to-cancel sheet scenario; unchanged standalone recheck passed all 155 assertions. [Recheck report](../../build/native-checks.noindex/run.uunqk_h6/report.json). Initial timeout cause is unconfirmed. |
| `bash scripts/build_move_sandbox_harness.sh` | passed | Affected builder compiled/published a fresh isolated fixture; [log](../../build/copy-contents-checks.noindex/move-builder.log). Interactive external-folder moves were not run. |
| Installed Finder and external-folder grants | not-run | Separate runtime boundary |

## Handoff

- Remaining implementation work: none. Local commit authorized on 2026-10-22;
  installation, push and release remain outside this delivery.
- Settings: File & Folder Tools → Copy File Contents; independent default-off switch
  and main/submenu placement. One file, 8 MiB source/output caps; UTF-8 or BOM UTF-16
  plain text, text-and-style RTF with original rich bytes and a plain-text fallback.
- Known limitations: native fixture success will not prove installed Finder callbacks,
  every third-party paste target, provider-volume behavior or older macOS versions.
- RTF tests cover native AppKit rich/plain receivers and font/color/paragraph
  attributes, not arbitrary editor layout. Attachments/objects and RTFD are rejected.
