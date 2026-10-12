# Development

Use full Xcode with Swift 6 on an M-series Mac, Python 3.9+ for context/CLI
checks, and XcodeGen (`brew install xcodegen`).

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
`make build` generates FileMint.xcodeproj from project.yml and builds the app and
Finder extension for arm64. `make package` removes Intel slices from embedded
Sparkle executables, adds ad-hoc bundle signatures, checks arm64-only contents
and creates the DMG.
Outputs are under build/ and ignored by Git.

For an explicitly requested installed Debug check, generate the project and use
the Debug configuration with a direct executable:

```sh
make project
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project FileMint.xcodeproj -scheme FileMint -configuration Debug \
  -derivedDataPath build/DebugDerivedData \
  -clonedSourcePackagesDirPath build/SourcePackages \
  ENABLE_DEBUG_DYLIB=NO CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

`ENABLE_DEBUG_DYLIB=NO` retains Debug compilation while avoiding Xcode's
separate debug-library launcher, which the distribution executable checks do not
support. Before installation, sign the resulting
`build/DebugDerivedData/Build/Products/Debug/FileMint.app` with the existing local
Developer ID using `scripts/sign_app.sh`, then check it with
`scripts/verify_bundle.sh`. Keep the production sandbox and signing identity.
Back up the previous installed app, quit it normally, replace only its bundle,
and verify the installed copy. Installation is a separate requested operation;
these commands neither install nor publish. Follow the computer-use precautions
in [creation window isolation](FINDER_QA.md#creation-window-isolation).
If an already enabled extension does not reload after bundle replacement,
check the actual process and visible menu. Refresh its existing switch through
macOS extension management and restore its original state; an enabled-status
label alone is not proof of a running extension. Do not reset system databases
or silently enable an extension with `pluginkit`.

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
