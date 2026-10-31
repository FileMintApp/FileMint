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
- Open with App may also appear for a captured background container directory.
  Item menus keep their complete selected-item snapshot. Recheck resolved scope
  and target type before a directory open; a later Finder location never replaces
  the captured target.
- Folder selection uses NSOpenPanel. Persist security-scoped bookmarks alongside
  paths, restore access on launch, and release access when folders are removed.
  Apply additions/removals to active grants only after saving succeeds. Failed
  bookmark capture or persistence restores the previous complete folder settings
  and leaves existing grants active; never retain a partially added selection.
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
- General also presents an immediately visible Full Disk Access setup action on
  first launch and later visits. It opens the macOS privacy pane only on the
  user's request and states that the system switch is authoritative, FileMint
  cannot read it, and sandbox folder selection may still be needed.
- macOS discovers and loads the bundled Finder extension; its enabled state is
  controlled by the user. Explain this in the setup guide and open the system
  extension management UI on request. Do not use private APIs or `pluginkit` to
  silently enable it from the sandboxed app. Refresh actual status on returning.
- Finder APIs remain in FinderSyncExtension; deterministic rules in CorePackage;
  SwiftUI settings remain in App/FileMint. Shared AppKit creation UI may be
  compiled into both app and extension.
- Menu icon choices are read from the cached preferences snapshot while building
  the menu. Rendering a symbol never reads user files or changes captured targets.
- Hiding/unhiding is a selection-scoped [file tool](file-tools.md#hide-and-unhide-selected-items).
  Finder captures metadata identities only after the explicit menu click; the main
  app owns exact-parent authorization and hidden-attribute writes. Do not request
  Accessibility access, send keys, change Finder preferences or restart Finder.
  There is no Finder-wide hidden-item toggle in settings or the menu bar.

## External draft destinations

- Saved bookmarks for explicitly exported launcher scripts authorize only those
  script files for management. They never authorize a draft's save destination
  or add a Finder observation root. Do not scan their containing directories.
- A launcher path or favorite ID is a location suggestion, never a grant or a
  Finder observation root. Native Intent directory access is session-owned;
  release it only after cancellation or write cleanup. Do not persist it merely
  because a command was exported, received or previewed.
- Resolve only the requested directory/favorite, off the UI thread. Validate its
  kind and captured identity after access and before creation. Bind writes to
  that directory object so a path replacement cannot redirect publication; a replaced,
  missing or denied target preserves the draft and offers explicit recovery.
  Missing access uses the existing exact-directory picker. Cancelling preserves
  input; choosing another directory updates the panel and requires Create again.
  External drafts never weaken Finder ticket/scope checks or scan folders.

## File information authorization

Copy File Contents follows the same captured identity and read-only authorization
boundary below. Its explicit menu click authorizes the bounded content read and
clipboard publication described in [file tools](file-tools.md#copy-file-contents).

- Finder captures the menu's single selected URL and probes only that item's
  type metadata to hide unsupported resources. It captures item/real-parent
  identities off the UI thread only after explicit invocation. It reads no content
  and cannot replace a failed capture with post-authorization identity.
- The main app reuses configured security-scoped access when valid; otherwise
  request the exact selected resource or necessary parent with a native picker,
  using read-only bookmark options. No new persistent grant database, write
  authority, Full Disk Access request or observation-root expansion. Keep grants
  through worker cleanup, release them on completion/cancel, and reauthorize on
  recalculation if needed. Validate current scope and both captured identities
  after authorization and around coordinated reads; never follow a replaced item.
- Metadata and digest work probes only the selected item and its real parent.
  No folder enumeration, automatic cloud-download API or provider discovery.
  Unsupported links/aliases/packages have no new menu entry; an older capture
  still reports them without reading their content or following their target.

## Batch rename authorization

Implementation contract; the [file-tools contract](file-tools.md#batch-rename)
owns selection, naming, storage support and recovery semantics.

- Finder keeps only the menu-captured complete URLs until explicit invocation;
  capture identities away from the UI thread and transfer them with a private
  single-use ticket. Main-app validation after accurate parent authorization
  rechecks the whole snapshot, real parent identity and resolved scope. Never
  substitute a later Finder selection or authorize just a file for parent writes.
- Click-time capture requires only metadata access to the selected entries and
  their parent; it must not open that directory for reading its contents before
  the main app can request authorization. Capture and recheck the parent identity;
  the main app then opens its pinned operation handle after exact-parent access
  and rejects a replaced parent or item before preview or mutation.
- Pin the real parent object for source/staging/target steps; scope checks and
  directory handles must not follow a replacement at the saved parent path.
  Bound metadata probes to selected items, their parent, exact generated targets
  and known protected locations. No directory enumeration, provider-domain crawl
  or broader filesystem entitlement. Required identity, scope and access checks
  must succeed; no unmanaged-storage classification or provider query is required.
  Respect native permission, availability and unsupported-operation errors. Do
  not request downloads or widen access as a fallback when an operation fails.
  Finder callback availability does not replace main-app validation and is not
  a guarantee about storage compatibility.
- Resolve selected-directory ancestry against known private storage/workspace
  locations as well as checking their protected subtrees. Reject an ancestor
  that would carry FileMint state into staging; never enumerate its contents.
- Normal rename/undo require current configured scope and saved/explicit parent
  write access. Restore an interrupted operation only inside its captured parent
  object, with a matching bookmark or explicit picker and fresh identity checks.
  This compensating action remains reachable when switches/scope are disabled;
  it never changes menu roots or accepts a different directory as a substitute.
- Remember batch-rename parent grants in a separate private, versioned store,
  bounded to 1,024 directory grants and 4 MiB, with 0600 files. Store the exact
  parent identity and read/write security-scoped bookmark. A new eligible batch
  restores a matching saved grant, including the same directory object moved to
  its current in-scope path, refreshes its bookmark and retains its own active
  access only for that operation. Recheck the complete batch and current scope
  before persisting a new/refreshed grant; cancelling the rename preview does not
  forget a folder the user already explicitly authorized.
- Persistent grant identity uses the bookmark's volume UUID plus inode,
  generation, birth time and kind, so a changed mount device number does not
  invalidate the same directory. Compare against fresh metadata after starting
  access; reject a different/missing volume UUID or replaced object. Existing
  version-1 bookmarks participate without a format reset; bookmarks lacking a
  volume UUID retain strict device matching. Click-time snapshots, pinned handles
  and operation/undo/recovery records retain their existing strict identity checks.
- Unresolvable, denied or identity-mismatched saved grants require the exact-parent
  picker again; do not treat a stale pathname or an ambient temporary grant as
  proof that a rejected saved grant remains valid. A matching still-valid prior
  rename receipt or configured folder grant may seed the independent store.
  Cancelled renewal preserves existing records and changes no user entries.
  Corrupt/unsupported/oversized or redirected grant-store bytes are preserved and
  reported, not silently reset. Create and finish a private 0600 temporary file
  before atomically replacing the grant store; no fallible permission repair
  follows publication. A failed save preserves the previous store (or its absence)
  and stops a new batch before mutation.
- Undo, receipt replacement/forgetting, recovery cleanup and manual retirement do
  not clear remembered directory grants. Existing operation bookmarks remain
  independent authority for undo/recovery, so a damaged grant cache cannot prevent
  compensating restoration. Remembered grants never add Finder observation roots,
  change feature switches or bypass current scope, identity or write checks.
- Manual record retirement follows the [file-tools protocol](file-tools.md#manual-resolution-of-recovery-records).
  It needs explicit export-destination access but no user-item access or restored
  Finder scope. An export grant never authorizes touching remaining staged items
  or broadens observation roots; cancellation/failure preserves the blocker.
- Keep user permission prompts authoritative and operation grants alive through
  the panel, commit or recovery; release active access on close. Restore consent
  comes from the explicit recovery action, not startup, ticket replay or opening
  a status card. Legacy creation, moves and other tools retain their own rules.

## Privacy permission guidance

- Folder settings include an optional Full Disk Access guide and a button to
  open its macOS privacy pane using the macOS 13+ Settings link, with a general
  System Settings fallback if opening that link fails: add the installed
  FileMint.app, enable it, then quit and reopen FileMint. Never silently change
  this system permission.
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

## Template workflow access boundaries

- Copy/preview/exchange do not widen observation roots or Finder folder scope.
  Preview touches only a selected validated asset and owned private snapshots.
  Package pick/save grants span their worker operations and are released once.
- The shared creation panel reports successful receipts to an injected app-owned
  executor; Finder keeps its existing single-use transport and captured directory.
  Hold destination grants through native handoff, and keep settings closed during
  cold/warm Finder creation. No installed app or real preferences are QA fixtures.

## Working context

- Implementation entry points: `FinderSyncExtension/`, `SharedUI/FolderAccess.swift`, `FolderScope.swift`, `FileMenuAction.swift`, `QuickCreationTicket.swift`; folder persistence in `Preferences.swift` and `PreferencesModel.swift`.
- Verification: [Finder/native checks](../verification/finder.md).
- Expand context only when needed: Load [creation](creation.md) when menu actions, captured destinations or request handling change; [distribution](distribution.md) for packaging/registration cleanup. Read [extension enablement research](../../docs/FINDER_EXTENSION_ENABLEMENT.md) only for status/enablement investigations.
