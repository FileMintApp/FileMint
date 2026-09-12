# FileMint 0.2 acceptance

Checked on 2026-09-13, macOS 26.6.2, Apple silicon. Minimum deployment target:
macOS 13. Release bundles contain arm64 and x86_64 executables.

## Automated verification

- 34 Swift Testing cases pass, plus all 5 public JSON harness cases.
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
