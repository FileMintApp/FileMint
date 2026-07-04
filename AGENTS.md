# FileMint Agent Guide

Use the project in SPEC-first order.

1. Read `specs/SPEC.md`.
2. Read `specs/HARNESS.md`.
3. Run `make verify` before changing behavior when the local Swift toolchain is available.
4. Update SPEC first when product behavior changes.
5. Add or update harness/unit coverage for naming, templates, creation, or preferences behavior.
6. Keep deterministic behavior in `CorePackage`.
7. Keep Finder API usage in `FinderSyncExtension`.
8. Keep SwiftUI settings code in `App/FileMint`.
9. Run `make verify` after implementation.

Do not edit generated `FileMint.xcodeproj` directly. Edit `project.yml`, then run `make project`.
