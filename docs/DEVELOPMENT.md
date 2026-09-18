# Development

Use full Xcode with Swift 6, Python 3.9+ for context/CLI checks, and XcodeGen
(`brew install xcodegen`).

```sh
make verify
make project
make build
make icon
APP_VERSION=0.5.1 make package
```

`make verify` runs context-document checks, unit tests, the public JSON harness
and real CLI regression via `make verify-harness-cli`. The CLI checks build a fresh
executable and verify both passing and deliberately failing inputs; no third-party
test runner is needed. The current [Harness format](../specs/verification/core.md)
and `HarnessSuite.load` are the only supported input/Swift entry points.
`make build` generates FileMint.xcodeproj from project.yml and builds arm64 + x86_64. `make package`
adds ad-hoc bundle signatures, checks both architectures and creates the DMG.
Outputs are under build/ and ignored by Git.

Packaging uses an isolated temporary directory under `build/package-work.noindex`
and removes its app/extension registrations and build products when it finishes
or fails. The final DMG and checksum remain in `build/`. `make build` still keeps
its runnable app in `build/DerivedData`; avoid leaving that development app
registered alongside an installed release with the same bundle identifiers.

For updater changes, select the applicable checks from the
[update verification guide](../specs/verification/updates.md). Client changes need
`make verify-updates`; save/download/open changes also need the interactive
`make update-sandbox-harness` flow. A non-sandboxed CLI download can pass checksums
while the installed sandboxed app produces an installer macOS refuses to execute.

- CorePackage: deterministic naming, templates, preferences and file writes.
- SharedUI: native creation panel and sandbox folder access.
- App/FileMint: SwiftUI settings and application entry points.
- FinderSyncExtension: Finder integration, context menus and extension status.

Start with the compact [SPEC router](../specs/SPEC.md), then load only contracts
for the changed behavior and paths. Read [HARNESS](../specs/HARNESS.md) when
selecting checks; do not preload all domain docs or historical acceptance records.
Use the [AI Playbook](AI_PLAYBOOK.md) for cross-domain features or session handoff.
Do not edit the generated Xcode project. No runtime package dependencies.

Future feature ideas, implementation starting points and completion criteria
live in the [implementation roadmap](ROADMAP.md). The public TODO lists are
maintained in the `roadmap` regions of both READMEs and included by the website
homepages. After editing them, build the site with
`SITE_BASE=/FileMint/ pnpm run site:build` to verify the GitHub Pages base path.

For downstream fork maintainers, see the [fork synchronization guide](FORK_SYNC.md).
