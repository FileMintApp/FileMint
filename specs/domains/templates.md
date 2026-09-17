# File types and templates

Load for: Preset/custom types, ordering, restoration, migration and template rendering.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## File types

- Presets: txt, md, swift, json, html, css, sh, csv, yaml, xml, js, ts, py, sql.
  The original seven are visible by default; additional presets can be enabled.
- Settings → File Types can add/edit/remove saved custom types, including a
  display name, suffix and optional initial template content. Duplicate suffixes
  are rejected case-insensitively. Changes persist and refresh Finder without
  restarting the app. Enabled types are shared by quick actions and the picker.
- Users can enable/disable and reorder types. Built-in templates have stable IDs.
  Restoring built-ins preserves custom types and requires a confirmation.
- Older preferences retain language, folder selection, template customizations,
  enabled state and order; newly added presets are appended disabled.
- Do not expose nonfunctional favorites, icon toggles, themes or dashboards.

## Working context

- Implementation entry points: `CorePackage/Sources/FileMintCore/FileTemplate.swift`, `TemplateRenderer.swift`, `CustomFileDraft.swift`; type editing in `App/FileMint/ContentView.swift` and `PreferencesModel.swift`.
- Verification: [Core checks](../verification/core.md); native type editing in [Finder QA](../../docs/FINDER_QA.md#types-and-preferences).
- Expand context only when needed: Load [creation](creation.md) for filename, suffix, token or content semantics; [startup](startup.md) if unrelated saved preferences or migration defaults are affected.
