# Development

Use full Xcode with Swift 6 and install XcodeGen (`brew install xcodegen`).

```sh
make verify
make project
make build
make icon
APP_VERSION=0.5.1 make package
```

`make verify` runs unit tests plus the public JSON harness. `make build` generates
FileMint.xcodeproj from project.yml and builds arm64 + x86_64. `make package`
adds ad-hoc bundle signatures, checks both architectures and creates the DMG.
Outputs are under build/ and ignored by Git.

Packaging uses an isolated temporary directory under `build/package-work.noindex`
and removes its app/extension registrations and build products when it finishes
or fails. The final DMG and checksum remain in `build/`. `make build` still keeps
its runnable app in `build/DerivedData`; avoid leaving that development app
registered alongside an installed release with the same bundle identifiers.

For updater changes, also run `make verify-updates` and the interactive
`make update-sandbox-harness` flow in `specs/HARNESS.md`. A non-sandboxed CLI
download can pass checksums while the installed sandboxed app produces an
installer macOS refuses to execute.

- CorePackage: deterministic naming, templates, preferences and file writes.
- SharedUI: native creation panel and sandbox folder access.
- App/FileMint: SwiftUI settings and application entry points.
- FinderSyncExtension: Finder integration, context menus and extension status.

Read [SPEC](../specs/SPEC.md) and [HARNESS](../specs/HARNESS.md) before changes.
Do not edit the generated Xcode project. No runtime package dependencies.
