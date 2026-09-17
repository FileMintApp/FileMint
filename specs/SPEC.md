# FileMint SPEC

## Product promise — 0.5

A small, native macOS utility that creates a file where the user is already working.
Fast Finder actions, a compact keyboard-friendly creation panel, and no account,
analytics, folder crawling, or clipboard monitoring. File creation works offline;
optional low-frequency update checks and user-requested downloads use the network.

## The two creation paths

- Finder → New File → a file type creates immediately in the captured target
  directory. Menu labels include the extension. The top-level entry shows the
  FileMint logo plus localized “New File” / “新建文件”; submenu rows remain text only.
- Finder → New File → New File… opens one compact persistent native panel.
  Name, editable extension selector, destination, optional plain-text content,
  Cancel and Create are the whole flow. The main app owns this single panel;
  Finder forwards only the target directory for drafts, so requests from either entry point
  focus the same draft. A draft route never writes a file without Create.
  Quick actions instead enqueue an expiring, single-use local request and pass
  its random identifier to the app. The app consumes it only for an enabled
  template and a configured folder; a bare deep link cannot create a file.
- The app and its menu bar also offer New File… with a native folder picker,
  so creation remains useful without Finder integration.
- Creation requests open or focus only the single creation panel. A Finder URL
  must not open or restore settings, including a cold launch or a request after
  settings was closed. Closing/cancelling the panel leaves settings closed.
  Settings is a separately owned native window, shown by an ordinary app
  launch or explicit Open FileMint / About / Settings actions, with no automatic
  SwiftUI primary-window creation or restoration during URL handling.
- Return creates from single-line fields; Return in the content editor inserts a
  newline; Command-Return creates anywhere; Escape cancels; Tab moves focus.
- The editor supports standard copy/paste, select-all and undo. A visible Paste
  button inserts clipboard text at the selection. Clipboard is read only at the
  user's explicit paste action. Non-text clipboard data produces a short message.
- Typed/pasted content is written as exact UTF-8, including whitespace, Unicode,
  and literal `{{fileName}}` or `{{year}}`. Changing the extension preserves it.
- All code/content editors disable smart quotes, dashes and text replacement.
  Template token expansion is a single pass; tokens inside a substituted filename
  are literal data and are never expanded again.
- Until content is edited, known formats seed their saved template content and
  render supported placeholders (`{{fileName}}`, `{{date}}`, `{{isoDate}}`, `{{year}}`).
  Date placeholders use UTC for deterministic output.
- The extension selector searches preset names, aliases and saved custom types.
  Its menu can always show all choices, even after a format has been selected.
- A full filename typed or pasted into Name is authoritative: `demo.js` is saved
  as exactly `demo.js`, and synchronizes the extension selector to `js`, even if
  that type is disabled or not saved. Selecting another format then updates the
  displayed filename. Typing just `demo` appends the currently selected suffix.
- Custom extensions are text-file suffixes, not converters for binary formats.
  Empty suffixes, whitespace, controls, path separators, trailing dots and empty
  extension components are invalid. Surrounding whitespace and leading dots are
  normalized. The most recently edited name or suffix wins; changing a compound suffix
  replaces the entire prior suffix. File names cannot escape the destination.
- Drafts are not stored. Cancelling never creates a file or changes the destination.

## File types

- Presets: txt, md, swift, json, html, css, sh, csv, yaml, xml, js, ts, py, sql.
  The original seven are visible by default; additional presets can be enabled.
- Settings → File Types can add/edit/remove saved custom types, including a
  display name, suffix and optional initial template content. Duplicate suffixes
  are rejected case-insensitively. Changes persist and refresh Finder without
  restarting the app. Enabled types are shared by quick actions and the picker.
- Users can enable/disable and reorder types. Built-in templates have stable IDs.
  Restoring built-ins preserves custom types and requires a confirmation.
- Older preferences retain language, folder selection, template customizations,
  enabled state and order; newly added presets are appended disabled.
- Do not expose nonfunctional favorites, icon toggles, themes or dashboards.

## Safe creation and performance

- Normal creation uses exclusive filesystem creation, never check-then-overwrite.
  Racing creations retry the next incremented name without overwriting data.
- Default collision names: `Untitled.txt`, `Untitled 2.txt`, `Untitled 3.txt`.
- Quick creation supports increment or fail. Replace is never a stored default.
- Custom creation asks before replacement, with Cancel as the default button.
  A directory is never replaced. Replacement atomically replaces the directory
  entry, not the content of a symlink's target.
- Finder captures the destination with the menu action, rather than resolving a
  potentially different target later. No path or clipboard content is logged.
- A background context menu uses Finder's container URL directly, including
  Desktop; missing sandbox metadata must never turn that directory into its
  parent. Missing targets never guess another destination.
- After either creation route, the Finder extension remains available for the
  next context menu and creation. App-launch completion callbacks may run on a
  background queue; they must not inherit main-actor isolation. Error UI is
  dispatched explicitly to the main actor.
- Preference refresh is notification-driven, with no polling timers or background
  directory enumeration. File I/O runs away from the main thread, and duplicate submission
  is disabled until it completes. An actionable error keeps the draft intact.

## Folders and permissions

- Finder menus include the current user's real home directory and its children
  by default, plus folders explicitly added by the user. Resolve the home URL
  from the operating system, never by a username, display label or fixed
  `/Users/...` path. Keep Desktop, Documents and Downloads as separate folder
  authorization entries. Older settings retaining all three original defaults
  gain the dynamic home entry once; restricted folder selections and subsequent
  removal of the home entry remain authoritative. When Desktop or Documents is in
  scope, register the real user's home as a Finder observation ancestor so
  protected-folder callbacks can arrive. This registration grants no filesystem
  access. Both menus and quick requests must still check the configured folder
  scope; unrelated home folders receive no FileMint menu. Never scan directory
  contents or badge files, and do not request broad filesystem entitlements.
- Folder selection uses NSOpenPanel. Persist security-scoped bookmarks alongside
  paths, restore access on launch, and release access when folders are removed.
- Preferences are an atomically replaced private JSON file in
  `~/Library/Application Support/FileMint`. Both sandboxed targets have an
  exception scoped only to this application-owned directory. No App Group or
  broad filesystem entitlement is required by the GitHub provenance channel.
  Only the main app writes preferences and destination files. Finder writes
  short-lived request tickets, not user files. Old development App Group data
  is left untouched; users can explicitly import an old JSON/plist settings file
  via the app's File menu. Never silently read a protected legacy container.
- Existing preferences without bookmarks still load. If a write lacks permission,
  hand the draft to the main app, authorize the destination using a directory
  picker there, and retry after the user chooses Create. All creation and
  authorization panels belong to the main app, not Finder extension processes.
- Settings give short instructions for enabling the extension (macOS 15+:
  General → Login Items & Extensions → Finder; older systems: Privacy & Security
  → Extensions). Show actual extension status when the system API is available.
- macOS discovers and loads the bundled Finder extension; its enabled state is
  controlled by the user. Explain this in the setup guide and open the system
  extension management UI on request. Do not use private APIs or `pluginkit` to
  silently enable it from the sandboxed app. Refresh actual status on returning.
- Finder APIs remain in FinderSyncExtension; deterministic rules in CorePackage;
  SwiftUI settings remain in App/FileMint. Shared AppKit creation UI may be
  compiled into both app and extension.

## Startup and menu bar

- FileMint starts as an accessory app. Explicitly opening settings (including
  About or an ordinary Applications/Spotlight launch) shows its Dock icon for
  that window's lifetime, including while minimized. Closing settings removes
  the Dock icon and keeps Finder integration available. Finder creation never
  opens settings or adds a Dock icon; the creation panel alone stays accessory.
- Launch at login and Show in menu bar default to enabled. Both have persistent
  switches in General. A saved off value must survive upgrades and relaunches.
- Use macOS 13+ SMAppService.mainApp for login registration. Request the default
  once after the app has been placed in /Applications or ~/Applications and
  launched. Do not register development builds or a mounted DMG as login items.
- Display actual service status: active, off, awaiting system approval, unavailable
  or failed. A stored preference alone is never proof of successful registration.
- Respect changes in macOS Login Items; do not silently re-register after the
  user disables/removes the item there. Offer an explicit retry/settings action.
- Hiding the menu bar item takes effect immediately and persists. Opening the app
  from Applications or Spotlight keeps settings reachable. Finder URL actions continue to work when the
  settings window is closed or the menu bar item is hidden.
- New preferences follow the system's supported language; explicit saved English
  or Chinese choices remain authoritative. Users can also select Follow System.
- Folder settings include an optional Full Disk Access guide and a button to
  open its macOS privacy pane: add the installed FileMint.app, enable it, then
  quit and reopen FileMint. Never silently change this system permission.
- The Full Disk Access guide explicitly says that FileMint cannot automatically
  read the system switch, and that the guide remaining visible does not mean
  access is denied. System Settings is the authority: an enabled FileMint switch
  means permission was granted; quit and reopen after enabling, without adding
  the app again. Explain the off/missing-entry case separately. Never infer this
  permission from folder access, saved preferences, or opening System Settings.
- Folder rows describe only their own saved folder authorization, using
  “Folder access saved” or “Choose this folder once”; neither label represents
  Full Disk Access or guarantees a future write will succeed.
- Explain the difference between privacy access and sandbox folder access:
  Full Disk Access does not remove sandbox requirements; folder bookmarks are
  remembered so normal use should not require repeated folder selection.

## Local extension maintenance

- Remove only confirmed obsolete FileMint application/extension registrations
  and their disposable old build bundles. Do not reset global LaunchServices,
  PluginKit, background-item or privacy databases.
- Preserve source, user preferences and created files. Keep one installed current
  FileMint.app; remove staging bundles after DMG packaging to avoid duplicate
  registration from a packaging directory. Verify registrations after cleanup.
- Packaging uses a separate temporary build directory. On success or failure,
  unregister only its own temporary app/extension and remove that directory, so
  a packaged development copy cannot compete with an installed release. Keep
  ordinary development builds, installed apps, preferences and DMGs outside
  that cleanup. Validate the downloaded release itself in Finder when checking
  a user-reported installation regression.

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

## Appearance

- Native controls and system colors. Compact settings with General, File Types,
  Folders and About. No decorative cards. Follow system language by default; English
  and Chinese can be selected explicitly.
- Only the top-level Finder entry has the small FileMint logo; its label maps
  to the resolved app language. Format choices, submenu rows and creation
  controls use text only. The Finder
  toolbar and macOS menu bar retain the small template glyph those entry points
  require. No icon preference.
- App logo: a distinctive folded-paper F in fresh mint on a warm porcelain
  macOS tile. Dock/application assets use the image master; menu bar and Finder
  toolbar use a separately drawn crisp monochrome F silhouette. No medical-style
  plus badge. `make icon` regenerates the asset catalog from the masters.
  The generated Xcode project is never edited directly.

## Distribution and product presentation

- macOS 13+; universal arm64 + x86_64 Release app and DMG on GitHub Releases.
- The owner explicitly chose to publish 0.5.3 while its existing `notarytool`
  submission was still `In Progress`. This one release uses the authorized
  Developer ID Application identity for the app, Finder extension and DMG,
  hardened runtime and secure timestamps, but had no stapled Apple notarization
  ticket at publication. A later query returned `Accepted` for the exact
  published DMG under submission `11ed351a-020e-4107-bfae-72d0a8daec52`.
  Apple publishes that ticket online, so Gatekeeper can retrieve it for the
  unchanged DMG when the Mac is connected, including copies downloaded before
  acceptance. The release page, README and installation guide must preserve
  this chronology and explain that the existing asset still has no stapled
  ticket, so offline verification can fail. The SHA-256 file establishes byte
  integrity, not ticket presence or permission to launch. Do not replace the
  published 0.5.3 bytes after the fact.
- Public stable releases after 0.5.3 require Apple notarization on the owner's
  Mac. Staple and validate the DMG ticket before computing its portable SHA-256
  checksum. Only the validated local DMG and checksum are uploaded to GitHub
  Releases. Missing credentials, rejected notarization or failed validation
  must stop publication.
- GitHub Releases remain the distribution channel. GitHub CI verifies the core
  without holding Apple signing assets or rebuilding the public DMG. A locally
  built release is not represented as a GitHub Actions build or GitHub build
  attestation. Existing published versions retain their original trust
  limitations; documentation must distinguish them from the first notarized
  release. Never tell users to disable Gatekeeper globally. Finder extension
  enablement remains a separate system action.
- The Developer ID certificate stays in the project's ignored local signing
  directory. The certificate, private key, exported signing identity and Apple
  notarization credentials must remain local and never be committed, uploaded
  to GitHub Actions secrets or bundled in the app.
- Before publishing, local release checks verify the source tag, clean checkout,
  both architectures, nested signatures, DMG integrity and final checksum. The
  one-time 0.5.3 exception additionally checked and recorded the actual Apple
  `In Progress` state at publication; the later `Accepted` result establishes
  an online ticket but does not retroactively staple the uploaded DMG. Later
  releases require local ticket validation before upload. A published-release
  GitHub job may re-check the uploaded bytes without building them or claiming
  build provenance.
- README leads with the pain solved, actual features, screenshots, download and
  a brief install guide. Chinese first, English separate. Developer instructions
  live in docs. Optional donations link the supplied ReceivePayment images.
- Both README languages and website homepages show a future roadmap as grouped
  TODO checklists. Describe concrete user outcomes without priorities, release
  assignments or delivery dates, and distinguish planned work from available
  features. Website checklists reuse the corresponding README content. Keep
  implementation guidance and completion criteria in docs/ROADMAP.md; checking
  off an item requires its implementation and verification to be complete.
- Non-commercial use is free for everyone, including personal, educational and
  research use. Commercial use, commercial redistribution and commercial
  derivatives require prior written authorization or a separately issued paid
  commercial license. Donations alone grant no commercial rights. Include the
  license in the app and DMG; do not label this as MIT or OSI open source.
- Keep the privacy policy.
  Do not promise valid Office/PDF/image output from a custom suffix.

## Completion evidence

Update SPEC before behavior, cover naming/templates/creation/preferences in
CorePackage tests or the public JSON harness, run `make verify` before and after,
build Release, inspect the native UI, test Finder where the host allows it,
verify packaged binaries and release checksums, and report any remaining runtime
or installation limitation honestly in docs/ACCEPTANCE.md.
