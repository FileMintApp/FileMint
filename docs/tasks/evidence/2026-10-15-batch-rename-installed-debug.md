# Installed Debug batch rename acceptance

Date: 2026-10-15. Parent: [batch rename task](../2026-10-14-batch-rename.md).

Overall result: **failed at installed Finder intake**. Debug build, signing,
installation and focused automated checks passed. The installed Finder action
could not open the authorization/preview flow; real rename and undo did not run.
No product code was changed during this acceptance.

Follow-up: the same-day [Finder sandbox fix and native acceptance](2026-10-15-batch-rename-finder-fix.md)
resolved this intake failure and records the final installed rename/undo results.
The failure below remains the historical result for the unchanged earlier build.

## Tested source and artifacts

- Primary checkout: `7b3ebea9d48765b6f521d01cd2ba6e79744f8154`.
- Version 0.7.0, build 28; macOS 27.2 (`26B5101f`), arm64;
  Xcode 27.0 (`27A266a`), Swift 6.4.
- Debug build used `/Applications/Xcode.app/Contents/Developer`,
  `ENABLE_DEBUG_DYLIB=NO`, `CODE_SIGNING_ALLOWED=NO`, and
  `CODE_SIGNING_REQUIRED=NO`; project generated with `make project`.
- Signed using the existing Developer ID team `8S66M2ZLD5`, retaining production
  sandbox entitlements, then installed at `/Applications/FileMint.app` after a
  normal main-app quit and a verified ZIP backup of the previous app.
- Local Debug ZIP: `build/FileMint-Debug-7b3ebea.zip`, SHA-256
  `5a4750ed6503cc0880ef1b01bd636d419b5a6de309bd483cddb2d6a006e95f71`.
  This is a local Debug artifact; no notarization or publication ran.

Logs and the previous app backup are retained in the ignored directory
`.local/verification/debug-batch-rename-20261015.ru3XKo/`.

## Observed checks

| Check | Result | Evidence / boundary |
| --- | --- | --- |
| Debug App and Finder build | passed | `debug-build.log`; direct executable, without `FileMint.debug.dylib` |
| `swift test --package-path CorePackage --filter 'BatchRename\|RenameName'` | passed | `rename-tests.log`; 83 tests / 5 suites |
| Developer ID signing and bundle verification | passed | `sign.log`, `bundle-before-install.log`, `installed-bundle.log`, `installed-bundle-final.log`; nested signatures, app/Finder sandbox entitlements, Sparkle services, arm64 and compression runtime checks |
| Installed versus built and archived executables | passed | `installed-source-identity.json`; exact SHA-256 equality for App and Finder executables |
| Existing Finder extension reload | passed | Existing on switch refreshed off/on through visible System Settings; `extension-registration.log` identifies the installed extension, enabled |
| Default-off setting and independent submenu placement | passed | Installed settings initially showed batch rename off with its placement disabled; enabling exposed its default tools-submenu placement |
| Finder entry in ordinary configured local scope | passed | Four synthetic files/folder selected in `/private/tmp/FileMint-Demo/batch-rename-20261015.v_edz11h/01-rules`; actual File & Folder Tools submenu contained Batch Rename |
| Finder click to authorization / preview | **failed** | Native extension alert and matching kernel sandbox denials, described below |
| Installed preview, commit, conflict UI, cancellation, recovery and undo | blocked | Intake failed before reaching the main-app panel; focused Core tests do not replace this installed evidence |
| Fixture preservation | passed | `fixture-readback.json`; all 16 synthetic file identities and SHA-256 hashes, plus the symlink target, unchanged; no production batch-rename store created |
| Full `make verify`, old macOS, case-sensitive APFS, VoiceOver, NAS / iCloud / sync compatibility | not-run | Outside this focused installed acceptance; previous fixture/offline results remain historical |

The ordinary repository test location under Documents initially showed no FileMint
context-menu entries. The fixture was moved into an already configured ordinary
local temporary scope, where the actual menu appeared. No callback instrumentation
was added, so this observation alone does not identify why the Documents menu was
absent or validate those locations.

## Blocking defect

Clicking the actual Finder action displayed this alert owned by
`FileMint Finder Extension`:

> 批量重命名… 无法准备所选项目。请检查所有项目及所在文件夹是否可用，以及是否具有访问权限。

`finder-sandbox-denials.log` contains matching failures at 15:09:50, 15:14:17,
15:18:06 and 15:19:12 for the installed extension processes, denying
`file-read-data` on the synthetic `01-rules` parent directory.

The current call path explains the failure:

1. `FinderSync.swift:469` calls `BatchRenameSelection.capture` inside the extension,
   before ticket enqueue at line 470 or main-app delivery at line 472.
2. `BatchRenameNative.swift:65` opens that parent using `RenameDirectory`;
   line 90 uses `O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC`.
3. The native exact-parent authorization belongs to the main app and is reached
   later, at `BatchRenameOperations.swift:67`. This observed request cannot reach
   that picker because the earlier extension-side directory read is denied.

The fix must preserve click-time complete-selection/identity ownership and
main-app exact-parent authorization, without broadening entitlements, disabling
the sandbox, scanning folders, or weakening mutation-time identity checks. A
subsequent signed installed-Finder regression is required; the current successful
Core tests and isolated fixture do not cover this extension sandbox boundary.

Computer Use repeatedly reported changed UI state while native menus were open.
The extension alert was identified using its exact installed `.appex` path; its
accessibility text was readable, while its screenshot was blank. No screenshot
is claimed as visual proof of that alert.

## State preservation

- Only synthetic fixtures were used; initial/final fixture manifests are retained.
- Only exact development App/extension registrations were removed; the installed
  extension remained enabled. No Finder restart, global registration reset,
  privacy-database modification or permission broadening was performed by the agent.
- A temporary feature-on change was made for acceptance. During teardown, an
  attempted off change did not match saved readback; newer scope/bookmark changes
  also appeared. The latest saved preferences were preserved instead of restoring
  the initial backup over concurrent changes. Final saved batch rename was on;
  `preferences-readback.json` records the changed fields without bookmark bytes.
- No production rename record or receipt was created. The previous installed app
  remains recoverable from `FileMint-before-install.zip` in the log directory.

Next: fix the pre-authorization Finder capture path, add appropriate sandbox
regression coverage, rebuild/sign/install, then repeat the full native rename and
undo flow. This acceptance record does not authorize publication.
