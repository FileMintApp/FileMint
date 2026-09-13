# Development

Use full Xcode with Swift 6 and install XcodeGen (`brew install xcodegen`).

```sh
make verify
make project
make build
make icon
APP_VERSION=0.3.0 make package
```

`make verify` runs unit tests plus the public JSON harness. `make build` generates
FileMint.xcodeproj from project.yml and builds arm64 + x86_64. `make package`
adds ad-hoc bundle signatures, checks both architectures and creates the DMG.
Outputs are under build/ and ignored by Git.

- CorePackage: deterministic naming, templates, preferences and file writes.
- SharedUI: native creation panel and sandbox folder access.
- App/FileMint: SwiftUI settings and application entry points.
- FinderSyncExtension: Finder integration, context menus and extension status.

Read [SPEC](../specs/SPEC.md) and [HARNESS](../specs/HARNESS.md) before changes.
Do not edit the generated Xcode project. No runtime package dependencies.
