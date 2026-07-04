# FileMint SPEC

## Product Promise

FileMint lets macOS users create common files from Finder's native right-click menu with minimal friction.

The experience should feel like a small missing Finder feature, not a separate productivity suite.

## Product Presentation

The repository README is a product introduction entry first and an engineering
reference second.

- Chinese is the default README language.
- English is available from the top-level `中文 | English` switch.
- Engineering setup, harness, and distribution details may appear after the
  product overview, but should not be the first impression.

## Name

The product name is **FileMint**.

Rationale: short, memorable, English-friendly for GitHub distribution, and expressive of "minting" a fresh file.

## Branding And Icons

FileMint ships with one coherent icon family across visible macOS entry points.

- Dock, Finder, app bundle, and extension entries use the generated `AppIcon`
  asset catalog.
- Top menu bar status entry points use a simplified generated `MenuBarIcon`
  template asset.
- Editable source icon files live under `Resources/IconSource`.
- Generated app and menu bar icon assets live under
  `Resources/Assets.xcassets`.
- After changing an icon source file, run `make icon` to rebuild generated icon
  assets.

## License

FileMint is source-available for non-commercial use.

- Users may fork and modify the code for personal, educational, research, or
  other non-commercial purposes.
- Commercial use, commercial redistribution, commercial hosting, and commercial
  derivative products require separate written permission.
- The project must not use a permissive license that allows unrestricted
  commercial derivative work by default.

## Technical Base

- Native macOS app.
- Swift-first implementation.
- SwiftUI for settings UI where it gives native controls quickly.
- AppKit/FinderSync for Finder integration.
- No Electron, React Native, Flutter, Tauri, or other multi-platform runtime.
- Distribution target: Developer ID signed `.app` packaged into `.dmg` for GitHub releases.

## Finder Integration

FileMint uses a Finder Sync extension.

Important Apple constraint: Finder Sync extensions work against registered monitored folders. FileMint therefore exposes monitored locations in settings and defaults to common user folders.

Expected menu behavior:

- Right-click Finder folder background inside a monitored location.
- Show `New File` submenu.
- Create the selected template in the current folder.
- If a file already exists, use a predictable incrementing name.
- Optionally reveal/select the created file after creation.

MVP monitored locations:

- Desktop
- Documents
- Downloads

Future monitored location options:

- Add custom folder.
- Remove custom folder.
- Enable broader Home-folder coverage with an explicit performance note.

## Core Features

### Templates

Built-in templates:

- Plain Text: `Untitled.txt`
- Markdown: `Untitled.md`
- Swift: `Untitled.swift`
- JSON: `Untitled.json`
- HTML: `Untitled.html`
- CSS: `Untitled.css`
- Shell Script: `Untitled.sh`

Template rules:

- Templates have stable IDs.
- Templates can be enabled or disabled.
- Templates have a menu rank.
- Template contents may use simple placeholders.

Supported placeholders:

- `{{fileName}}`
- `{{date}}`
- `{{isoDate}}`
- `{{year}}`

### Naming

Default strategy is safe auto-increment:

- `Untitled.txt`
- `Untitled 2.txt`
- `Untitled 3.txt`

No silent overwrite in MVP.

Invalid path separators are sanitized before writing.

### Settings

Settings should be compact and operational:

- Extension status and quick action to open macOS extension settings.
- Finder permission setup guidance that tells users where to enable the Finder
  Sync extension, which folders are monitored by default, and when to relaunch
  Finder after changing extension permissions.
- Monitored locations.
- Template enablement and ordering.
- Collision behavior.
- Reveal after creation.
- App language switching between English and Chinese, with English as the
  default language.

Do not add dashboards, decorative cards, themes, or onboarding tours unless a later SPEC explicitly asks for them.

Language behavior:

- The app stores a language preference in shared preferences so the main app,
  menu bar commands, and Finder Sync menu labels use the same language.
- English is the default for new installs and for older saved preferences that
  do not yet contain a language field.
- Built-in UI labels, Finder menu labels, permission guidance, and built-in
  template display names are localized.
- File naming remains stable across languages; built-in suggested filenames
  stay English, for example `Untitled.txt`.

### Premium-Inspired Ideas To Keep In Scope

Borrowed from common paid file-manager/new-file utilities, but reduced to useful essentials:

- Favorite templates at top of menu.
- Custom templates.
- Create from existing file as template.
- Hotkey for "create most-used template".
- Recent destination memory.
- Per-folder preferred template.

These are not MVP unless a Harness case is added.

## Non-Goals

- Replacing Finder.
- Building a dual-pane file manager.
- Cloud sync.
- AI file generation.
- Heavy visual customization.
- Cross-platform support.

## UX Principles

- Native first.
- One menu level for common actions.
- Predictable names.
- No destructive overwrite defaults.
- Settings are for behavior, not decoration.
- Failures should be explainable in one sentence.

## AI Development Contract

Every behavior change should follow this order:

1. Update `specs/SPEC.md` if product behavior changes.
2. Add or update a Harness case in `specs/harness/cases`.
3. Implement core logic in `CorePackage`.
4. Connect UI or Finder extension only after core behavior passes.
5. Run `make verify`.
