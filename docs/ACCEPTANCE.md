# FileMint 0.5 acceptance

Checked on 2026-09-14, macOS 26.6.2, Apple silicon. Minimum deployment target:
macOS 13. Release bundles contain arm64 and x86_64 executables.

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
