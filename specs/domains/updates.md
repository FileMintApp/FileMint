# About and updates

Load for: About content, automatic/manual release checks, downloads and installer handoff.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## About and online updates

- Settings includes an About / 关于 page with the app icon, installed version
  and build, copyright `XiaoDaiGua-Ray`, and developers `XiaoDaiGua-Ray` and
  `GPT-Astra`. Names are preserved verbatim in both languages. The application
  About menu opens this same page. Project, license and privacy links are visible.
- About and both README languages include Special Thanks / 特别感谢 to `阿逼`,
  linking to `https://github.com/bibinocode`, for help with Developer ID signing
  and Apple notarization. Preserve the nickname verbatim in both languages.
- About, the application menu and the menu bar offer Check for Updates. General
  includes Automatically check for updates, enabled for new and older settings
  unless an explicit off value has been saved. Manual checks work with it off.
- While the main app is running, automatic checks request only release metadata
  at most once per seven days. The first overdue check waits at least 60 seconds
  after startup or enabling the switch. Use a one-shot timer for the next due
  check, not frequent polling; no helper launches the app just to check.
  Persist the attempt time before each check, including manual checks, failures
  and cancellations, so relaunches, wake and switching off/on do not trigger
  repeated requests. A future timestamp after clock rollback waits one interval
  from the corrected time. If persistence fails, skip automatic networking.
- Disabling the switch cancels scheduled and in-flight automatic checks, leaving
  manual checks and downloads alone. Automatic work never overlaps an existing
  operation or active modal window, or discards an offered update.
  No-update results and failures remain quiet; errors are visible in About and
  never represented as success. A new version appears in settings and the menu
  bar menu without opening a window, stealing focus or downloading anything.
  Only the main app has the outbound-network entitlement; Finder stays offline.
- Use the public latest stable release of `FileMintApp/FileMint` on GitHub.
  Compare the three numeric version components, never lexicographically. Equal
  or older versions do not offer a download; malformed versions and responses
  show an error rather than claiming the app is current.
- A newer release must contain the matching `FileMint-VERSION.dmg` and
  `FileMint-VERSION.dmg.sha256` assets. Only HTTPS release URLs from this exact
  repository are accepted; redirects are limited to GitHub's release hosts.
- Show the available version and release notes link before downloading. The user
  chooses Update and Restart once; the app then downloads, verifies, installs and
  relaunches without a save panel, Finder drag-and-drop or a second restart prompt.
  System administrator authorization may still be necessary for protected installs.
- Use pinned Sparkle 2 for installation, with a custom visible About-page user
  driver. This dependency provides the signed installer/XPC, bundle replacement
  and relaunch lifecycle that the sandboxed main app cannot safely implement alone.
  Keep the main app and Finder extension sandboxed. Enable only Sparkle's installer
  XPC service and its two scoped Mach lookup exceptions; retain main-app networking.
- Keep the existing GitHub metadata discovery and weekly scheduler. Sparkle's own
  automatic checks, automatic downloads and system profiling are disabled. Start
  Sparkle only for an explicit install request, using the selected release's
  immutable appcast.xml asset, not a moving latest feed. Bind the offered item to
  the selected version, exact DMG URL and size; reject mismatches, informational
  items, deltas and downgrades. Require an EdDSA archive signature before extraction.
  An Apple-silicon-only release appcast declares Sparkle's arm64 hardware
  requirement, so older Intel clients cannot install a release they cannot run.
  Existing Intel clients may still discover a newer GitHub release before
  Sparkle filters its appcast; this must not be presented as installed success.
  The appcast minimum macOS version matches the app's deployment target.
  Apple signing/notarization remains required for public releases. SHA-256 files
  remain available for older clients and manual downloads.
- Show progress and cancellation during checking/download. Disable cancellation
  once extraction/installation begins; do not claim cancellation after commit.
  Failures remain visible and retryable, with a release-page fallback. Never report
  installation success just because a download or extraction finished.
- Before starting, and again before relaunch, defer installation while a creation
  draft, file operation or modal sheet is active. Preserve the draft and let the
  user choose Update and Restart after finishing it. Do not force-kill Finder,
  discard work, alter preferences/bookmarks or silently enable the Finder extension.
- Sparkle owns update staging, signature checks, replacement, cleanup and relaunch.
  Never hand a sandbox-created private-cache DMG from the legacy UpdateClient to
  the installer or strip quarantine to bypass a macOS execution block.
- Existing clients without Sparkle need one manual installation of the first
  Sparkle-enabled release; later upgrades use the automatic replacement path.
  Released 0.5.7/0.5.8 also require manual installation of 0.5.9: their installed
  signatures contain incorrect installer Mach permissions, which cannot be
  repaired through an update feed. Keep this migration limit explicit in release
  and installation guidance.
  Keep the legacy download client and smoke harness for testing old-client
  compatibility, not as a second production installation path.
- Verify this from a real sandboxed app with signed old/new bundles. Core tests
  and a successful build do not prove helper launch, replacement, relaunch or
  Finder extension refresh on an installed system.

## Working context

- Implementation entry points: `App/FileMint/AboutPane.swift`, `UpdateModel.swift`, `UpdateClient.swift`; `AppUpdate.swift`, `AutomaticUpdatePolicy.swift`, `InstallerQuarantinePolicy.swift`; updater preferences/localization and `scripts/*update*`.
- Verification: [Update checks](../verification/updates.md), loaded when planning or performing updater verification.
- Expand context only when needed: Load [startup](startup.md) if scheduling changes app lifecycle or shared preferences; [distribution](distribution.md) when changing published asset/signing contracts.
