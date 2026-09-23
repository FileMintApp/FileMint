# Finder, folders and permissions

Load for: Finder observation/menu scope, bookmarks, privacy guidance and local extension maintenance.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

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
- Menu construction may use path-only scope checks to stay fast in Finder. Before
  the main app executes a request, resolve the configured roots and the selected
  item's parent or destination directory on disk. Reject a path that enters an
  unconfigured folder through a symlink. A selected symlink itself belongs to its
  parent folder and may still be moved or deleted as a link. Resolution failure
  grants no scope.
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
- A missing preferences file uses first-run defaults. A present but unreadable,
  oversized or invalid file must not restore the broader default Finder scope or
  be silently overwritten. Keep its bytes for explicit user recovery/import.
- Existing preferences without bookmarks still load. If a write lacks permission,
  hand the draft to the main app, authorize the destination using a directory
  picker there, and retry after the user chooses Create. All creation and
  authorization panels belong to the main app, not Finder extension processes.
- Settings give short instructions for enabling the extension (macOS 15+:
  General → Login Items & Extensions → Finder; older systems: Privacy & Security
  → Extensions). Show actual extension status when the system API is available.
- General shows a setup card whenever the Finder extension is disabled, including
  first launch and a later system-level disablement. Its user-triggered button
  opens extension management; short path guidance remains visible if the system
  opens a broader settings page. The card disappears only after the system API
  reports the extension enabled, refreshed when FileMint becomes active. Do not
  persist a separate onboarding-complete flag or treat opening Settings as consent.
- macOS discovers and loads the bundled Finder extension; its enabled state is
  controlled by the user. Explain this in the setup guide and open the system
  extension management UI on request. Do not use private APIs or `pluginkit` to
  silently enable it from the sandboxed app. Refresh actual status on returning.
- Finder APIs remain in FinderSyncExtension; deterministic rules in CorePackage;
  SwiftUI settings remain in App/FileMint. Shared AppKit creation UI may be
  compiled into both app and extension.

## Privacy permission guidance

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

## Working context

- Implementation entry points: `FinderSyncExtension/`, `SharedUI/FolderAccess.swift`, `FolderScope.swift`, `FileMenuAction.swift`, `QuickCreationTicket.swift`; folder persistence in `Preferences.swift` and `PreferencesModel.swift`.
- Verification: [Finder/native checks](../verification/finder.md).
- Expand context only when needed: Load [creation](creation.md) when menu actions, captured destinations or request handling change; [distribution](distribution.md) for packaging/registration cleanup. Read [extension enablement research](../../docs/FINDER_EXTENSION_ENABLEMENT.md) only for status/enablement investigations.
