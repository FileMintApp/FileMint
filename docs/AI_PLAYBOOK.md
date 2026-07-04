# AI Playbook

Use this project in SPEC-first order.

## Before Editing

1. Read `specs/SPEC.md`.
2. Read `specs/HARNESS.md`.
3. Run `make doctor` when validating the local machine.
4. Run `make verify`.

## Adding A Feature

1. Add product behavior to SPEC.
2. Add a Harness case if the behavior touches file creation, naming, templates, or settings persistence.
3. Implement in `CorePackage`.
4. Wire the App or Finder extension.
5. Run `make verify`.

## Generated Project And Assets

- Edit `project.yml`; do not edit `FileMint.xcodeproj` directly.
- Regenerate the Xcode project with `make project`.
- Regenerate app icons with `make icon` after changing `scripts/generate_app_icon.swift`.

## Boundaries

- Keep Finder-specific API usage in `FinderSyncExtension`.
- Keep SwiftUI views in `App/FileMint`.
- Keep deterministic logic in `CorePackage`.
- Do not add package dependencies unless the SPEC explains why.
- Prefer small stable structs over hidden global state.

## Manual Finder QA

Headless tests cannot prove Finder menus are visible.

Manual QA checklist:

1. Build and install `FileMint.app`.
2. Enable the Finder Sync extension in macOS settings.
3. Open Desktop in Finder.
4. Right-click the folder background.
5. Choose `New File -> Text`.
6. Confirm `Untitled.txt` appears.
7. Repeat and confirm `Untitled 2.txt` appears.
