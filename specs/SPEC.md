# FileMint SPEC

## Product promise — 0.2

A small, native macOS utility that creates a file where the user is already working.
Fast Finder actions, a compact keyboard-friendly creation panel, and no account,
network client, analytics, folder crawling, or clipboard monitoring.

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
- Preference refresh is notification-driven. No timers or background directory
  enumeration. File I/O runs away from the main thread, and duplicate submission
  is disabled until it completes. An actionable error keeps the draft intact.

## Folders and permissions

- Finder Sync monitors Desktop, Documents and Downloads by default, plus folders
  explicitly added by the user. It does not scan their contents or badge files.
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
- Finder APIs remain in FinderSyncExtension; deterministic rules in CorePackage;
  SwiftUI settings remain in App/FileMint. Shared AppKit creation UI may be
  compiled into both app and extension.

## Startup and menu bar

- Launch at login and Show in menu bar default to enabled. Both have persistent
  switches in General. A saved off value must survive upgrades and relaunches.
- Use macOS 13+ SMAppService.mainApp for login registration. Request the default
  once after the app has been placed in /Applications or ~/Applications and
  launched. Do not register development builds or a mounted DMG as login items.
- Display actual service status: active, off, awaiting system approval, unavailable
  or failed. A stored preference alone is never proof of successful registration.
- Respect changes in macOS Login Items; do not silently re-register after the
  user disables/removes the item there. Offer an explicit retry/settings action.
- Hiding the menu bar item takes effect immediately and persists. The Dock/app
  settings remain reachable. Finder URL actions continue to work when the
  settings window is closed or the menu bar item is hidden.
- New preferences follow the system's supported language; explicit saved English
  or Chinese choices remain authoritative. Users can also select Follow System.
- Folder settings include an optional Full Disk Access guide and a button to
  open its macOS privacy pane: add the installed FileMint.app, enable it, then
  quit and reopen FileMint. Never silently change this system permission.
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

## Appearance

- Native controls and system colors. Compact settings with General, File Types
  and Folders. No decorative cards. Follow system language by default; English
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
- This release uses ad-hoc code signatures for bundle integrity and GitHub
  artifact attestations for build provenance, plus a portable SHA-256 checksum.
  Neither claims Apple developer identity or notarization. Disclose Gatekeeper
  and Finder extension approval requirements before download. Never tell users
  to disable Gatekeeper globally.
- GitHub Releases and GitHub build provenance are the standing default for
  future releases, not a temporary fallback. Do not switch channels or make
  Apple credentials a release prerequisite without a new owner request.
- CI verifies the core, builds both architectures, validates nested code and
  creates the DMG. Attestation refers to the final bytes uploaded to the release.
- README leads with the pain solved, actual features, screenshots, download and
  a brief install guide. Chinese first, English separate. Developer instructions
  live in docs. Optional donations link the supplied ReceivePayment images.
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
