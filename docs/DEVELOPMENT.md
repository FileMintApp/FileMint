# Development

Use full Xcode with Swift 6 on an M-series Mac, Python 3.9+ for context/CLI
checks, and XcodeGen (`brew install xcodegen`).

```sh
make verify
make project
make build
make icon
make package
```

`make verify` runs context-document checks, unit tests, the public JSON harness
and real CLI regression via `make verify-harness-cli`. The CLI checks build a fresh
executable and verify both passing and deliberately failing inputs; no third-party
test runner is needed. The current [Harness format](../specs/verification/core.md)
and `HarnessSuite.load` are the only supported input/Swift entry points.
`make build` generates FileMint.xcodeproj from project.yml and compiles the arm64
app and its embedded Finder extension into `FileMint.bundle`. This
bundle target also applies to Debug and direct Xcode builds and skips Xcode's
application registration step. `make package` uses the version in project.yml,
removes Intel slices from embedded Sparkle executables, signs the bundle ad hoc
by default, and produces local DMG and ZIP archives with checksums.
For a public release, follow [Distribution](DISTRIBUTION.md).
Outputs are under build/ and ignored by Git.

Website development and CI use Node 26.x. CI resolves the newest stable patch
with `check-latest: true`; keep local development on the same major series.
Use the pnpm version declared in `package.json`, independently of Node's version
or a globally installed package-manager launcher. Website CI installs with the
frozen lockfile and prints both resolved tool versions.

For routine acceptance, select checks from
[HARNESS](../specs/HARNESS.md#default-acceptance). Covered Core behavior uses
automated results; app/extension changes also need unsigned compilation, with
native checks selected only for affected interactions and system boundaries.
Source CI runs both `make verify` and the unsigned app/extension build on its
macOS matrix. Compilation does not require installing or launching the result.

For changed native interactions, plan and run the existing isolated QA fixtures:

```sh
make native-qa-plan
make verify-native-affected
make verify-native-affected NATIVE_QA_BASE=HEAD~1
make verify-native-affected NATIVE_QA_SUITES=batch-rename,file-tools-settings
```

The runner builds signed stable QA apps serially and writes a fresh JSON report
with per-suite logs under `build/native-checks.noindex`. Exit 0 requires successful
automatic checks in the selected scope; an empty plan is reported separately.
Manual boundaries or unknown runtime paths remain blocked. Developer ID keys
stay local, and the offline `make verify` only tests this runner's selection and
failure handling. See [native QA](../specs/verification/native-qa.md#automated-local-checks)
for suite coverage and requirements.

To build, sign and install a local Debug app, run this from the checkout as the
signed-in Mac user with write access to `/Applications`.

```sh
make install-debug
```

The [installer script](../scripts/install_debug.py) generates the project and
uses `ENABLE_DEBUG_DYLIB=NO` so the Debug app has a direct executable. It reuses
the installed app's Developer ID from the local Keychain, or the sole available
Developer ID Application identity on a first install. Set `APPLE_CODESIGN_IDENTITY`
to the full identity name to select a certificate explicitly. Both the app and
Finder extension must continue to satisfy their existing signing requirements.

The run prints its build log and verified rollback ZIP paths under
`build/local-debug-install.noindex/run.*`. Finish pending FileMint work before
installation. If it declines the normal quit, finish that work and run the
command again. After atomic replacement and bundle verification the script
opens `/Applications/FileMint.app` and checks the Finder registration. Finder
extension enablement stays under macOS user control. An enabled registration
and a new extension process establish loading. For menu acceptance, check the
visible menu and follow the computer-use precautions in
[creation window isolation](FINDER_QA.md#creation-window-isolation).

Packaging keeps its build wrapper in an isolated directory under
`build/package-work.noindex` and removes the staging products when it finishes
or fails. The final DMG and ZIP contain `FileMint.app`. Use `make install-debug`
to exercise the production Finder extension from `/Applications/FileMint.app`.

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
Edit `project.yml` to change the generated Xcode project. New dependencies
need a rationale in the owning domain SPEC.

Future feature ideas, implementation starting points and completion criteria
live in the [implementation roadmap](ROADMAP.md). The public TODO lists are
maintained in the `roadmap` regions of both READMEs and included by the website
homepages. After editing them, build the site with
`SITE_BASE=/FileMint/ pnpm run site:build` to verify the GitHub Pages base path.

For downstream fork maintainers, see the [fork synchronization guide](FORK_SYNC.md).
