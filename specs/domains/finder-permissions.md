# Finder, folders and permissions

Load for: Finder observation/menu scope, bookmarks, privacy guidance and local extension maintenance.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Folders and permissions

- Finder menus include the current user's real home directory and its children
  by default, plus folders explicitly added by the user. Resolve the home URL
  from the operating system, never by a username, display label or fixed
  `/Users/...` path. Keep Desktop, Documents and Downloads as separate menu
  locations. Older settings retaining all three original defaults
  gain the dynamic home entry once; restricted folder selections and subsequent
  removal of the home entry remain authoritative. When Desktop or Documents is in
  scope, register the real user's home as a Finder observation ancestor so
  protected-folder callbacks can arrive. This registration grants no filesystem
  access. Both menus and quick requests must still check the configured folder
  scope; unrelated home folders receive no FileMint menu. Never scan directory
  contents or badge files, and do not request broad filesystem entitlements.
- Menu construction may use path-only scope checks to stay fast in Finder. Before
  the main app accesses files, resolve the configured roots and the selected
  item's parent or destination directory on disk. Reject a path that enters an
  unconfigured folder through a symlink. A selected symlink itself belongs to its
  parent folder and may still be moved or deleted as a link. Resolution failure
  grants no scope.
- Open with App may also appear for a captured background container directory.
  Item menus keep their complete selected-item snapshot. Recheck resolved scope
  and target type before a directory open; a later Finder location never replaces
  the captured target.
- Finder menu location selection uses NSOpenPanel and saves only paths.
  Adding or removing a menu location does not change saved file access. A
  failed settings save keeps the previous complete selection.
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
- Menu icon choices are read from the cached preferences snapshot while building
  the menu. Rendering a symbol never reads user files or changes captured targets.
- The [Finder hidden-files command](file-tools.md#toggle-hidden-files-in-finder)
  uses the captured menu path for scope and sends Finder its shortcut on demand.
  Ask for the keystroke-posting permission from the main app after the user
  chooses the command. The grant appears under Device Control and Data Access
  in macOS 27 and later, and under Accessibility in earlier versions.

## Authorization for file operations

- File Access settings let the user save read/write access to the real home
  directory or another explicitly selected directory. Use the native picker and
  explain descendant coverage before consent. List saved directory write grants
  and legacy Finder folder bookmarks with their sources. Removing one record
  removes its saved authority without deleting files or changing Finder menus.
  Another explicit covering grant, native session access or system access can
  still apply. Report save/remove failures and preserve the prior record.
- Present saved folder access and on-demand native authorization in file access
  setup and troubleshooting. File Access rows describe saved directory grants;
  Finder & Folders rows describe menu locations. Actual access depends on the
  target, the operation and macOS permissions.
- For each captured item or destination, restore applicable saved grants for the
  exact target and its authorized ancestors. Resolve the operation target against
  the current Finder roots and separately verify coverage by the authorized
  object. An ancestor grant may start above the menu root. Use explicit app
  destinations without requiring Finder menu registration. Hold saved scopes
  only for the operation and worker cleanup, with no startup-wide activation.
  New operations reload saved authority. Keep feature-specific grants within
  their original purpose and access mode.
- Share explicit file and folder grants at compatible access levels. A read-only
  grant never satisfies a write. General read and write bookmarks use separate
  private stores. Existing legacy Finder and feature-specific bookmarks keep
  their format and permission level. A valid, independently authorized ancestor
  can still cover an operation when another saved grant needs renewal.
- When safe, attempt the requested read or transactional creation first. Before
  multi-item writes or external dispatch that cannot safely be repeated, check the
  required native access without touching user data. Only a permission denial can
  trigger the exact-file or exact-folder authorization picker. Missing, replaced,
  unsupported and out-of-scope targets report their own failure. Never replay a
  partial operation. Explicit authorization setup and documented identity-bound
  grant renewal or recovery still require the user's selection.
- Authorization uses the native sandbox selection panel. Name the file or folder
  in its message and use Authorize / 授权 for confirmation. An explicit setup
  picker may ask for folders the user selects. Recheck the selected target and
  the operation's current scope before using or persisting access.

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
  A folder explicitly authorized in that picker can be remembered for later
  writes. An external request outside Finder scope can restore an exact saved
  destination grant. A request path or an Intent's temporary grant alone never
  creates that record.
  External drafts never weaken Finder ticket/scope checks or scan folders.

## File information authorization

Copy File Contents follows the same captured identity and read-only authorization
boundary below. Its explicit menu click authorizes the bounded content read and
clipboard publication described in [file tools](file-tools.md#copy-file-contents).
Change Default App uses the same metadata-only capture and read authorization
to confirm the selected type. The system association is a separate, explicit
confirmation and never needs write access to the selected file.

- Finder captures the menu's single selected URL and probes only that item's
  type metadata to hide unsupported resources. It captures item/real-parent
  identities off the UI thread only after explicit invocation. It reads no content
  and cannot replace a failed capture with post-authorization identity.
- Reuse configured security-scoped access and valid remembered read grants.
  On permission denial, the native picker accepts the exact selected item or
  its direct parent. Explain the choice and that FileMint remembers read access.
  Verify the current scope and captured item and parent identities before saving
  an explicitly chosen grant. Cancellation preserves the previous grants.
- Copy File Contents, File Info and Change Default App share general read-only bookmarks across
  Finder windows and app relaunches. Store at most 1,024 grants and 4 MiB, publish
  atomically with 0600 file permissions, and preserve corrupt or redirected
  storage. A file grant covers the exact file. A directory grant covers its
  resolved descendants that remain in Finder scope. Verify saved resource and
  volume identities against fresh metadata. Moved, replaced or unusable grants
  require authorization only when the operation is denied. A remembered grant
  adds neither observation roots nor write access.
- Keep active scopes through worker cleanup and release them on completion or
  cancellation. Check current scope and captured identities around coordinated
  reads. A storage failure reports an error before publishing new clipboard data.
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
- A rejected saved grant needs exact-parent renewal unless another valid,
  independently authorized folder grant covers the current captured parent.
  A stale pathname or ambient temporary grant supplies no renewal consent.
  Only an explicit parent selection or a previously saved rename grant can
  seed or refresh the rename grant store. A reusable general grant may cover
  a batch but never creates a second reusable grant or reuses an undo receipt
  as authority for a new batch.
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
