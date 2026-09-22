# Task: 真实文档模板

Status: complete
Next action: Installed Finder, sandbox authorization and supported-platform release acceptance; no installation or publication requested in this task.

## Objective and scope

- Import a user's valid .docx or .xlsx file into a managed private template copy; create independent documents with original formatting/content.
- Third task, after [multiple templates](2026-09-22-multiple-templates.md). Existing UTF-8 text templates remain supported.
- Native file picker grants access. Validate supported Office package structure, regular-file identity and a bounded size before import; persist no dependency on the source location.
- Create without opening the document, executing macros or replacing existing files. Handle missing/damaged stored assets with actionable errors.
- No Word/Excel editing, document-variable replacement, macro-enabled formats, packages/directories, template sharing or publication.

## Selected context

- Contracts: [templates](../../specs/domains/templates.md), [creation](../../specs/domains/creation.md), [Finder](../../specs/domains/finder-permissions.md), [startup](../../specs/domains/startup.md), [appearance](../../specs/domains/presentation.md), [distribution](../../specs/domains/distribution.md).
- Core template model/store/validation and creation service; native import/settings and both creation routes.
- Checks: [HARNESS](../../specs/HARNESS.md); real Office fixtures, exact-byte preservation, malformed/missing assets, old-preference migration, unsigned build and isolated native import/create.

## Evidence

Tested worktree: uncommitted implementation based on `4788db0`, 2026-09-22.
Environment: macOS 27.2, Apple silicon, Xcode; unsigned arm64/x86_64 build.

| Check | Status | Result |
| --- | --- | --- |
| Final `make verify` | passed | 137 Core + 13 image tests, 5 public cases, 10 CLI regressions and 3 appcast tests. `/tmp/filemint-final-verify.log`. Includes damaged/oversized/ZIP64/macro packages, XML entities, source independence, asset removal, metadata migration and edited-draft protection. |
| Final unsigned universal build | passed | `/tmp/filemint-final-build.log`; no Office/ZIP dependency added. Test DOCX/XLSX resources are absent from the application bundle. |
| Native document import and creation | passed | `build/design-ui-harness.noindex/run.L5Dhxi/`: both documents selected through NSOpenPanel, managed references read back, then DOCX and XLSX created with Cmd-Return. Output, stored asset and source bytes match. python-docx/openpyxl independently read the heading, styled header and formula. |
| Appearance and keyboard | passed | Chinese/light import and document creation; English/dark at the 840×600 settings minimum. Document mode skips readonly content/Paste on Tab. Final duplicate/misleading text cleanup inspected with `run.Zly9QT` using the same private fixture store; a numbered Word copy preserved the existing file. |
| Installed Finder / sandbox grant cancellation / macOS 13 and Intel runtime / Microsoft Office runtime | not-run | Fixture app is separate from the installed app. Builds and byte-preserving copies do not claim these installed-platform checks. |

## Decisions and progress

- All three authorized tasks implemented sequentially. User's Tab/Shift-Tab request was included in the second task and retained in document mode.
- Private managed copies have independent UUIDs and SHA-256 integrity. No source path or bookmark is stored in the template record.
- ZIP validation uses system zlib and bounded in-memory XML parsing with external entities disabled; no extraction or document execution.
- Final review tightened local/central ZIP header consistency; the final automated suite and universal build include that change. Native UI evidence is scoped to the unchanged valid-document flows described above.
- The native fixture supports `--resume-fixture --document-preview --dark` for repeatable appearance checks using an already-owned fixture directory.

## Handoff

- Implementation and local verification complete. Remaining installed/platform scenarios are recorded above and belong to release acceptance.
- No commit, installation, system permission change, upload or publication performed. Public download-version feature claims and roadmap checkboxes were not advanced.
