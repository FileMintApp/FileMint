# FileMint 0.3 acceptance

Checked on 2026-09-13, macOS 26.6.2, Apple silicon. Minimum deployment target:
macOS 13. Release bundles contain arm64 and x86_64 executables.

## Automated verification

- 46 Swift Testing tests pass, including update validation and bilingual About
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

GitHub workflows build, verify and attest the final DMG before publishing. GitHub
build provenance is not Apple notarization. First-launch and Finder extension
approval remain subject to macOS policy and are explained in INSTALL.md.

Intel execution, reboot/login execution and a clean-Mac first install were not
performed on this host. Universal compilation, native login registration/status,
and the actual runtime checks above are the evidence available here. The final
release download and its attestation are verified separately after publication.

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
