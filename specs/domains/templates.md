# File types and templates

Load for: Preset/custom types, ordering, restoration, migration and template rendering.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## File types

- Presets: txt, md, swift, json, html, css, sh, csv, yaml, xml, js, ts, py, sql,
  plus blank Word (.docx) and Excel (.xlsx) documents. The original seven text
  presets and the two Office presets are enabled on new installs; the other
  text presets can be enabled. Existing installations append new presets disabled.
- Settings → File Types can add/edit/remove saved custom types, including a
  display name, suffix, default filename and optional initial template content.
  Multiple templates may share a suffix; stable IDs identify templates. Changes persist and refresh Finder without
  restarting the app. Enabled types are shared by quick actions and the picker.
- Users can enable/disable, reorder, edit and remove every type, including built-in
  templates. Built-in templates retain stable IDs when edited. A removed built-in
  stays removed across relaunch and settings import until the user explicitly
  restores built-ins. Restoring built-ins preserves custom types and requires a
  confirmation. Template selection uses a quiet adaptive mint treatment rather
  than the system's saturated blue list selection; drag reordering still shows
  an exact insertion boundary and a restrained row-settling animation that
  respects Reduce Motion.
- Older preferences retain language, folder selection, template customizations,
  enabled state and order; newly added presets are appended disabled.
- Do not expose nonfunctional favorites, icon toggles, themes or dashboards.
- Every saved type has a default SF Symbol based on its file suffix (a generic
  document symbol for unknown suffixes), visible in Templates & Types and the
  Finder New File choices. The type editor can select another available system
  symbol and primary/secondary colors or reset to the suffix default. A custom
  icon belongs to the stable template ID, persists with built-in and user types,
  and survives ordinary edits, ordering and settings import. Changing a suffix
  recomputes only an uncustomized default. Restoring built-ins restores their
  default icons while retaining custom types and their chosen icons.

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

- FileMint bundles an empty Word document and an Excel workbook with one empty
  worksheet. They have stable template and versioned asset identities, contain
  no personal metadata, and work offline without an Office installation or import.
  They use the same selection, naming, collision and editing rules as imported
  documents. They can be renamed, enabled, reordered, chosen as a suffix default
  or removed; explicit built-in restoration restores them and preserves custom
  templates and valid defaults. Upgrade never replaces a saved customization or
  revives a removed built-in.
- Bundled document references are distinct from managed imports and resolve only
  to known read-only package resources. Verify their format, byte count and
  digest before creation. Removing a bundled template changes preferences only,
  never deletes an asset or creates a private imported copy. Missing or damaged
  bundled resources produce no output and advise restoring built-ins or
  reinstalling FileMint; imported-asset errors retain their re-import guidance.
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
- Store an independent private copy of imported documents in FileMint's application-owned template
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

## Copy, preview and template exchange

- Copy opens an unsaved complete draft with a new custom identity and localized
  Copy suffix. Save enables and inserts it after the source (or appends if the
  source disappeared); Cancel changes nothing. Preserve icons, group, suffix,
  content, action and immutable Office reference. Preserve explicit defaults; if
  copying an earlier disabled source would change an implicit default, pin the
  previous effective default. Copies survive restoration;
  delete managed assets only after their last saved reference is removed.
- Template Preview is an independent local default-off gate. When off, remove
  preview controls and perform no preview work. When on, text previews display
  exact resolved UTF-8 with a labelled fixed UTC example; Office previews use
  native Quick Look with one validated, private read-only snapshot per surface.
  Selection changes, disable and close cancel work and remove owned snapshots.
  Distinguish unavailable providers from invalid assets; neither edits originals.
- Each template owns none, revealInFinder, openWithDefaultApp or
  openWithApplication. Selected apps use a separate validated local registry or
  an inert portable hint. Hidden controls must round-trip these fields. Built-in
  restoration resets only built-ins to the current basic reveal preference.
- `.filemint-templates` version 1 is a stored-entry ZIP with strict manifest.json
  (format=filemint.templates, schemaVersion=1, templates, payloads,
  defaultTemplateIDs) and digest-named payloads. Array order is relative order;
  include exact UTF-8/Office bytes, metadata, enabled state and portable action
  hints. Exclude local registry/asset IDs, paths, bookmarks, gates and preferences.
- Limits: 100 templates/payloads, 64 Office payloads, 4 MiB manifest, 8 MiB total
  text, 128 MiB archive/outer payload, 256 MiB combined Office expansion; retain
  each Office validator limit and 32 MiB settings cap. Reject unknown/duplicate
  keys, invalid references/digests, invalid UTF-8/Office, unreferenced entries,
  encrypted/split/ZIP64/deflated outer entries, links, unsafe names, overlapping
  ranges and header/CRC mismatches before any managed mutation. Never extract.
- Required import review offers Add, Skip or Save as copy, never replacement.
  Identical portable fields/content skip; changed ID/name conflicts copy. Suffix
  alone is no conflict. Reserved/used identities remap; copies receive unique
  localized names. Preserve local order/defaults/tombstones and append accepted
  entries. Optional default adoption fills only suffixes without valid explicit
  defaults and reviews effective changes; all-skipped imports change nothing.
- Validate a bounded immutable input snapshot, bind review to saved settings,
  and require renewed review if they changed. Journal fresh asset IDs before
  exclusive publication, atomically save one merged configuration plus transaction
  marker, then notify once. Roll back only transaction-owned assets. Recovery
  reads exact journal entries, retains referenced assets and preserves corrupt or
  replaced evidence; never scans. Block template mutations during commit/recovery.
- Export selected/enabled/all/custom scopes through a native save panel, validating
  complete bytes on a worker before atomic publication. Cancel/failure preserves
  existing destination bytes. Packages never enable features or discover/open apps.

## Working context

- Implementation entry points: `CorePackage/Sources/FileMintCore/FileTemplate.swift`, `DocumentTemplateStore.swift`, `OfficeDocumentValidator.swift`, `TemplateRenderer.swift`, `CustomFileDraft.swift`; type editing in `App/FileMint/TypesPane.swift` and `PreferencesModel.swift`.
- Verification: [Core checks](../verification/core.md); native type editing in [Finder QA](../../docs/FINDER_QA.md#types-and-preferences).
- Expand context only when needed: Load [creation](creation.md) for filename, suffix, token or content semantics; [startup](startup.md) if unrelated saved preferences or migration defaults are affected.
