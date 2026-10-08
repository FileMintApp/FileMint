# FileMint 0.5 acceptance

Checked on 2026-09-14, macOS 26.6.2, Apple silicon. Minimum deployment target:
macOS 13. Release bundles contain arm64 and x86_64 executables.

## Configured and default post-creation applications — 2026-10-08

Tested primary checkout `main`, base `e0ba136` plus these uncommitted changes,
on macOS 27.2 arm64 / Xcode 27.0.

- [The chain review](tasks/2026-10-08-creation-opening.md) covers saved template
  actions, quick tickets, the creation panel, dispatch and retry. Explicit apps
  retain bookmark/bundle validation; system-default opening directly uses the
  macOS API. Neither route has a FileMint editor, publisher or content-type
  allowlist. Recovery distinguishes unavailable apps and native opening failures.
- **Passed:** `make verify` (220 Core tests, 14 image tests, 5 public Harness
  cases, 10 CLI regressions and offline release checks), plus
  `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build`.
  [Verification log](../build/opening-chain-2026-10-08.f4gv9s80.noindex/verify.log),
  [build log](../build/opening-chain-2026-10-08.f4gv9s80.noindex/build.log).
- **Passed:** real native explicit/default receipt delivery, 12 isolated
  quick/panel and selected/default combinations for JS/DOCX/XLSX, 6 collision
  receipts, temporary override, cancel, pending-work, failure and retry checks.
  A temporary fixture-specific system association is removed after the check;
  existing file associations are unchanged.
  [Native log](../build/opening-chain-2026-10-08.f4gv9s80.noindex/native.log).
- **Passed:** actual VS Code 1.141.0 displayed panel/quick JS tabs and the test
  code; WPS 12.1.26050 was launched for DOCX and reused for XLSX, displaying a
  blank Word page and Sheet1 without a repair prompt. System-default TXT opened
  in TextEdit 1.21 with the expected marker. Live CUA observations supplement
  [native callbacks](../build/opening-chain-2026-10-08.f4gv9s80.noindex/installed-apps.log).
  Test documents were closed without editing user documents.
- Installed Finder entry points and macOS 13 were **not run**. Real FileMint
  preferences and installed apps were unchanged; no release was installed or
  published, and arbitrary third-party format compatibility is not claimed.

## FileMint 0.6.7 release — 2026-10-08

The arm64/macOS 13+ [0.6.7 release](tasks/release-0.6.7.md), build 26, was built
from `747527192053d9465dd08c6b6e2fc8717b1d517c` on macOS 27.2 arm64 / Xcode 27.0.
Standard checks passed 220 Core tests, 14 image tests, 5 public Harness cases,
10 CLI regressions and offline release checks. The production-model native
fixture passed copied compound-suffix output and automatic-check deferral for
native sheets/modal windows, one-shot resumption, disabling, manual checks and
cancellation, using temporary settings and injected metadata.

Developer ID signatures, embedded entitlements, arm64-only code, production
Sparkle-driver checks, accepted Apple notarization, DMG stapling and signed
appcast validation passed. Both hosts contain exact source Office resources;
the main app declares the template-package type. Published DMG, checksum and
appcast matched local bytes. Published-release verification, release-source CI
and website deployment passed. The task records submission ID, hashes and runs.

No installed FileMint was replaced. Installed Finder, macOS 13, managed devices,
complete keyboard/VoiceOver/appearance coverage and public-feed installation
remain unverified. Earlier unavailable Office providers and rejected installed
VS Code signatures are not converted into native acceptance by these checks.

## Template import memory bound — 2026-10-08

Tested primary checkout `main`, base `fa90604` plus these uncommitted fixes,
on macOS 27.2 arm64 / Xcode 27.0.

- Import planning budgets every accepted text reference before materializing
  incoming bodies. Bounded UTF-8 chunks use the persistence encoder's escaping;
  the final budget includes existing settings, metadata and the transaction marker.
  Shared bodies decode once, and skipped rows consume no text budget.
- Four regression tests passed: escaping and UTF-8 chunk boundaries, repeated
  payload limits with unchanged stored bytes, skip/copy and successful commit,
  escaped-text expansion, and cancellation. `make verify` passed 220 Core tests,
  14 image tests, 5/5 public cases, 10 CLI regressions and offline release checks.
  The initial standard run was blocked by SwiftPM's `sandbox-exec` permission;
  the authorized retry passed. [Verification log](../build/pre-release-review-2026-10-08.noindex/verify-fix-retry.log).
- The same [isolated probe](../build/pre-release-review-2026-10-08.noindex/ImportLimitProbe.swift)
  used an archive of 547,577 bytes with 80 references to one 512 KiB text payload.
  Peak process RSS fell from 207,716,352 bytes to 13,352,960 bytes (about 198 MiB
  to 12.7 MiB); both runs rejected the oversized plan and preserved settings bytes.
  [Before](../build/pre-release-review-2026-10-08.noindex/import-limit-80.log),
  [after](../build/pre-release-review-2026-10-08.noindex/import-limit-80-fixed.log).
- These are Core and isolated resource-limit results. Installed Finder, native UI,
  macOS 13, signed updates and publication were not exercised; real preferences
  and installed applications were unchanged.

## Pre-release review fixes — 2026-10-05

Tested primary checkout `main`, base `eee6e24` plus these uncommitted fixes,
on macOS 27.2 arm64 / Xcode 27.0. Existing product contracts are unchanged.

- A present malformed template array now enters settings recovery instead of
  replacing the saved list with defaults. Regression cases cover a damaged
  record, null and an invalid container, blocked ordinary writes, preserved
  original bytes, and explicit recovery with an intact backup. Existing missing
  field migration and tolerant optional action/icon decoding still pass.
- Copies carry their original compound suffix through saving and editor preview.
  The production-model fixture changes `Untitled.d.ts` to Markdown, reloads the
  saved template and creates `Untitled.md` with the expected resolved content;
  the source template stays unchanged.
- Automatic checks defer both scheduling and execution while a native sheet or
  app-modal dialog is active. Native presentation events resume a one-shot timer.
  The fixture verifies unchanged preferences/import revisions, a sheet opened
  after scheduling, app-modal order-out, single resumption, disabling deferred
  work, explicit checks while automatic checks are off, and cancellation of an
  in-flight check. Only its startup delay and metadata transport are injected.
- `make verify` passed: 216 Core tests, 14 image tests, 5/5 public JSON cases,
  10 CLI regressions and offline release/signing checks. The final unsigned
  `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` passed, as did
  `make verify-context` and `git diff --check`.
- `bash scripts/build_template_workflow_harness.sh` followed by the fixture
  executable with `FILEMINT_TEMPLATE_QA_MODE=review-fixes` passed. Evidence is
  in `build/pre-release-fixes.noindex/{verify,build,native-build,native}.log`.
  The unchanged Quick Look callback API still has an async-alternative warning.
- These are Core/build and isolated native scheduling results. Installed Finder,
  macOS 13 runtime, public networking, signed update installation, notarization
  and publication were not exercised. No installed app or real preferences were
  modified, and version/build metadata was not advanced.

## Commit 51e49db QA — 2026-10-05

- Revalidated exact commit `51e49db28dd0e342b5c84f40bf86b4ecb5af46af` on
  macOS 27.2 arm64 / Swift 6.4: 214 Core tests, 14 image tests, 5/5 JSON cases,
  10 CLI regressions, offline release checks and unsigned app/extension build passed.
- Live isolated UI verified copy cancel/save, fixed-UTC text preview, exact UTF-8
  creation and actual TextEdit content, plus native template-package export and
  duplicate-review Save as copy import with unchanged existing rows/defaults/gates.
- The user-requested icon follow-up displays the selected application icon/name
  in template editing and creation, including temporary choices. Its build,
  regression fixture and live saved/temporary selection checks passed.
- Office providers still return unavailable and installed VS Code fails strict
  signing validation. Installed signed Finder, macOS 13, complete accessibility/
  appearance coverage and quit/updater lifecycle remain unverified. Real FileMint
  preferences were unchanged; no installed-app replacement or publication.
- Commands, logs, readbacks and precise limits are in the
  [commit QA record](tasks/2026-10-05-template-workflow.md#commit-qa-and-selected-application-icons--2026-10-05).

## Template workflow — 2026-10-05 (isolated source verification)

Primary checkout `main`, base `64820a9` plus the uncommitted
[template workflow task](tasks/2026-10-05-template-workflow.md), macOS 27.2 arm64,
Swift 6.4; minimum deployment target 13.0.

- `make verify` passed 210 Core tests, 14 image tests, 5/5 JSON cases, 10 CLI
  regressions and offline release/appcast/entitlement checks. Unsigned main app
  and Finder extension build passed.
- A disposable sandboxed fixture using production model/preview/executor code
  passed gate persistence/failure rollback, copy/reference cleanup, hidden-action
  retention, actual receiver handoff, stale gate/duplicate/replaced-file rejection
  and bounded preview cancellation/cleanup.
- DOCX/XLSX native providers returned unavailable. Metadata fallback and unchanged
  original bytes were observed; native content rendering/offline provider behavior
  remains unverified. TextEdit signing passed. Installed VS Code's sealed
  `workbench.html` is modified, so strict validation rejected its editing profile.
- Bilingual native view-cache renders were collected; incomplete AppKit cached
  rendering and unavailable desktop automation do not establish live keyboard,
  VoiceOver, editor-content or installed Finder acceptance. macOS 13 and quit/
  updater interaction remain not run. No installation or publication occurred.
- Full commands, source digest, logs and remaining acceptance IDs are recorded
  in the task. These results are source/fixture evidence, not a public release.

### Review-fix follow-up — 2026-10-05

- Fixed concurrent preferences/import overwrites, file-grant-only export failure,
  submission of stale failed-review plans, and saveable but unexportable app actions.
- `make verify` passed 214 Core tests, 14 image tests, 5/5 public cases, 10 CLI
  regressions and the existing release checks; unsigned app/extension build passed.
- The production-model fixture reproduced a real settings-limit replan failure:
  the old plan cannot commit, and correcting the choice permits a valid import.
  Busy-save rollback and invalid-app rejection preserve persisted settings.
- A file-only sandbox fixture passed both new export and atomic overwrite with
  sibling writes denied. Interactive Save-panel and installed Finder acceptance
  remain unverified; earlier editor/provider limitations are unchanged.
- Source identity, logs and exact boundaries are in the task's
  [review-fix evidence](tasks/2026-10-05-template-workflow.md#code-review-fixes--2026-10-05).

## Built-in blank Office templates — 2026-10-03

Checked on macOS 27.2, arm64, `85535ff` plus the uncommitted
[built-in Office templates task](tasks/2026-10-03-built-in-office-templates.md).

- `make verify` passed: 191 Core tests, 14 image tests, 5/5 public Harness cases,
  10 CLI regressions and offline release/appcast/entitlement checks. New coverage
  includes initialization, migration, custom defaults, removal/restoration,
  exact-byte creation and unavailable/tampered bundled resources.
- Unsigned Release main app and Finder extension builds passed. Both contain the
  exact checked-in DOCX/XLSX resources and remain arm64-only. Bilingual site build
  passed. Logs and resource audits are in `build/office-template-qa.noindex/`.
- The isolated native design fixture showed Word and Excel enabled on fresh
  settings. Word display/default filenames were edited and read back; its suffix
  remained fixed. The production creation panel created both formats with
  Cmd-Return, matching bundled bytes and creating no private template copies.
- WPS opened both generated files without a document repair prompt. Edits were
  saved locally and independently read back with python-docx/openpyxl. Excel
  retained one worksheet. Resources themselves remained unchanged.
- Evidence: [checks](../build/office-template-qa.noindex/verify.log),
  [Release build](../build/office-template-qa.noindex/release-build.log),
  [resource audit](../build/office-template-qa.noindex/resources.json),
  [native creation and WPS readback](../build/office-template-qa.noindex/native-evidence.json).
- Microsoft Word/Excel, installed signed Finder and minimum-macOS acceptance
  were not run. The installed FileMint was not replaced; this task's generated
  app registrations were removed, leaving the installed extension registered.
  No commit or publication was performed.

## Issue #6 — Open with App folder authorization — 2026-10-03

Checked on macOS 27.2, arm64, `ea46b7c` plus the uncommitted
[issue #6 task](tasks/2026-10-03-issue-6-open-with-folder-access.md).

- `make verify` passed: 186 Core tests, 14 image tests, 5/5 public Harness cases,
  10 CLI regressions and offline release/appcast/entitlement checks.
- The final unsigned Release App and Finder extension build passed.
- The isolated, ad-hoc-signed sandbox app used an actual exact-folder picker for
  a synthetic external fixture. A separate launch restored its saved read-only
  grant without a picker, read the directory and a descendant, rejected writes
  and a removed ancestor scope, then released access after the request.
- Moving the granted directory and recreating its old path initially exposed a
  path-only identity check failure. The final fresh-resource identity check
  rejected the replacement, and cancelling reauthorization preserved the store.
  Wrong-folder and cancellation checks also passed without persisting new grants.
- The production coordinator sent a real mixed selection and a directory to the
  sandbox fixture's native receiver; source bytes, general clipboard, single-use
  tickets and the busy guard remained correct.
- Native UI inspection confirmed Chinese light guidance and folder-settings
  navigation, plus final English dark layout at 960×680 without clipped text.
- Evidence: [standard checks](../build/issue-6.noindex/verify.log),
  [build](../build/issue-6.noindex/build.log),
  [first grant](../build/issue-6.noindex/grant.log),
  [restart/read-only/release](../build/issue-6.noindex/restore.log),
  [replacement rejection](../build/issue-6.noindex/moved.log),
  [native transport](../build/issue-6.noindex/transport.log),
  [UI notes](../build/issue-6.noindex/native-ui.txt).
- These fixtures did not replace the installed FileMint. Actual installed signed
  Finder → Terminal working-directory and tab/window behavior, minimum macOS,
  third-party terminals and publication remain unverified for this change.

## Code review regression fixes — 2026-09-30

Checked on macOS 27.2, arm64, `fc8b7fe` plus the uncommitted review fixes.

- `make verify` passed: 181 Core tests, 14 image tests, 5 public Harness cases,
  10 CLI regressions and the offline release/appcast/entitlement checks.
  New cases keep permission-blocked quick tickets available to the authorization
  handler without granting write scope, reject a symlink escape after access is
  restored, and deduplicate a renamed favorite after simulated device renumbering.
- Three isolated release-resume tests use a disposable Git repository and offline
  signing/network adapters. They verify that interrupted builds retain their
  original source record, matching source resumes unchanged bytes without a
  rebuild, and a different commit or missing/malformed/mismatched record stops
  before external calls while preserving the stage. No Apple submission or
  public release was performed.
- `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` passed for the
  Release App and Finder extension. `make verify-favorite-model` passed its
  isolated 1,000-entry, concurrent-edit, recovery and busy-guard checks.
- Built `scripts/build_resource_tools_harness.sh` and launched its app with
  `FILEMINT_RESOURCE_REGRESSION_ONLY=1`. A gated production preview was cancelled;
  the same controller then automatically cleaned two synthetic images, completed
  successfully and retained the original bytes. The fixture loaded only its own
  settings and exited. This is native controller evidence, not installed Finder
  callback, sandbox authorization or minimum-macOS acceptance.
- Local logs: [standard checks](../build/review-fixes.noindex/verify.log),
  [Release build](../build/review-fixes.noindex/build.log),
  [favorite model](../build/review-fixes.noindex/favorite-model.log), and
  [resource lifecycle](../build/review-fixes.noindex/resource-regression.log).
  Real Finder authorization prompts and signed/notarized artifact delivery were
  not run for these fixes. The installed app and user preferences were not replaced.

## FileMint 0.6.4 release — 2026-09-30

The arm64/macOS 13+ [0.6.4 release](RELEASE_VERIFICATION_0.6.4.md), build 23,
passed the standard local signing, notarization, stapling, mounted-DMG,
entitlement and signed-appcast gates. Published DMG, checksum and appcast bytes
matched their local originals, and the release-verification, CI and website jobs
passed. The release and fix commit associate issue #5, which is now closed.
Earlier user-confirmed real Finder acceptance of the same icon code remains
below; this publication did not repeat installation or screenshots.

## Finder monochrome system appearance fix — 2026-09-30

Checked on macOS 27.2, Apple silicon, `1dde45f` plus the uncommitted
[monochrome appearance worktree](tasks/finder-monochrome-appearance.md).

- Finder's own symbol/logo images now carry explicit white pixels for Dark Aqua
  and black pixels for Aqua as non-template 1x/2x bitmaps. Each menu reads the
  extension's effective appearance on the main thread; only the resolved tone
  crosses to the callback. Settings previews retain native template behavior.
- Final `make verify` passed 178 Core tests, 14 image tests, 5 public Harness
  cases, 10 CLI regressions and the remaining offline checks. The unsigned App
  and Finder extension built. `git diff --check` passed. Local logs/readback are
  under `build/qa-2026-09-30-monochrome/` (ignored).
- The isolated final production renderer checked 22 slots and 14 built-in
  templates, including custom symbols, unavailable-symbol fallbacks and F logos.
  In both bitmap scales and TIFF readback, visible dark-menu pixels were white
  (each RGB channel > 0.98) and light-menu pixels black (each < 0.02). Transparency
  and logical dimensions survived; menu output was non-template and Colored
  images were preserved. This exercises image transfer without relying on
  template metadata; it does not establish Finder's internal transfer format.
- A local candidate signed with the existing Developer ID identity passed nested
  signatures, arm64 bundle and sandbox-entitlement checks. It was temporarily
  installed at `/Applications/FileMint.app`; `pluginkit` and the running process
  identified the changed extension at that path. CUA observed the real Finder
  main/submenus in the owned QA folder. The user then completed visual acceptance
  and confirmed: “不用截图，我已经完成了查看验收，实现的很棒”. Additional screenshot
  attempts stopped. This visual result is user-reported; the agent did not obtain
  a floating-menu image proving every individual row's colors.
- The original App, extension and preference bytes were restored and checked
  against their saved SHA-256 values. System appearance was confirmed back at
  Light, with one enabled FileMint extension at the original install path. The
  owned Finder QA window and isolated QA app were closed. Restoration and user
  confirmation are recorded under the local evidence directory's `native/`.
- No issue reply or publication occurred. This local candidate was not a newly
  notarized release, and macOS 13 runtime/clean-install trust were not tested.

## FileMint 0.6.3 release — 2026-09-30

The user selected the standard publication workflow. The arm64/macOS 13+
[0.6.3 release](RELEASE_VERIFICATION_0.6.3.md), build 22, passed local Developer ID
signing, Apple notarization/stapling, mounted-DMG, sandbox entitlements and signed
appcast checks. The published DMG, checksum and appcast were downloaded and
compared byte for byte. Published-release verification, CI and website deployment
passed. The unfinished exhaustive QA was not repeated; earlier native observations
and the remaining installed Finder, public-feed 0.6.3 update and environment
limitations are recorded in the linked release evidence. The installed app and
owner preferences were unchanged in this publication turn.

## Background Copy Paths and global icon style QA — 2026-09-30

Checked on macOS 27.2, Apple silicon, `0409f1a` plus the uncommitted
[Finder path/icon-style worktree](tasks/2026-09-30-finder-path-and-icon-style.md).

- `make verify` passed 178 Core tests, 14 image tests, 5 public Harness cases,
  10 CLI regressions and the remaining offline checks. The unsigned Release
  app and Finder extension built. `git diff --check` passed. Local evidence is
  under `build/qa-2026-09-30-issues.DTad4B/` (ignored).
- The isolated production renderer checked 22 icon slots and 14 built-in
  templates in Colored and System Monochrome, including custom symbols,
  unavailable-symbol fallback and both F logo assets. Raster output was visible,
  Colored retained color and Monochrome had no colored pixels and was templated.
- CUA observed dark glyphs in the light monochrome settings preview and light
  glyphs in the dark preview. Monochrome disabled both color wells while allowing
  a symbol edit. Switching back restored the saved `folder.fill` symbol and
  `#00C8B3` / `#0088FF` colors and enabled both wells. Chinese/English style options
  appeared in the native picker. The QA app was closed after the checks.
- The fixture used disposable preferences, no user file operation and no general
  clipboard writes. Installed FileMint/Finder was not replaced; real Finder
  background clipboard execution, highlighted menu colors and NAS authorization
  remain separate pending checks. No publication occurred.

## FileMint 0.6.2 release — 2026-09-29

The arm64/macOS 13+ [0.6.2 release](RELEASE_VERIFICATION_0.6.2.md) passed local Developer ID signing, Apple notarization/stapling, mounted-DMG and appcast checks. An isolated signed sandbox Sparkle fixture replaced and relaunched build 1 with build 2 at the same path; the published DMG, checksum and appcast were downloaded and compared byte for byte. Release verification, CI and website deployment passed. This was not an installed FileMint/Finder test or a public-feed upgrade from 0.6.1.

## Clipboard text and directory opening QA — 2026-09-28

Checked on macOS 27.2, Apple silicon, `c23ffc6` plus the uncommitted
[clipboard/directory worktree](tasks/2026-09-28-clipboard-text-and-directory-tools.md).

- `make verify` passed 168 Core tests, 14 image tests, 5 public Harness cases,
  10 CLI regressions and the remaining offline checks. The unsigned Release
  app/Finder extension built, and `git diff --check` passed. Logs are under
  `build/qa-2026-09-28/` (ignored local files).
- A separate Developer ID-signed local QA DMG passed nested signature,
  entitlement, bundle, checksum and `hdiutil verify` checks. It was not
  notarized, installed or published; its SHA-256 is recorded beside the DMG.
- An isolated native UI fixture used a named pasteboard to prefill the creation
  panel. Creating `QA-clipboard.txt` wrote exactly 29 expected UTF-8 bytes,
  including CRLF, Unicode, surrounding spaces and literal `{{fileName}}`.
  A second cancelled draft created no file. The user's general pasteboard was
  not used for this test.
- The signed disposable sandbox fixture delivered a complete file/folder
  selection and a directory through the production coordinator, preserving
  the source and general pasteboard. Terminal 2.15 and Warp Stable returned
  success for both New Tab and New Window. Read-only shell inspection confirmed
  each request's actual cwd, including a path with quotes, punctuation, emoji
  and a newline. It does not establish tab/window counts or routing under
  duplicate Services registrations.
- VS Code 1.138.0 displayed the exact temporary QA folder as its workspace
  root. In the isolated settings UI, Terminal's mode and menu-position pickers
  appeared on one row, the preview updated when the mode changed, and VS Code
  had no terminal picker. Chinese/light and English/dark were inspected.
- Native QA exposed a settings-window resize from 960×680 to 960×1253 after
  changing language. Disabling `NSHostingView`'s implicit sizing in the
  product window kept the isolated regression fixture at 960×680 through
  language and appearance changes. The actual installed product window was
  not replaced or run with this change.
- Not run: current-source installed Finder callbacks, signed product-window
  behavior, iTerm2/Ghostty (not installed), tab/window counts (terminal UI
  inspection is blocked by the computer-use tool), duplicate/disabled
  Services, smaller/multiple displays, and macOS 13 runtime. The installed
  `/Applications/FileMint.app` is a different binary from this worktree; no
  install or publication was performed. The owner chose to keep the installed
  app unchanged for this round and will provide iTerm2/Ghostty, macOS 13 and
  manual tab/window-count observations later. After packaging, PluginKit still
  listed only the installed Finder extension.

## Favorite availability, Finder locate and groups — 2026-09-28

Checked on macOS 27.2, Apple silicon, `684dba2` plus the uncommitted favorite
repair worktree. Contract: [Favorite locations](../specs/domains/favorite-locations.md).

- Read-only diagnosis found an existing saved item with matching inode, creation
  time and bookmark volume UUID, but a changed device number. Its group was
  already saved. No user catalog was modified during diagnosis or verification.
- `make verify` passed 158 Core and 14 image tests plus the public Harness, CLI
  and script checks. The identity regressions cover device renumbering, a
  different/missing volume UUID, wrong kind, changed creation time, same-path
  replacement and the legacy device fallback. The unsigned app/extension built.
- `scripts/build_design_ui_harness.sh` ran production settings/model code with
  an isolated catalog and a deliberately mismatched saved device number. That
  item stayed available; the missing fixture retained its warning and group.
- Native UI checks passed: batch assignment to `*`, filtering to that group,
  returning to All Groups after moving its final item to Ungrouped, and saving
  a Chinese group through Name and Group. The saved fixture catalog was read
  back to confirm the Chinese group and successful-locate timestamp.
- Clicking Show in Finder on the device-renumbered fixture opened its parent
  with the expected file selected. The test Finder window and fixture app were
  closed afterward. Logs: `build/favorite-repair-qa/verify.log`, `build.log`, and
  `ui-build.log` (local, ignored).
- Not run: installed signed-app bookmark access, installed Finder extension
  callbacks, folder/package locate, and macOS 13 runtime. No installed app was
  replaced and nothing was published.

## Settings setup and template interaction — 2026-09-24

Checked on macOS 27.2, Apple silicon, `7a482bb` plus the uncommitted
[settings task worktree](tasks/2026-09-24-settings-setup-and-templates.md).

- `make verify` passed 150 Core and 13 image tests plus public Harness, CLI,
  context and release script checks. The unsigned universal app/extension built.
- In an isolated native settings fixture at 840×600, a built-in template could be
  selected with the muted mint style, edited and removed. The fixture preferences
  stored the removed stable ID. General showed both manual extension setup and
  Full Disk Access guidance without changing system permission.
- The populated Open with App fixture showed a blue insertion guide. A drag in
  the final build reordered rows with a short transition; the settled UI and
  saved preference order agreed. The fixture used its own preferences.
- Installed Finder callbacks, real permission toggles, Reduce Motion presentation,
  macOS 13 and Intel runtime were not checked. No installed app was replaced.

## Performance and security repair QA — 2026-09-23

Checked on macOS 27.2, Apple silicon, `79c2c45` plus the uncommitted
[performance/security worktree](tasks/2026-09-23-performance-security-audit-fixes.md).

- `make verify` passed after implementation: 148 Core and 13 image tests,
  public JSON Harness, CLI and script checks. The unsigned universal app and
  Finder extension built; the Pages site build and six immutable Action-pin
  assertion passed. No publication occurred.
- The disposable sandboxed Open with App app delivered a full Unicode file/folder
  batch to a native receiver, preserved source bytes/clipboard, and rejected an
  oversized application Info.plist.
- After explicit approval for only its generated `source` and `target` folders,
  the disposable sandboxed move app prepared and completed a two-item move.
  Pending count reached zero; the source was empty and target file/package bytes
  matched the original fixtures. No owner preferences or user files were used.
- A disposable HFS+ disk image on a distinct device exercised the physical
  cross-volume Core path: file, symbolic link and App package moved intact;
  occupied destination entries remained unchanged, the source was restored on
  collision, and owned staging was absent. The disk image was ejected and removed.
  This CLI observation is separate from sandboxed Finder execution.
- The isolated Resource Tools native app completed all six tools in Chinese/light
  and English/dark with two synthetic images each; original bytes and clipboard
  remained intact.
- PluginKit currently registers only the installed 0.5.9 Finder extension at
  `/Applications/FileMint.app`, while this source builds 0.5.10. A separate local
  ad-hoc 0.5.10 QA DMG and a verified backup of the installed 0.5.9 app are ready;
  the installed app has not been replaced. Actual new-code Finder callbacks,
  Intel and macOS 13 runtime remain unverified. A crash during private destructive
  staging can leave a recoverable item in that staging folder.

## FileMint 0.5.9 release — 2026-09-22

Source tag `v0.5.9`, commit `6f9c3061f671e86026cb721a539393aa9a802194`, build 17.
[Release evidence](RELEASE_VERIFICATION_0.5.9.md) records accepted notarization,
stapling, corrected embedded sandbox permissions, copied-DMG startup, published
byte comparisons and successful release/source/website checks. Confirmed affected
0.5.7/0.5.8 users need one manual installation of 0.5.9.

## Sparkle signed entitlement repair — 2026-09-22

Follow-up to the user's installed 0.5.7 → 0.5.8 failure. See
[diagnosis and evidence](tasks/sparkle-entitlements-fix.md).

- Installed 0.5.7 and published 0.5.8 both contained literal build variables in
  the signed installer Mach permissions. Unified logs confirmed sandbox denial;
  this was not caught by earlier signature/notarization/startup checks.
- Manual signing now resolves bundle IDs first. A Security-framework check reads
  the embedded entitlements, rejects unresolved variables/wrong service names,
  and preserves Finder sandbox/network boundaries. The old installed app fails
  the new gate; the complete signed 0.5.9 local candidate passes after mounting.
- Two isolated Developer ID-signed sandbox hosts completed download, extraction,
  replacement and relaunch with Sparkle. Old PID 60859 exited and new PID 60910
  launched build 2 at the same fixture path. Signature and entitlement checks
  passed after replacement. No production app/preferences were used by this test.
- The native fixture uses a minimal user driver and a local feed; the production
  driver's callback regression passed separately. Installed Finder refresh,
  production-feed/custom-driver end-to-end, Intel and macOS 13 runtime remain unrun.
- The tested local candidate was followed by the signed/notarized 0.5.9 release
  above. Old affected installations need one manual replacement; a feed cannot
  repair their current signed permissions.

## FileMint 0.5.8 release — 2026-09-22

Source tag `v0.5.8`, commit `eb487e3250dc1a7d631332cfe4500ae769b96269`, build 16.
[Release evidence](RELEASE_VERIFICATION_0.5.8.md) records accepted Apple notarization,
stapling, universal/nested-signature checks, copied-DMG launch and Gatekeeper,
published asset byte comparisons, and successful source/artifact/website CI.
Native launch was checked on macOS 27.2/Apple silicon; owner preferences were
unchanged. This does not add installed Finder, full updater replacement,
clean-Mac, Intel or macOS 13 runtime evidence to the feature checks below.

## Settings appearance and consistency — 2026-09-22

Checked on macOS 27.2 (26B5086k), Apple silicon, `e2202df` plus the uncommitted
settings worktree. See [the task](tasks/settings-appearance.md) for commands and logs.

- `make verify` passed: 139 Core and 13 image tests, 5 public cases, 10 CLI regressions,
  3 appcast tests and context checks. The final unsigned universal app/extension built.
- Inspected all eight settings pages in English/light and Chinese/dark at 840×600.
  General's Theme and Interface language controls align with switches; Creation
  and tool pickers share the trailing treatment. Native menu choices, sidebar
  Up/Down, long-page scrolling, disabled icons/controls and About links were checked.
- The isolated production model passed immediate appearance application, clearing
  the app override, store reload and failed-save rollback. Relaunching the fixture
  retained Dark and English. Follow System read back as `system` and restored the
  current system appearance. New/missing/invalid theme values have Core coverage.
- Existing creation and resource-processing windows changed light/dark without
  reopening. Template editor and creation Escape cancellation worked. Open with
  App's populated layout was checked by adding Preview to fixture preferences.
- Native tests used disposable preferences and generated images; no installed app,
  user files or owner preferences were changed. Actual OS appearance toggling,
  Intel and macOS 13 runtime remain unrun; no publication was performed.

## Open with App — 2026-09-22

Checked on macOS 27.2, Apple silicon, `55d9a1f` plus the uncommitted Open with App
worktree. See [the task](tasks/2026-09-22-open-with-app.md).

- `make verify` passed: 127 Core tests, 12 image tests, 5 public cases, 10 CLI
  regressions, 3 appcast tests and context checks. The unsigned universal app and
  Finder extension built after the final stack/app-icon changes.
- An isolated production settings window added VS Code through the real picker,
  defaulted to submenu, retained main placement when re-added, and removed its last
  entry. JSON readback confirmed bookmark/placement/removal persistence.
- Chinese light/dark and English dark at 840×600 were inspected through native
  screenshots. The final stack entry icon was inspected in Chinese/light. These
  fixtures used their own preferences and did not launch VS Code or run login setup.
- The ad-hoc-signed sandbox fixture ran the production operation coordinator and
  NSWorkspace opening. A separate native app received the full Unicode file/folder
  batch in order; wrong app identity and ordinary-directory app selection were
  rejected. The ticket was single-use, the busy guard released, and source bytes,
  folder and clipboard remained intact. Log: `/tmp/filemint-open-with-native.log`.
- Installed Finder callbacks, visible Finder child icons, actual third-party
  support, external-folder picker cancellation, keyboard-only navigation, Intel
  and macOS 13 runtime remain unrun. No installation, enablement or publication.

## Native UI/UX v1 and image resources — 2026-09-18

Checked on macOS 27.0 (26A428), Apple silicon, `6bf596d` plus the uncommitted
resource/UI worktree. See [the task](tasks/image-resource-tools.md) and
[the approved design](design/UI_UX_V1.md).

- `make verify`: 131 Swift tests (119 Core and 12 native image tests), 5 public
  Harness cases, 10 CLI regressions, 3 appcast tests and context checks passed.
  Unsigned Release app/extension build passed for arm64 and x86_64.
- Production settings/views/controllers in an isolated app and preferences store
  were inspected at 900×650 Chinese/light and 840×600 English/dark. Three sidebar
  groups, file-tool disabled states, template editing/cancellation, folder guidance
  and About retained readable controls. No login setup or automatic update task ran.
- With the fixture's Finder resource master off, the main-app picker selected its
  synthetic `Mountain.png`; the real coordinator/panel saved a 1600×1000 JPEG.
  The saved Finder resource preference remained false.
- The native New File panel accepted `界面验收.md`, multiline Chinese and literal
  `{{year}}`; Command-Return created the file and its UTF-8 bytes were verified.
- Six production image panels ran in Chinese/light and English/dark using only
  fixture images. All completed two-image batches. Oversized stitch recovery,
  OCR clear/retype, source preservation and result handling passed. Final run:
  `/private/tmp/filemint-design-resource-final.log`.
- AppKit view-cache exports miss SwiftUI layers and were not used as visual proof;
  live native screenshots and accessibility readback were used instead.
- The installed application was not replaced. Finder's installed callback, actual
  sandbox source/output grants, Intel execution and macOS 13 runtime remain unrun;
  these observations do not substitute for those scenarios. No commit or release.

## Desktop aliases — 2026-09-18

Checked on macOS 27.0 (26A428), Apple silicon, `41067c3` plus the desktop-alias
worktree. See the [task and official sources](tasks/desktop-aliases.md).

- Final automated verification passed: 112 Swift tests, 5 Harness cases, 10 CLI
  regressions and 3 appcast tests. Unsigned universal app/extension build passed.
- Production settings view: the opt-in alias checkbox, placement picker and blue
  symbol were inspected in Chinese/light and English/dark at minimum detail width.
  Main-menu placement changed successfully; master off disabled alias controls
  while preserving their values.
- An isolated, ad-hoc-signed sandbox fixture compiled the production coordinator.
  Its source and synthetic Desktop were initially inaccessible. Cancelling the
  source picker left zero outputs. Authorizing both exact fixture folders made
  two aliases. Relaunching and repeating reused saved bookmarks without pickers,
  making `Folder 2` and `报告 2.txt`; both original fixture contents were unchanged.
- Finder displayed the native arrow. Get Info identified the folder output as
  “替身” and showed the correct original; opening it displayed the original child.
- The isolated fixture did not replace the installed app. A later clean arm64
  Debug build `0.5.6 (14)` was installed at `/Applications/FileMint.app`; the
  installed settings page showed the opt-in `发送替身到桌面` switch and placement
  picker without changing preferences. The actual Finder extension callback,
  real Desktop/iCloud integration and removable volumes remain unverified.
  Rollback archive: `build/local-install-backups/20260918-174004-desktop-alias-debug-clean/FileMint-before-debug.zip`.
- The four aliases created by the disposable fixture were removed from
  `build/desktop-alias-native.iS7cSz/Desktop`; no test aliases remain there.
- Logs and disposable fixture sources are in `build/desktop-alias-evidence/`.

## File tools settings polish — 2026-09-18

Checked on macOS 27.0 (26A428), Apple silicon, `559fc8f` plus the UI-polish
worktree. The isolated native fixture compiled the production settings view and
shared tool images without loading or saving the owner's preferences.

- All five expanded tool sections, native checkboxes and placement/deletion
  controls were inspected in Chinese/light and English/dark, including the
  632-point detail area corresponding to the app's 840-point minimum width.
- Module off kept every section visible and grayscale. Accessibility reported
  all child controls disabled; attempted pointer/keyboard changes to checkboxes,
  menu location and deletion mode left fixture JSON unchanged. Child-only
  disablement kept its enable checkbox available. Custom move location and
  deletion mode survived module off/on.
- All five shared symbols rendered colored, non-template images at 16 and 20
  points. The compiled Finder adapter assigns these at either menu level and
  retains the pending-move icon in its submenu. This is not installed Finder
  menu/highlight verification; the existing app/extension were not replaced.
- The follow-up Debug install at `/Applications/FileMint.app` was inspected in
  Chinese/light appearance. Menu-position values now use system control text
  color, and the selected File & Folder Tools sidebar row has a slightly stronger
  mint surface while retaining its fine outline. The previous installed package
  is recoverable from `build/local-install-backups/20260918-165507-file-tools-ui-tweak/`.
- `make verify` passed: 104 Swift tests, 5 public cases, 10 CLI regressions and
  3 appcast tests. The unsigned universal app/extension build also passed.

See [the task record](tasks/file-tools-ui-polish.md) for local evidence and limits.

## 0.5.5 signed and notarized release — 2026-09-18

Published FileMint 0.5.5 (13) from source tag v0.5.5 at commit
846f128ec8da4a47f0e2cd01ddd5c886f0da6a1d.

- The release process reran context, Core, harness, CLI and appcast verification:
  97 Swift tests in 9 suites, 5 JSON harness cases, 10 CLI regressions and
  3 appcast tests passed. The base-aware Chinese and English website build,
  unsigned universal candidate build and Sparkle driver verification also passed.
- The locally built universal DMG, main app, Finder extension and embedded Sparkle
  helpers passed Developer ID validation. Apple notarization submission
  12215c00-123f-4332-b449-1c3bb7c1f31e was Accepted; stapling, mounted-image
  validation, final SHA-256 and appcast signature validation passed before upload.
- GitHub Release v0.5.5 contains the notarized DMG, its checksum and appcast.
  All three downloaded assets matched the local release files byte-for-byte.
  CI, Pages deployment and the published-release verification job succeeded; both
  public website homepages returned HTTP 200.
- The signed package was not installed over the owner’s existing app, and full
  signed Finder/Sparkle runtime acceptance remains unrun. This release record
  does not represent build or artifact checks as proof of those native scenarios.

See [the 0.5.5 release record](RELEASE_VERIFICATION_0.5.5.md) for exact assets,
hashes, release links and runtime limits.

## Finder tools menu icons — 2026-09-18

Checked on macOS 27.0 (26A428), `9bbc850` plus the existing file-tools worktree
and the menu-icon changes. The tools root uses `wrench.and.screwdriver` with a
mint/blue palette; the pending-move root uses `arrow.right.square` with a
mint/teal palette. Both resolve through the actual `menuIcon` helper as 16 × 16
non-template images. An isolated AppKit rendering of both icons with their
Chinese labels was inspected in light/dark appearances.
`make verify-context` and the unsigned universal `make build` passed. This was
an appearance-only change; Core tests were not rerun at that point.

## Debug build installation and Finder menu acceptance — 2026-09-18

Built the current worktree as an arm64 Debug app with ad-hoc local signing,
`get-task-allow`, App Sandbox and Hardened Runtime disabled, then installed it
at `/Applications/FileMint.app`. The previous installation is recoverable from
`build/local-install-backups/20260918-debug-menu-icons/`.

- The installed app and embedded Finder extension passed deep strict signature
  verification and report version `0.5.4 (12)`. Their main executable bytes match
  the Debug build output.
- After restarting Finder, the Documents background context menu showed New File
  and its format entries. A selected-directory context menu showed File & Folder
  Tools with Copy Names, Copy Paths and Move File / Folder. PluginKit reports one
  FileMint extension, from `/Applications/FileMint.app`.
- The temporary Move Selected Items Here action was not prepared during this
  install check, so no pending move state was created. Its two icon symbols were
  already verified in the isolated light/dark rendering above.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make verify` passed
  97 Swift tests, 5 harness cases, 10 CLI regressions and 3 appcast tests. The
  installed app is running for manual acceptance; release signing and notarization
  are outside this Debug install.

## Colored Finder menu icons Debug update — 2026-09-18

Changed the two Finder root icons to palette-colored, non-template SF Symbols:
mint/blue for File & Folder Tools and mint/teal for Move Selected Items Here.
Both remain 16 × 16. The arm64 Debug build was installed at
`/Applications/FileMint.app`; the previous monochrome install is recoverable from
`build/local-install-backups/20260918-color-menu-icons/`.

- After restarting Finder, the actual selected-file context menu showed File &
  Folder Tools with Copy Names, Copy Paths and Move File / Folder. The installed
  FileMint extension was the only PluginKit registration.
- No pending move was prepared, so this check did not change the user's pending
  move state. The move icon was verified through the same palette helper and the
  isolated AppKit rendering.
- `make verify-context`, the arm64 Debug build, and
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make verify` passed.

## Installed Debug Finder menu recovery — 2026-09-18

Checked on macOS 27.0 (26A428), with installed Debug 0.5.4 (12) at
`/Applications/FileMint.app`; source checkout was `9bbc850` plus existing
file-tools worktree changes. No build or installation was performed in this check,
so exact source-to-installed-binary correspondence was not established.

- Reproduced: the Documents background context menu had no FileMint New File
  entry. PluginKit listed exactly one enabled FileMint extension at the installed
  path, but its process was absent. Strict signature verification passed and the
  installed extension retained its App Sandbox entitlement.
- System logs showed the Finder-hosted extension received SIGTERM at 10:14:11
  and Finder lost its connection. The sender of that signal was not established.
  Separate sandbox-rejection logs referred to an unsigned Release build under
  DerivedData, not the installed Debug extension.
- Recovery passed: `killall -TERM Finder` restarted Finder; the installed
  extension process returned. The actual Documents background context menu then
  showed New File and its custom, text, Markdown, JSON, HTML, CSS and Shell items.
  PluginKit still listed exactly one enabled installed extension.
- No application code, preferences or extension enablement was changed. File
  creation, desktop menus and recurrence after another Debug replacement were
  not tested. Automated tests/build were not run for this runtime recovery.

## Settings sidebar and native layout — 2026-09-17

Subsequent local-install check on the same date: at the user's explicit request,
the arm64 Debug build was installed at `/Applications/FileMint.app` and opened.
Both app and Finder extension processes were observed at that installed path,
with exactly one enabled extension registration. Ad-hoc signatures passed strict
deep verification; both targets retain App Sandbox and get-task-allow. This
development build is signed without Hardened Runtime because its ad-hoc Debug
dylib was rejected by the release-style library validation. No system security
setting or release signing configuration was changed. The preferences JSON hash
was unchanged. The prior installed app is archived locally at
`build/local-install-backups/20260917-175149/FileMint-installed.zip`; the same
directory contains the installation record and build log. Debugger attachment,
complete Finder creation and public-release notarization were not tested.

Checked on macOS 27.0, Apple silicon, at `73e02f5` plus the settings-navigation
worktree changes. This is local development evidence, not release acceptance.

- Final `make verify` passed 83 Swift tests, 5 JSON cases, 10 CLI regressions
  and 3 appcast tests. The unsigned universal app build passed. Logs are retained
  locally under `build/settings-preview/`; no signed installer was produced.
- The actual built app was opened in Chinese/light appearance: settings pages,
  template actions and the expanded/scrollable Full Disk Access guide were
  inspected. The app's About menu selected About in the same settings window.
  The sidebar New File action opened its directory picker; cancelling returned
  to settings. No file was created and no settings toggle was changed during QA.
- An isolated native preview compiled the actual page views with in-memory
  fixture models, without preferences storage, bookmarks, Finder registration
  or network operations. At 840×600, English/dark template actions, creation
  settings, About and the editor sheet were readable; Escape cancelled editing.
- After the user's visual feedback, the final sidebar used a continuous
  background, subdued mint selection and a thin mint keyboard focus outline.
  Chinese and English dark layouts were inspected; Down moved from Creation
  to Templates & Types, and accessibility exposed the selected page button.
- The fixture is layout/interaction evidence only. Real persistence, login-item
  changes, updater installation and signed/installed Finder cold-launch/window
  isolation were not rerun. macOS 13 retains the system focus indicator and its
  native appearance was not tested on that OS. No release was published.

See [the settings task](tasks/2026-09-17-settings-navigation.md) for scope and
remaining release checks.

## Automatic update checks and extension guidance — 2026-09-17

Published 0.5.4 (12) subsequently passed local Developer ID signing, Apple
notarization and stapling, downloaded-asset comparison and GitHub release
verification. See [the 0.5.4 release record](RELEASE_VERIFICATION_0.5.4.md) for
the exact source commit, submission ID, checksum and runtime scope.

- General now has a default-on automatic update switch. Attempts persist across
  launches and are spaced at least seven days apart; the first overdue check
  waits at least 60 seconds. Manual checks remain usable with the switch off.
  Release discovery shows an in-app/menu indication without a download or window.
- Apple public documentation and a DTS response were reviewed; the bundled
  extension's loading and user enablement are separate. The app remains
  sandboxed and uses status plus system settings guidance. Sources and the
  supported boundary are in `FINDER_EXTENSION_ENABLEMENT.md`.
- Initial `make verify` and `make build` attempts were blocked by the machine's
  unaccepted Xcode license (exit 69). Command Line Tools also failed with a
  PackageDescription linker error. After the user completed Xcode setup,
  Xcode 27.0 (27A266a) passed its first-launch check. No system setting or license
  was changed by the agent.
- The normal `make verify` command then passed all **60 tests in 5 suites** and
  all **5 JSON harness cases** using `/Applications/Xcode.app/Contents/Developer`.
  `make build` with `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` succeeded.
  Both the app and Finder extension contain arm64 and x86_64; their versions
  match, and the accessory-launch flag, Finder extension metadata and bundled
  license were checked. This is an unsigned local build, not a signed release,
  notarized installer or completed installation. Global `xcode-select` still
  points to Command Line Tools; the Makefile selects Xcode for these commands.
- Independent validation used the installed Swift compiler directly with its
  matching SDK, writing artifacts to `/tmp/filemint-validation`: all Core sources
  compiled; all **60 Swift Testing tests in 5 suites** passed; all **5 JSON harness
  cases** passed. The app, shared UI and Finder status bridge passed Swift 6
  type checking. Existing download-closure capture warnings remain.
- A temporary native smoke executable compiled the actual `UpdateModel.swift`
  with in-memory preferences and a controlled mock update client. It exercised
  the real 60-second one-shot timer: no immediate request, exactly one delayed
  check, attempt recorded before completion, cancellation on disabling, manual
  checks with auto off, retained cooldown after toggling, and an in-flight manual
  check unaffected by toggling all passed. It made no network request and did
  not open an installer or change the user's preferences.
- `git diff --check` passed. Packaged-app visual inspection, a real automatic
  GitHub request, and sleep/wake behavior remain native acceptance follow-ups.
  The existing installed app was not replaced, and no release was published.

## Automated verification

- 54 Swift Testing tests pass, including Desktop menu destinations, installer quarantine preflight, repeated menu creation, update validation and bilingual About
  text, plus the permission-copy tests and all 5 public JSON harness cases.
- Coverage includes 40 simultaneous creations with distinct payloads, exact
  custom filenames, verbatim UTF-8 and CRLF, dangling symlinks, atomic replacement,
  template/date rendering, single-pass expansion, custom types, preference
  migration/storage, startup defaults, saved off switches, locale resolution,
  expiring one-use requests and captured Finder destinations.
- Release compilation passes. Nested code signatures, both architectures,
  app/extension versions and the bundled license are checked by verify_bundle.sh.
- The DMG passes hdiutil verification. Its SHA-256 manifest uses a portable
  basename. Packaging removes its staging app, preventing residual registrations.

## Native runtime checks

| Scenario | Observed result |
| --- | --- |
| Launch at login | FileMint appeared in macOS Login Items; app switch disabled and re-enabled registration |
| Preference persistence | Startup and menu bar switches remained off after quit/relaunch; restored to on afterwards |
| Permission guide | Button opened Privacy & Security → Full Disk Access; no full-disk permission was automatically granted |
| Folder permission | Test directory was authorized once; later creation after relaunch reused the saved access |
| Custom type | TOML type with starter content saved and appeared in Finder immediately |
| Quick creation | Created Untitled.toml and Untitled 2.toml with correctly rendered names |
| Hidden UI | Quick creation worked with the settings window closed and menu bar item hidden |
| Custom filename/content | Actual UI saved demo.js; on-disk UTF-8 bytes matched pasted Chinese, emoji, multiline JavaScript and literal {{year}} |
| Content editing | Return inserted a newline; Undo restored the prior content; suffix changes preserved edits |
| Format picker | Entering a known suffix then opening the list showed all enabled types |
| Collision confirmation | Cancel was visibly the default button; Return dismissed the confirmation, preserved the draft and left the original bytes unchanged |
| Cancel | Cancelling the remaining draft did not create demo.md |
| Language | Follow System resolved to Chinese; native menus/pickers and application labels localized correctly |
| Old registrations | Removed old 0.1.0 and staging/development copies; refreshed System Settings showed one installed FileMint entry |

## Performance and icon audit

Runtime inspection found and fixed a menu bar binding feedback loop that repeatedly
saved preferences during SwiftUI updates. The setter now rejects unchanged values
and defers system writebacks outside the render transaction. Idle observations
showed 0.0% CPU for the app and Finder extension processes after the fix. This is
an idle observation, not a benchmark for every workload.

File creation performs no background traversal of user folders and no clipboard
polling. File writes and Finder request processing run away from the main thread.
Menu snapshots are bounded; consumed request files were removed as expected.

App/Dock assets, Finder toolbar, menu bar and the colored Finder root mark use
the Folded F identity. The installed extension's real NSBundle image API loaded
the 16-point root mark and both 18-point toolbar/menu marks with alpha. The macOS
icon service returned the updated Folded F for /Applications/FileMint.app, and
no obsolete pinned FileMint path was found in Dock preferences. The application
window also displayed that icon. Direct capture of Dock/context-menu surfaces
was unavailable in the UI driver, so those checks use asset and system-icon
service evidence rather than claiming a captured Dock/menu screenshot.

## Distribution limits

For published version 0.5.1, GitHub workflows built, verified and attested the
DMG; that provenance is not Apple notarization. Future public versions use
local Developer ID signing and Apple notarization, then upload the validated
DMG to GitHub. First-launch and Finder extension approval remain subject to
macOS policy and are explained in INSTALL.md.

Intel execution, reboot/login execution and a clean-Mac first install were not
performed on this host. Universal compilation, native login registration/status,
and the actual runtime checks above are the evidence available here. The final
0.5.1 release download and its attestation were verified separately after publication.

## 0.5.3 protected-folder menus and dynamic home scope (2026-09-14)

- The first 0.5.2 candidate passed 51 core tests but failed user acceptance:
  Documents and the actual desktop background still had no FileMint menu. Its
  targetless-Desktop fallback did not address the cause and has been removed.
  That candidate is not approved for publication, regardless of its Apple result.
- Temporary native diagnostics confirmed that the running extension registered
  Desktop, Documents and Downloads, but only received Downloads observation
  events. A real Documents context menu never called FileMint's menu function.
- Adding the dynamically resolved user home as an observation ancestor produced
  Documents observation and container-menu callbacks. The native Documents menu
  then displayed New File and all enabled types. The user also confirmed that
  desktop, Documents and Downloads menus appeared; they explicitly did not test
  actual file creation. All temporary diagnostics were removed afterwards.
- Menu and quick-ticket validation share the configured folder scope, separate
  from observation roots. A native check with home excluded confirmed that its
  background did not receive a FileMint menu merely because it was observed.
- The user subsequently required menus in their home directory itself. Default
  scope now includes the OS-resolved real user home, using the existing user-ID
  lookup rather than a username, Finder display label or fixed /Users path.
  Old three-folder defaults gain home once; restricted scopes, later removal,
  language and saved bookmarks survive migration.
- The original three-folder JSON was restored before testing the migration.
  Installed 0.5.3 (11) then showed New File both on the home background and on
  a file in home without manually adding a home entry to that legacy JSON.
- Documents → New File… opened the native panel with Documents as its exact
  destination. The test draft was cancelled without writing a file. No additional
  system privacy or folder-bookmark permission was granted during these checks.
- All 54 Swift tests and 5 public harness cases passed. Tests cover different
  usernames, a relocated /Volumes home, old-settings migration and saved removal,
  out-of-scope targets, and ticket-to-file creation in a temporary Desktop.
- The universal Release build, nested Developer ID signatures and bundle checks
  passed. The installed copy is 0.5.3 (11) with one enabled PluginKit registration.
  Clean-Mac notarized-install trust and actual user-folder file creation remain
  separate acceptance items. Public release was initially planned to wait for
  Apple notarization; the owner subsequently authorized a clearly labeled
  one-time 0.5.3 release while the submission remained `In Progress`.
- About and both READMEs retain the verified Special Thanks / 特别感谢 to 阿逼,
  linking to https://github.com/bibinocode for signing and notarization help.

## 0.5.3 notarization accepted after publication (2026-09-15)

- A live `xcrun notarytool info` query using the local `FileMint` Keychain
  profile returned `Accepted` for `FileMint-0.5.3.dmg`, submission
  `11ed351a-020e-4107-bfae-72d0a8daec52`. The response identified the original
  submission creation time as `2026-09-14T09:56:50.589Z`; it did not report the
  later transition time.
- A live GitHub Release query still found the exact 4,177,677-byte asset with
  SHA-256 `712219fe3e3b163baf0fabfec16a78b305ac09311d1eba51a71010ea04c0f6ae`.
  The asset therefore remains byte-identical to the accepted submission. It was
  published before acceptance and has no stapled ticket, but Apple publishes the
  accepted ticket online for Gatekeeper, including already-downloaded copies.
  Offline first-launch behavior and a clean-Mac networked launch remain untested.
- The Release title and body still said `pending` at the start of this follow-up.
  They can be edited in place from `docs/RELEASE_NOTES.md`; the DMG and checksum
  must not be deleted, replaced or re-uploaded. A future version remains the path
  for a distribution with a locally stapled and validated ticket.

## 0.5.3 early signed GitHub release (2026-09-14)

- The owner explicitly requested publication before Apple finished processing
  the existing `notarytool` submission `11ed351a-020e-4107-bfae-72d0a8daec52`.
  Apple reported `In Progress` immediately before publication and again after
  the release checks. The published DMG has no stapled notarization ticket.
  The release title, notes, README and install guide identify this limitation;
  Gatekeeper may block the download. SHA-256 is not notarization evidence.
- The published `FileMint-0.5.3.dmg` is the exact 4,177,677-byte submitted DMG
  from binary source commit `c3d924a81eeb5e2efdb0b637eefe405947593dde`,
  SHA-256 `712219fe3e3b163baf0fabfec16a78b305ac09311d1eba51a71010ea04c0f6ae`.
  Annotated tag `v0.5.3` points to `ab4f8096c8f3796d3f3f4a1ee6c0ef8d3e83eab9`,
  which adds only release documentation and verification scripts; no app or
  package code changed. A local manifest records both commits separately.
- `make verify` passed before and after the release-description change: 54
  Swift tests and 5 public harness cases. The published DMG checksum, disk-image
  integrity, universal app/Finder extension, version/build `0.5.3 (11)`, nested
  Developer ID signatures, hardened runtime and secure timestamps passed local
  checks. The one-time 0.5.3 path explicitly detects the absence of a stapled
  ticket; later release verification still requires one.
- [GitHub Release](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.3)
  is public, stable and Latest with only the DMG and portable `.sha256` assets.
  The downloaded assets matched the local bytes exactly. `make verify-updates`
  passed against the live 0.5.3 release, covering the latest-version response,
  cancellation, retry, size, SHA-256, quarantine and cleanup. It did not install
  or launch the published app.
- [Verify uploaded DMG](https://github.com/FileMintApp/FileMint/actions/runs/34835141335)
  passed after publication, checking the uploaded checksum, universal bundle and
  Developer ID signatures. The job did not claim a notarization ticket or a
  GitHub Actions build attestation. Clean-device Gatekeeper behavior and actual
  user-folder file creation remain unverified. The former automatic
  Accepted-only publisher is paused so the 0.5.3 assets cannot be silently
  replaced after Apple finishes; a newly stapled public build needs a new version.

## Developer ID release preparation (2026-09-14)

- The supplied Developer ID Application certificate for team `8S66M2ZLD5`
  matches the public key in the locally generated FileMint CSR. macOS Keychain
  reports a valid code-signing identity for this certificate and its private key.
- The local `.cer` in `Config/Signing` has the same SHA-256 as the supplied file
  and is ignored by Git. It is not a signing private key.
- `make verify` passed before the distribution workflow change: 48 Swift tests
  and all 5 public harness cases.
- A disposable `0.5.99` Release package built both architectures and passed
  `verify_bundle.sh`. The Finder extension, main app and DMG each passed strict
  Developer ID signature checks for the intended identity and team, hardened
  runtime where applicable, and secure timestamps. `hdiutil verify` accepted
  the DMG. It was submitted to Apple as `fb386d9a-0ac0-4491-9c2a-1236c2c403c9`;
  at 2026-09-14 16:44 China time, Apple still reported `In Progress`. This test
  DMG is not a public release, and its notarization has not yet been verified.
- The exact identity was exported to an encrypted local `.p12`; its generated
  password is stored in the login Keychain. No signing identity was uploaded to
  GitHub. The empty `release-signing` environment created during exploration was
  removed after the decision to build locally; it had no secrets or deployments.
- The supplied Apple Team API key was parsed locally and validated by Apple's
  notary service, then stored in a local `notarytool` Keychain profile named
  `FileMint`. No notarization credential was added to GitHub.

## Full Disk Access guidance follow-up

Checked locally on 2026-09-13 after the report that the guide did not change
after permission was enabled:

- System Settings → Privacy & Security → Full Disk Access showed FileMint.app
  switched on. No privacy switch was changed during this verification.
- The old app only displayed setup instructions; it did not query this system
  permission. The revised guide says the system switch is authoritative,
  explains both enabled and off/missing cases, and explicitly says its continued
  visibility does not mean access is denied.
- Chinese and English native UI screenshots showed the full guide, folder list
  and folder actions without clipping. Saved folder authorization has its own
  label. The original Follow System language preference was restored afterwards.
- The confirmation button opened the Full Disk Access pane. Returning to the app
  retained the neutral explanation rather than manufacturing an enabled state.
- `make verify`, universal Release compilation, nested signatures and
  `verify_bundle.sh` passed. The verified app replaced the local
  `/Applications/FileMint.app` and was reopened with the new guide visible.
  Re-entering the system privacy pane still showed FileMint.app switched on.
- Temporary build registration was removed; PluginKit reported one enabled
  FileMint Finder extension, from `/Applications/FileMint.app`.

This verifies the visible macOS switch and the app's explanatory UI, not an
in-app Full Disk Access detection API or unrestricted access to every file.
Apple describes the independent sandbox and privacy restrictions, and the lack
of a TCC API surface, in [On File System Permissions](https://developer.apple.com/forums/thread/678819).
This follow-up updated the local app only; published DMG assets were not rebuilt
or republished as part of this change.

## About, online updates and creation-window isolation

Checked locally on 2026-09-13:

- `make verify` passed before the work (35 tests and 5 harness cases) and after
  implementation (46 tests in 4 suites and 5 harness cases). New coverage checks
  numeric versions, no downgrades, stable-only releases, exact repository/asset
  URLs, redirect hosts, absent/invalid checksums, mismatches and requested credits.
- `make verify-updates` used the actual app client against the public v0.2.0
  release. It received download bytes before cancellation, removed the partial
  download, retried successfully, checked all 3,946,055 bytes and SHA-256, and
  confirmed quarantine metadata. Temporary smoke artifacts were removed.
- Native About showed the installed version/build, `© XiaoDaiGua-Ray` and
  `XiaoDaiGua-Ray · GPT-Astra`. Chinese layout was visually inspected. Both
  languages' strings are covered by unit tests. The page's update button and the
  application-menu command returned the real up-to-date result for 0.2.0.
- A temporary build numbered 0.1.99 exercised the complete UI upgrade path
  against the real 0.2.0 release: available version and size, download progress,
  verification, installation guidance and Reopen Installer. Finder visibly
  opened the DMG containing FileMint.app, Applications and LICENSE.txt. The
  published app was not installed; the test disk image was ejected afterwards.
- Settings now has an explicitly owned, non-restorable AppKit window. A real
  Finder cold launch delivered the creation URL before did-finish-launching,
  with `NSApplication.launchIsDefaultUserInfoKey == false`; only the creation
  panel opened. A request with settings already closed behaved the same way.
- Repeating New File with an existing draft preserved its filename and focused
  the same panel. Cancelling left no visible app windows. Explicit app reopening
  still opened settings. The user's existing hidden-menu-bar preference remained
  off throughout, so these checks also cover that configuration.
- The UI driver reopens apps when asked to inspect an app with no windows. A
  temporary event-only diagnostic distinguished that driver action from a Finder
  URL: it reported a reopen with no visible windows after cancellation. These
  diagnostics recorded no paths/content and were removed from the implementation.
- Final `make package` rebuilt the normal 0.3.0 (3) version, validated the universal
  app and nested signatures, created a valid DMG and passed the portable SHA-256
  manifest check. The packaging staging directory was removed. The final app
  replaced the temporary 0.1.99 build in `/Applications/FileMint.app`, passed
  `verify_bundle.sh` there and reopened on About. Startup stayed enabled, the
  menu bar stayed hidden, and the Follow System language setting was preserved.

The tagged release workflow independently rebuilds, verifies and attests the
final uploaded bytes before publishing. No clean-Mac install, Intel execution or
macOS 13 runtime was performed in this follow-up; universal compilation targets
macOS 13+. The end-to-end update check used a test version number rather than
publishing a fake remote update.

## Dock lifetime and Finder menu disappearance

Checked locally on 2026-09-13 after the user's clarification that the Dock icon
belongs only to the settings window:

- The installed app's crash report at 14:05:22 showed `EXC_BREAKPOINT` in
  `FinderActions.open(_:activate:)` on `com.apple.launchservices.open-queue`.
  The callback inherited main-actor isolation and trapped even on success,
  terminating the extension after it had handed the request to the app. It is
  now explicitly `@Sendable`; only error presentation hops to the main actor.
  Apple's [NSWorkspace callback contract](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:))
  documents execution on a concurrent queue.
- The main app now launches with `LSUIElement = true`. Opening settings or About
  switches to `.regular`, and closing the settings window switches back to
  `.accessory`. Minimizing keeps `.regular` so settings remains reachable.
  A creation panel on its own does not change the policy or open settings.
- `make verify` passed before the change (46 tests) and after it (47 tests),
  plus all 5 public harness cases. The new test runs five independent menu
  snapshots through ticket consumption and actual file creation, checking
  incremented names, no replay and request cleanup. Universal Release build,
  ad-hoc nested signatures and `verify_bundle.sh` passed; bundle verification
  now requires the main app's accessory-launch flag.
- Native Finder background and file context menus were inspected through the
  accessibility tree. A disposable directory required its first folder
  authorization; the creation panel handled that flow without opening settings.
  Subsequent quick actions created `Untitled 2.txt` through `Untitled 5.txt`.
  All five files were checked on disk, each with the expected empty content.
  Fresh context menus continued to show FileMint after each action, and the
  same Finder extension process survived all app-launch completions.
- The live macOS `NSRunningApplication.activationPolicy` was `.accessory` after
  quick creation, with only the custom creation panel, and after closing
  settings. It was `.regular` with settings open and minimized. Creating again
  after closing settings kept `.accessory`. This is system runtime state
  evidence, not a captured Dock screenshot.
- Both quick and custom Finder routes were exercised from a cold main-app
  launch. Custom cold launch showed only the creation panel; cancellation kept
  settings closed. For this check the app process was confirmed absent first,
  and its activation policy was read before selecting it in the UI driver:
  inspecting a stale app handle while launch is pending can itself reopen
  settings and must not be attributed to the Finder request.
- No new Finder extension crash report appeared. The verified bundle replaced
  `/Applications/FileMint.app`; PluginKit reported one enabled registration,
  from that installed app. The temporary test-folder authorization was removed,
  and decoded preferences exactly matched their pre-test values, including the
  hidden menu bar, enabled login item, language and original folder bookmarks.

This follow-up updates the local app and source. Existing DMG files and published
GitHub release assets were not rebuilt or republished. The native checks ran on
this Apple silicon host; no Intel, macOS 13 or clean-Mac runtime claim is made.

## 0.4.0 release preparation

Checked locally on 2026-09-13 for the 0.4.0 release:

- The source defaults are `MARKETING_VERSION = 0.4.0` and
  `CURRENT_PROJECT_VERSION = 4`. The main app and Finder extension generated
  from the Release build both report version `0.4.0`.
- `make verify` passed: 47 Swift tests across four suites, including repeated
  Finder menu creation, and all five public JSON harness cases.
- `APP_VERSION=0.4.0 BUILD_NUMBER=4 make package` built a universal,
  ad-hoc-signed DMG. Nested-code verification, both architecture checks and
  the `LSUIElement` bundle assertion passed. `hdiutil verify` accepted the
  DMG, and its portable checksum was
  `12077691867d094f18b64f563f090183cc5303e2ad33bdde372264886019f654`.
- The release tag workflow rebuilds from this committed source, creates and
  verifies a distinct final DMG, creates a GitHub artifact attestation, and
  publishes the final checksum. The published asset's checksum and attestation
  are verified after that workflow completes; local and CI DMG bytes are not
  expected to match.

## 0.4.0 published release

Verified after publication on 2026-09-13:

- [GitHub Release v0.4.0](https://github.com/FileMintApp/FileMint/releases/tag/v0.4.0)
  is a non-draft, non-prerelease latest release for commit `9f663ea`.
- The [Release workflow](https://github.com/FileMintApp/FileMint/actions/runs/34743063797)
  completed its build, attestation and publication job successfully in 2m15s.
- The published `FileMint-0.4.0.dmg` is 4,263,439 bytes and its published
  SHA-256 is `6e6595c213e0d628c2cf3834ec41c2c9b50dc237f90349061f741c2368728031`.
  A fresh release download passed `shasum -a 256 -c` and `hdiutil verify`.
- `gh attestation verify FileMint-0.4.0.dmg --repo FileMintApp/FileMint`
  completed successfully against that downloaded DMG.

## GitHub 0.4.0 reinstall and competing development registrations

Investigated on 2026-09-13 after a report that the GitHub DMG still lost its
Finder menu after creation:

- The user-provided `Downloads/FileMint-0.4.0.dmg` and a fresh GitHub download
  both matched the published SHA-256 above. The release was built with Xcode
  16.4 and reports build 3; the earlier local build used the newer local Xcode
  and build 4. Version labels alone do not identify the active extension copy.
- At 14:41:04, `launchd` explicitly reported an attempt to bootstrap the same
  Finder extension from two paths: an existing `build/DerivedData/.../FileMint.app`
  and a conflicting `/Applications/FileMint.app`. It retained the development
  path. At 14:41:12, PluginKit removed the extension instances and Finder logged
  an interrupted connection. There was no new Swift crash report for this event.
- The release preparation had created and registered another development app
  after the previous cleanup. Both that app and the standalone build extension
  were saved as ZIP backups, unregistered where present, and removed from the
  discoverable build directory. The installed app was restored from the exact
  published DMG; main-app and extension executable bytes were compared with it.
- Real Finder checks with the GitHub app created `Untitled.txt` through
  `Untitled 10.txt`, plus a custom file containing exact Unicode and literal
  `{{year}}` text. Background and file context menus remained available after
  creation. All processes inspected pointed to `/Applications/FileMint.app`,
  and PluginKit listed one installed registration. No new extension crash
  report appeared. The same installed extension instances survived the checks.
- Packaging now owns a fresh temporary build under `build/package-work.noindex`.
  Its exit handler unregisters only those temporary app/extension paths and
  removes the temporary directory. `make build` retains its separate development
  output. A full successful package and a deliberately failing signing attempt
  both left no temporary bundle or registration, while the installed app kept
  working through five more consecutive quick creations. The failure test used
  a nonexistent signing identity and failed at signing as intended.
- `make verify` passed before and after: 47 tests and 5 public harness cases.
  Release compilation and successful DMG packaging passed. Test folder access
  was removed afterwards; the decoded preferences matched the values before
  this round's folder authorization. Preferences had been removed during the
  user's uninstall, so this round began with fresh application defaults.
- In-app updates download and verify a DMG, then open it for manual replacement.
  They do not copy an app into the development directory. Their old handoff text
  omitted ejecting the installer volume; the revised Chinese and English text
  adds ejecting it and reopening the installed copy from Applications. Cache
  deletion is not an eject operation, and an open installer is not proof of a
  completed installation. This is a separate handoff gap, not the development
  path conflict proven by the system log.

The installed and tested app remains the original published 0.4.0. These build
workflow and instruction changes do not replace existing GitHub release assets
or claim to add an automatic installer. The updated in-app text will ship with
the next application release.

## 0.5.0 release preparation

Prepared on 2026-09-13:

- The application version and local packaging defaults are now `0.5.0` (build 5).
  The Release workflow continues to use its run number for the published build.
  This release includes the isolated packaging cleanup and bilingual installer
  ejection guidance described above; installation still requires manual app
  replacement.
- `make verify` passed before and after the version update: 47 Swift tests and
  all 5 public harness cases. `APP_VERSION=0.5.0 BUILD_NUMBER=5 make package`
  passed universal build, nested ad-hoc signatures, bundle checks and DMG
  verification. Its local checksum is
  `5b4acae4d6bb06f8127870cb717607f75f67b9987e56a09b4787c27286915e91`.
- Packaging removed its temporary directory and extension registration.
  PluginKit still listed only `/Applications/FileMint.app` version `0.4.0`.
  The installed main-app and extension executable SHA-256 hashes were unchanged,
  preserving the user's requested baseline for testing the online update.

## 0.5.0 published release and update-client verification

Verified on 2026-09-13:

- [Release v0.5.0](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.0)
  is the latest non-draft, non-prerelease release. Tag `v0.5.0` points to
  `ca9c2a9578fe96f96c88afa2fa105657493e768c`.
- The [Release workflow](https://github.com/FileMintApp/FileMint/actions/runs/34757935781)
  completed successfully in 1m46s. The published app is `0.5.0` (build 4).
- The public DMG is 4,263,537 bytes with SHA-256
  `7b6d2d72cc95c4f09a6bf65ac72e0335ffc0faffe10a47dde9e89591d5136969`.
  A fresh download matched its checksum file and the GitHub asset digest.
  Attestation verification passed with the exact release source digest,
  `refs/tags/v0.5.0` and the repository's Release workflow as constraints.
- The downloaded DMG was mounted read-only without opening Finder or running
  its app. `verify_bundle.sh` passed the nested signatures, universal binaries,
  matching app/extension versions and accessory-launch flag. The volume was
  ejected immediately after inspection.
- The same `UpdateClient` and update policy used in 0.4.0 returned the public
  0.5.0 update when checked with current version `0.4.0`. `make verify-updates`
  then passed the live same-version check, cancellation after receiving bytes,
  partial-download cleanup, full retry, checksum/size verification, quarantine
  preservation and installer cleanup.
- No app was installed during these checks. The local GitHub 0.4.0 app and its
  extension remain the user's baseline for their manual online-update test.
  These client and artifact checks do not claim completion of the user's
  Finder replacement/ejection/relaunch flow.

## 0.5.1 sandbox download authorization fix

Investigated and checked on 2026-09-13 after the user completed a real in-app
0.4.0 → 0.5.0 download and Finder replacement:

- The installed app was version 0.5.0 (build 4), executable permissions were
  correct, and strict nested code-signature verification passed. The cached DMG
  matched the published 4,263,537-byte artifact and SHA-256. The failure was not
  damaged download bytes: the installed executable had quarantine `0387`, and
  the kernel denied execution as created without user consent. `spctl` reported
  “File created by an AppSandbox, exec/open not allowed”.
- A real sandboxed diagnostic reproduced `0086` after writing into private
  cache and `0287` after adding download metadata. Selecting the destination
  through NSSavePanel instead produced `0082` after writing and `0283` after
  download metadata, including with atomic writes. Apple's [DTS explanation](https://developer.apple.com/forums/thread/767612)
  identifies the sandbox no-user-consent bit as an execution block separate
  from ordinary Gatekeeper approval.
- The user installation was recovered by downloading the same public artifact
  with system save authorization, copying it with Finder and ejecting the
  installer. The recovered app retained internet quarantine (`0383`), matched
  the source executable bytes and opened normally. No quarantine attributes,
  sandbox restrictions or Gatekeeper protections were removed.
- The production updater now gets a save-panel destination before downloading,
  uses cache only for partial download and verification, and atomically writes
  fresh verified bytes to the authorized URL. It does not move cache quarantine
  into the user's installer. Saved installers retain their checksum proof and
  are revalidated before every open. A known execution block or changed saved
  file prevents opening; completed user-saved files are not automatically deleted.
- `make verify` passed before the change (47 tests) and after it (48 tests), plus
  all five harness cases. `make verify-updates` passed cancellation after bytes
  arrived, preservation of an existing destination, cache cleanup, full retry,
  normal quarantine and rejection of a modified saved installer on reopening.
- The new interactive sandbox harness uses the actual production UpdateClient.
  It rejected an unapproved container save, started no download after cancelling
  the system save panel, and saved/validated the public installer with quarantine
  `0283` after save-panel confirmation. It has the existing sandbox/network/
  user-selected-file permissions, with no executable-writing entitlement.
- A temporary, unpublished build numbered 0.4.99 (600) then exercised the full
  FileMint About interface against public 0.5.0. Cancelling the save panel left
  the available update intact. Confirming a destination showed progress, verified
  and opened the DMG, and offered Reopen Installer. The on-disk installer matched
  the public hash and had quarantine `0283`. Both temporary test volumes were
  ejected after the test; the 0.4.99 build is not a release.
- Local 0.5.1 (build 6) universal packaging and nested signatures passed, with
  DMG SHA-256 `c3e5ef7d7204fd77ba90ac07270d364f45b8dffcac5e90be6d5575d3b88ea783`.
  Build and staging app registrations were cleaned by the packaging exit handler.

These checks supersede the earlier assumption that non-sandboxed update smoke
tests could validate the installed application's download-to-launch behavior.
The old 0.3.0–0.5.0 updater cannot acquire this fix before replacing itself;
release/install instructions require a fresh browser download for that upgrade.

## Published 0.5.1 installation verification

- [Release v0.5.1](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.1)
  was published from `47ae1ebcd7d2ed81c1f21a530cdb229dac906287` by the successful
  [Release workflow](https://github.com/FileMintApp/FileMint/actions/runs/34760784869).
  Its public DMG is 4,288,842 bytes with SHA-256
  `e03889baa63f62653ed098ef61a1d3dc835e5451d0d71599aefd7d59e029aa08`.
- The actual sandbox regression client downloaded that public release through
  a confirmed system save dialog into `Downloads/FileMint-0.5.1.dmg`. Quarantine
  was `0283`. The public checksum and an attestation constrained to the exact
  release tag, commit and Release workflow passed.
- Strict nested signatures, universal architectures and app/extension versions
  passed on the mounted public bundle. Finder then replaced the installed app;
  the installed executable matched the mounted original bytes. The volume was
  ejected before launch. No quarantine flag was removed or rewritten.
- The installed app retained normal internet quarantine (`0383`, then `03c3`
  after launch). The running LaunchServices record reported 0.5.1 (build 5),
  the process finished launching, and its native creation panel was visible.
  A user-owned draft in that panel was left untouched.
- PluginKit listed one enabled 0.5.1 extension under `/Applications/FileMint.app`.
  Diagnostic processes had exited; their temporary builds, unpublished 0.4.99
  installers and test caches were cleaned up. The public 0.5.1 installer remains
  in Downloads. Existing app settings were not reset.


## 2026-09-22 — Creation workflow implementation, isolated fixtures

Worktree based on `4788db0`, macOS 27.2 / Apple silicon, Xcode. These observations
cover the development worktree, not the installed Finder extension or a release.

- [Clipboard image task](tasks/2026-09-22-clipboard-image.md): native synthetic
  PNG preview, 1600×1000 output, identical numbered copy and cancel-without-write;
  real PNG/TIFF encoding and alpha/orientation regression coverage.
- [Multiple-template task](tasks/2026-09-22-multiple-templates.md): same-suffix
  choices, persisted format default, independent name/content, exact native
  meeting-note output. Tab/Shift-Tab cycles through text/image controls, skips
  disabled controls and preserves content; Cmd-Return still creates.
- [Office-template task](tasks/2026-09-22-document-templates.md): native DOCX/XLSX
  import, managed reference readback, exact-byte native creation and numbered
  output. Independent document readers verified text, formatting and a formula.
  Chinese/light and English/dark surfaces inspected; template settings fit 840×600.
- Final `make verify`: 137 Core + 13 image tests, 5 public cases, 10 CLI and 3
  appcast tests passed (`/tmp/filemint-final-verify.log`). Unsigned universal
  build passed (`/tmp/filemint-final-build.log`).
- Installed Finder callbacks, sandbox permission cancellation, macOS 13/Intel
  runtime and Microsoft Office runtime remain not run. No installation, Developer ID signing,
  commit or publication was performed.

## 2026-09-23 — Published 0.5.10

The [0.5.10 release verification](RELEASE_VERIFICATION_0.5.10.md) records the
clean tagged build, Accepted Apple notarization, stapled DMG, downloaded GitHub
asset comparison, successful CI/site/release jobs and native acceptance. An
isolated copy of public 0.5.9 upgraded through the production About UI and
public feed to 0.5.10 (18), replacing and relaunching at the same temporary
path. The user's `/Applications/FileMint.app` remained at 0.5.9; installed
Finder refresh, Intel/macOS 13 and managed-device paths remain untested.

## 2026-09-24 — Published 0.6.0

The [0.6.0 release verification](RELEASE_VERIFICATION_0.6.0.md) records the
Accepted and stapled arm64-only candidate, exact published asset comparisons,
successful source/release/Pages workflows, and public 0.5.10 → 0.6.0 update.
The original `/Applications/FileMint.app` and loaded Finder extension remained
at 0.5.10. Installed 0.6.0 Finder callbacks, Intel and macOS 13 runtime, and
managed-device authorization remain unverified.

## 2026-09-28 — Full-review fixes and isolated favorites QA

Tested `684dba2` plus the existing favorite-location repair and this worktree's
[review fixes](tasks/2026-09-28-review-fixes.md). No installed app was replaced.

- `make verify` passed: 164 Core tests, 14 image tests, 5 public Harness cases,
  10 CLI checks, and appcast/release/notarization/signing/context checks. New cases
  cover ordinary-quit busy states, preserved POSIX permission errors, extreme
  template ranks, serialized off-main catalog edits, cleared recent entries and
  notarization recovery before/after stapling. Apple commands were local stubs.
- Unsigned Release app and Finder extension build passed. Move and Open with App
  sandbox QA entrypoints compile and sign their isolated fixtures again; their
  interactive authorization/receiver flows were not rerun here.
- `make verify-favorite-model` passed with a private 1,000-entry catalog, concurrent
  edits, atomic name/group changes, policy rejection, damage backup/reset and busy
  guard release. It does not read real preferences or favorite catalogs.
- Isolated native UI (`build/design-ui-harness.noindex/run.UAlSEC`, then the final
  `run.KEV5TR`) confirmed clearing Recent preserves All, pinning updates the row,
  and name/group editing saves both values. Quick-search QA exposed position-ID
  row reuse; after switching to UUIDs, searching `Lake` showed only `Lake.png`,
  Return closed the palette and Finder selected that exact fixture file. Saved
  catalog readback confirmed its locate timestamp and subsequent name/group edit.
- Build/UI evidence is scoped to these fixtures. Installed Finder callbacks,
  macOS 13 runtime, TCC authorization prompts, actual notarization and public
  release/update acceptance were not exercised. No commit, push or publication.
