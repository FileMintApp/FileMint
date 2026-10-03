# Task: Built-in blank Office templates

Status: complete
Next action: None for implementation. Installed Finder and Microsoft Office acceptance remain separate checks before claiming those environments.

## Objective and scope

- Ship blank Word and Excel presets, enabled for new installations and appended
  disabled for existing settings. Preserve imported templates, suffix defaults,
  customizations and removed built-in identities.
- Reuse exact-byte document creation, independent copies and collision numbering.
- Include resource packaging, bilingual names/search, migration and regression
  coverage. PPTX, Office editing, installation and release are out of scope.

## Selected context

- Contracts: [Templates](../../specs/domains/templates.md),
  [Creation](../../specs/domains/creation.md),
  [Startup](../../specs/domains/startup.md),
  [Distribution](../../specs/domains/distribution.md),
  [Presentation](../../specs/domains/presentation.md).
- Entry points: FileTemplate, DocumentTemplateStore, CustomFileDraft,
  Localization and CorePackage/Package.swift.
- Verification: [HARNESS](../../specs/HARNESS.md),
  [Core checks](../../specs/verification/core.md), affected creation/type scenarios
  in [Finder QA](../FINDER_QA.md).

## Decisions and progress

- Keep versioned bundled asset references separate from imported UUID assets.
  Catalog construction performs no file I/O. Creation reads and validates the
  known bundled asset; deleting a preset never removes bundled or imported bytes.
- Update the owning contracts before implementation.
- Added two immutable package resources, localized preset names and search
  aliases, recoverable bundled-resource errors and five focused regression tests.
  Existing migration/restoration code handles stable Office template IDs without
  overwriting imported defaults or user edits.
- Resources were generated from an empty python-docx 1.2.0 document (one empty
  paragraph) and openpyxl 3.1.5 workbook (one empty Sheet1). Core properties were
  cleared, the Word thumbnail removed, application metadata set to FileMint, and
  ZIP entry timestamps normalized to 2000-01-01. These libraries are generation
  tools only, with no new app/package dependency. Reference byte counts and
  SHA-256 digests bind the checked-in files; future versions must keep old assets
  readable rather than changing their bytes in place.
- Updated bilingual usage/installation copy and the native QA checklist.
- The design fixture copies the Core resource bundle. Release app/extension
  copies match the source bytes, and resource lookup has no build-path fallback.

## Evidence

Tested commit/worktree: `85535ff` plus this uncommitted implementation.
Environment: macOS 27.2, arm64, Xcode toolchain; isolated native fixture
`build/design-ui-harness.noindex/run.mlqJID/`.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 191 Core tests, 14 image tests, 5/5 public Harness cases, 10 CLI regressions and offline release/appcast/entitlement checks. [Log](../../build/office-template-qa.noindex/verify.log). |
| Unsigned `make build` | passed | Release main app and Finder extension, both arm64. [Log](../../build/office-template-qa.noindex/release-build.log). |
| Bundled asset inspection | passed | Both binaries contain the exact source resources; blank content, empty personal metadata and no external relationships. [Audit](../../build/office-template-qa.noindex/resources.json). |
| `SITE_BASE=/FileMint/ pnpm run site:build` | passed | Bilingual site compiled. [Log](../../build/office-template-qa.noindex/site-build.log). |
| Native creation/type interactions | passed | Fresh fixture shows 9/16 enabled, including both Office presets. Renamed Word/display filename saved; suffix stayed fixed. Cmd-Return created both documents with exact source bytes and no private template assets. [Evidence](../../build/office-template-qa.noindex/native-evidence.json). |
| Independent document library read/edit/save | passed | python-docx and openpyxl read blank resources and round-tripped edits. No Office runtime claim follows from this check. |
| WPS open/edit/save | passed | Native WPS opened both generated documents without a document repair prompt. Typed test content, saved locally and independently read the content back; one Excel worksheet retained. [Evidence](../../build/office-template-qa.noindex/native-evidence.json). |
| Microsoft Word / Excel open-edit-save | not-run | Microsoft Word/Excel are not installed in `/Applications`; WPS checks do not establish Microsoft compatibility. |
| Installed signed Finder / minimum macOS | not-run | Did not replace the installed app. This fixture exercises production panel/model code, not an installed Finder callback. |

The first restricted build attempts were blocked by Swift/Xcode cache access;
approved sandbox escalation allowed the checks above. The initial test run found
an obsolete seven-option expectation and an incorrectly ranked custom test
fixture; both test expectations/setup were corrected before the final pass.
Only this task's generated app registrations were removed after QA. PluginKit
still reports the installed `/Applications/FileMint.app` extension as its sole
registered instance. No commit, installation or publication was performed.

## Handoff

- Remaining implementation work: none.
- Known limitations: installed signed Finder, Microsoft Word/Excel and minimum
  macOS compatibility remain unverified for this change.
