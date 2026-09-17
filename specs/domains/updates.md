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
  operation or save panel, or discards an offered update or verified installer.
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
- Show the available version and release notes link before downloading. Download
  only after the user chooses it and confirms a destination in the system save
  panel. Cancelling that panel starts no download. Downloads retain progress,
  cancellation and retry. Network
  work and file hashing run away from the main thread. Duplicate operations and
  stale callbacks must not replace the current state.
- Check the downloaded size and SHA-256 against the matching checksum file,
  also checking GitHub's asset digest when provided. Missing, malformed or
  mismatched checksums prevent opening. This checks download integrity; it does
  not claim Apple notarization or automatically verify a GitHub attestation.
- Use the private cache only for partial downloads and verification. After all
  checks pass, atomically write fresh bytes to the exact save-panel-authorized
  URL, preserving existing destination content until verification succeeds.
  Never open or move a private-cache DMG directly into the installation flow:
  sandbox-created cache files can carry a no-user-consent execution block.
- Mark the saved DMG as an internet download and check that quarantine is
  present without the sandbox no-user-consent execution block before opening it.
  Never clear quarantine, disable the sandbox, or strip Gatekeeper protections.
  Keep the saved URL accessible for reopening during the session. Temporary
  downloads are removed on success, cancellation and failure; completed files
  in the user's chosen location are theirs and are not automatically removed.
  Old update cache files are cleared on the next download. Downloaded release
  notes are never rendered as executable HTML.
- Revalidate the saved installer's size, checksum and quarantine before every
  open, including reopening it later in the session; changed or replaced files
  must not be opened as previously verified downloads.
- Run the update client from a real sandboxed app with the system save panel
  when verifying download-to-install behavior. Command-line network/checksum
  tests alone do not prove that macOS will allow the saved installer to run.
- Opening the DMG is not installation completion. Explain that the user must quit
  FileMint, drag the new app into Applications to replace it, then reopen it.
  The installation handoff must also tell users to eject the FileMint installer
  volume after copying, then reopen the installed app from Applications. A
  downloaded DMG cache is not an installed app, and removing that cache is not
  proof that an installer volume has been ejected.
  Report disk-image opening failures and offer reopening or the release page.
  Do not replace the running app, alter user preferences, or quit automatically.

## Working context

- Implementation entry points: `App/FileMint/AboutPane.swift`, `UpdateModel.swift`, `UpdateClient.swift`; `AppUpdate.swift`, `AutomaticUpdatePolicy.swift`, `InstallerQuarantinePolicy.swift`; updater preferences/localization and `scripts/*update*`.
- Verification: [Update checks](../verification/updates.md), loaded when planning or performing updater verification.
- Expand context only when needed: Load [startup](startup.md) if scheduling changes app lifecycle or shared preferences; [distribution](distribution.md) when changing published asset/signing contracts.
