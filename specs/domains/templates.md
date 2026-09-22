# File types and templates

Load for: Preset/custom types, ordering, restoration, migration and template rendering.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## File types

- Presets: txt, md, swift, json, html, css, sh, csv, yaml, xml, js, ts, py, sql.
  The original seven are visible by default; additional presets can be enabled.
- Settings → File Types can add/edit/remove saved custom types, including a
  display name, suffix, default filename and optional initial template content.
  Multiple templates may share a suffix; stable IDs identify templates. Changes persist and refresh Finder without
  restarting the app. Enabled types are shared by quick actions and the picker.
- Users can enable/disable and reorder types. Built-in templates have stable IDs.
  Restoring built-ins preserves custom types and requires a confirmation.
- Older preferences retain language, folder selection, template customizations,
  enabled state and order; newly added presets are appended disabled.
- Do not expose nonfunctional favorites, icon toggles, themes or dashboards.

## Multiple templates and defaults

- Each template stores an explicit suffix independently of its default filename.
  Decode older templates by preserving ID/name/content/order and deriving their
  legacy suffix once, including compound suffixes after `Untitled.`.
- Both Finder and the creation panel choose exact template IDs, with localized
  name and suffix visible. Search matches template names and suffixes.
- A user may choose one enabled default template for each suffix. Without a valid
  default, use the first enabled template by saved rank, then stable ID. Removing,
  disabling or changing a template's suffix invalidates its old default reference.
- Explicit template selection wins. Entering a complete name with the same suffix
  retains the selected template; changing suffix selects its default. Unsaved name
  and content edits survive same-format template switches. Unedited fields adopt
  the selected template's defaults; an explicit format change updates the suffix.
- Template changes, defaults and removal persist atomically; a failed save keeps
  the prior saved template configuration. Built-in restoration preserves custom
  templates and valid defaults. New preferences add no arbitrary defaults.

## Office document templates

- Templates & Types offers New Text Template and Import Document Template. The
  native file picker accepts one regular .docx or .xlsx; folders, symlinks,
  cloud placeholders and macro-enabled formats are excluded. Read only the
  selected file while holding its picker grant, on a background worker.
- Validate the actual ZIP/Office package before saving: bounded directory and
  entry ranges, stored/deflated entries, CRC integrity, valid required XML and
  the matching non-macro main content type/relationship. Never extract paths,
  resolve XML external entities, run scripts/macros or launch an Office app.
- First-version limits: 64 MiB encoded, 4,096 ZIP entries, 64 MiB per expanded
  entry and 128 MiB total expanded bytes. Reject encrypted, split and ZIP64
  packages, malformed XML, missing primary parts and inconsistent formats.
- Store an independent private copy in FileMint's application-owned template
  directory. Preferences hold a UUID, format, byte count and SHA-256 digest;
  no bookmark or original source path is needed after import. Old templates
  without an asset reference remain UTF-8 text templates.
- Imported templates use the selected document name initially. Users may edit
  the template display name and default filename, enable/order/default/remove it.
  Its format and contents are preserved; there is no embedded Office editor.
- Saving preferences after import is atomic. Failure removes only that new
  owned asset; removing a template deletes its asset only after configuration
  saved successfully and no remaining template references it. Never scan for
  or bulk-delete template files. Missing/damaged assets remain visible so the
  user can remove and re-import the document.
- Creation validates the stored regular file, size and digest, then publishes
  exact bytes as an independent file with no overwrite. Originals and template
  copies remain unchanged; unavailable assets create no output and give an
  actionable re-import message. Ordinary file associations are unchanged.

## Working context

- Implementation entry points: `CorePackage/Sources/FileMintCore/FileTemplate.swift`, `DocumentTemplateStore.swift`, `OfficeDocumentValidator.swift`, `TemplateRenderer.swift`, `CustomFileDraft.swift`; type editing in `App/FileMint/TypesPane.swift` and `PreferencesModel.swift`.
- Verification: [Core checks](../verification/core.md); native type editing in [Finder QA](../../docs/FINDER_QA.md#types-and-preferences).
- Expand context only when needed: Load [creation](creation.md) for filename, suffix, token or content semantics; [startup](startup.md) if unrelated saved preferences or migration defaults are affected.
