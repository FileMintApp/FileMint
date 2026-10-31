# Startup, settings and preferences

Load for: App/window lifecycle, login items, menu bar visibility, language, appearance and persistent defaults.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

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
- Failed preference saves restore the previous menu-bar and automatic-update
  choices. A rejected update-setting change must not cancel an active automatic
  check or start a new one; the successfully saved choice remains authoritative.
- New preferences follow the system's supported language; explicit saved English
  or Chinese choices remain authoritative. Users can also select Follow System.
- General offers Follow System, Light and Dark appearance choices. Follow System
  is the default for new, missing or invalid saved values. Explicit choices persist
  across relaunch and settings import, apply immediately to all app-owned windows
  and sheets, and do not change macOS or Finder's appearance. Follow System removes
  the app override so subsequent system appearance changes remain live.

- Settings has one resizable sidebar window. Switching pages preserves the
  in-session page selection without saving navigation into user preferences.
  About/update commands select About in that same window; page navigation does
  not change the explicit-launch and Finder-creation window ownership rules.
- Reopening the app while a native modal authorization/confirmation window is
  active focuses that window first. Do not put settings in front of it or strand
  the operation in an obscured modal session. Ordinary reopening when no modal
  window is active keeps the existing settings behavior.
- File & Folder Tools and Resource Tools have their own settings entry under Extensions. Their
  master switches default off on new installs and migration, preserve child
  choices and menu placement when disabled, and never alter existing creation
  preferences. File-tool placements default to submenu, except Move Selected Items
  Here which defaults to main. New deletion/AirDrop switches default off; deletion
  confirmation defaults to required, including absent or invalid saved values.
  Send Alias to Desktop also defaults off and retains its menu placement.
- Resource Tools is a separate default-off module. The original six child
  switches default on, and private metadata removal is on for new installs but
  off for older saved child lists; saved choices survive off/on. An active resource panel blocks quit/restart
  through the serialized file-operation coordinator.
- The resource switch controls Finder exposure only. Explicit main-app file
  selection remains available without changing this preference or menu scope.
- Favorite Locations has its own Extensions settings page and menu-bar quick
  access. Its direct Finder add entry and bounded quick list have independent
  saved visibility switches, initially on, and never broaden Finder folder scope.
- Hide & Unhide is an independently configurable File & Folder Tools child,
  initially off on new installs and migration. It has no menu-bar command or
  Accessibility permission flow; its selection and metadata contract lives in
  [file tools](file-tools.md#hide-and-unhide-selected-items).
- Open with App has an initially empty persistent application list. Explicitly
  adding an app enables its entry; its independent placement defaults to submenu.
  Saved list order controls each Finder menu level. See [Open with App](open-with.md)
  for validation and opening behavior.
- A supported terminal's directory opening mode is saved with its existing App
  entry. Older entries preserve Follow App behavior; adding a recognized terminal
  defaults to New Tab. Other apps have no terminal mode control.
- Fixed creation actions and template IDs save independent hidden/main/submenu
  positions. Decode each saved entry independently; missing/invalid entries inherit
  the legacy New File group position, or submenu if that is invalid. Existing
  templates inherit the legacy position on upgrade; newly appended presets remain
  disabled and use submenu. Preserve valid neighboring positions and unrelated
  preferences. New templates/imports default to submenu; copies inherit the source
  position. Delete orphan positions and reset only built-in positions on explicit
  restoration. Save placement and template edits in one atomic preference update.
  Keep the legacy field for decoding older settings; it has no group-level UI.
  See [creation](creation.md) for menu composition.
- Per-suffix default template IDs are saved independently of ordering. Missing
  old fields fall back deterministically without losing user templates or other
  preferences; invalid references are removed when settings are saved.
- Menu icon overrides store only system symbol names and color values in the
  existing preferences document. Missing or malformed icon preferences use the
  established defaults without changing other settings. The app alone writes
  them; Finder reads the cached settings and refreshes after a save. Unsupported
  symbols render the default icon instead of an empty menu image.
- The global Finder menu icon style persists independently of icon overrides.
  New installs and missing, malformed or unknown saved style values use Colored.
  System Monochrome survives relaunch and settings import, refreshes Finder's
  cached preferences after saving and preserves all saved symbols and colors so
  switching back restores them. A failed save restores the previous style.
- Limit the persisted settings document to 32 MiB. A missing file initializes
  defaults; a present corrupt or oversized file leaves Finder scope empty and is
  preserved for explicit recovery instead of being overwritten during startup.

- An explicitly requested updater relaunch must wait until creation work and
  modal editing are finished. Preserve saved startup preferences and bookmarks.

## Quick Search and its global shortcut

- General contains a Quick Search section with an independent Enable Global
  Shortcut switch and a combination recorder. New, missing and malformed switch
  values default off. Suggest Control-Option-K; explicitly enabling with no saved
  combination fills this default in the same atomic update. An existing custom
  combination remains authoritative. A conflicting default leaves the switch off
  and displays guidance to choose another. Turning off releases registration but
  preserves the combination. Recording or restoring the default never enables the
  switch. Malformed/imported enabled settings without a key display setup guidance.
- Store physical key code and Command/Control/Option/Shift modifiers in the
  existing preferences document, decoding each field independently. Require
  Command or Control and a supported ordinary key; reject modifier-only/media
  combinations. Display the key using the active keyboard layout. No key logging,
  Accessibility, Input Monitoring, Automation or additional package is required.
- Record only inside the focused recorder. Pause the app's hotkey during recording;
  Escape, loss of focus, closing settings or quitting cancels recording and restores
  the committed registration. Reject known system/app-menu conflicts and surface
  OS registration failures. Prepare a changed registration, save atomically, then
  release the previous registration; a failed save/change keeps the prior settings.
  A failed startup/import/external reload releases obsolete registrations and
  shows the saved choice as inactive with an explicit retry, never as effective.
- Only the main app owns the global key while running. Closing settings or hiding
  the menu bar does not disable it; quitting releases it. A hotkey release opens
  or focuses one accessory Quick Search panel; pressing it again while that panel
  has keyboard focus dismisses it. Existing app-owned modal windows
  or sheets take priority. The panel neither creates a Dock icon nor opens settings
  until an explicit settings result is chosen. No Finder selection is inferred.
- Quick Search is also available in the menu bar and app File menu (Command-Shift-K)
  independently of the global switch. Existing Command-K retains Favorite Locations.
  Results cover the three app creation actions, enabled templates, saved favorites
  and settings destinations. Match bilingual action/settings aliases, template
  names/suffixes/aliases and saved favorite names/groups/path text. Group results by
  kind, preserve existing within-kind match ordering and stable IDs. Empty search
  shows creation actions and bounded pinned/recent favorites.
- The panel starts in All and offers Actions, Templates, Favorites and Settings
  scopes. Switching scope retains the query and selects the first current match;
  Command-1 through Command-5 select those scopes in order. Empty scoped searches
  browse that category's available snapshot (enabled templates, all saved
  favorites, or settings); All keeps its bounded default suggestions. Clearing a
  query keeps its scope. Left/Right retain native text editing and IME behavior;
  category switching remains Command-1 through Command-5.
  Category controls remain keyboard accessible and restore input focus when used.
  Show each category's Command-number shortcut in its label. Opening or refocusing
  the panel makes it the key window and focuses its search field without another
  click; Arrow/Return/Escape work immediately, respecting IME composition.
  Pointer hover is distinct from keyboard selection and never redirects Return.
  The footer names the selected action (create, locate in Finder, or open settings)
  and gives navigation/close keys; no-result states offer clearing the query or
  returning to All. Only a currently selected result enables the footer action.
  Keep the full action label visible; shorten secondary keyboard hints first
  when space is constrained, never the action itself.
- Dismiss when the user clicks outside, switches applications/Spaces, presses
  Escape or closes the panel. Mouse movement alone never dismisses; the external
  click must reach its original target normally. A context menu, IME composition
  or a search-owned relink/authorization interaction must not be mistaken for
  leaving. Menu cancellation and IME confirmation/cancellation take precedence
  over dismissing the enclosing search. Observe native window/workspace events,
  without adding keyboard monitoring or permissions.
- Unfinished search state (query, category and stable selected ID) survives all
  dismissals in controller memory only. Reopening refreshes current snapshots,
  preserves a still-valid selection and selects all query text so typing replaces
  it. An invalidated selection cannot silently execute another row. Successful
  handoff to creation/settings, or successful favorite activation, clears this
  state; creation's own picker/draft lifecycle remains independent. Relaunch starts
  fresh. A pending operation may clear its dismissed session on success, but never
  a session reopened since it started. Failures keep the current search available
  without reopening a dismissed panel or stealing focus from another app.
- Search operates on cached value snapshots without clipboard reads, filesystem
  discovery, template-content indexing or search-history persistence. Refresh after
  successful preference/catalog changes; revalidate an ID before execution.
  Arrow keys select, Return activates, Escape closes, and IME composition consumes
  its own navigation/confirmation first. Query/result updates never make Return
  execute a different stale row. Use a lazy result list with native accessibility.
- Commands call their existing app flows. Favorite activation retains its bookmark,
  identity, error and operation guards. Template results open the one creation
  draft with the exact template ID after directory choice; only Create writes.
  Settings results navigate the existing settings window without changing a setting.
  No Finder-only file operation or automatic use of a previous Finder target joins
  this version. Existing operation, quit and update guards remain authoritative.

## Shortcuts and launchers

- FileMint keeps its macOS 13.0 application minimum. Shortcuts & Launchers alone
  requires macOS 13.3 or later, using one ForegroundContinuableIntent route.
  On macOS 13.0–13.2, keep the settings page readable, show the required version
  and disable its setup, preview and export actions. Reject direct external
  draft/search requests before admitting work or accessing a destination.
  Do not offer an older-system fallback, persist an enabled state, raise the
  application's deployment target or disable ordinary creation/Quick Search.
- Explicit external draft/search actions work independently of the global key and
  menu-bar switches. Run the adapters in the main app and reuse the existing
  creation/search controllers, pending-work and quit/update guards.
- External cold launches present only their accessory draft/search. Ordinary
  explicit launch remains able to show settings. Never classify an Intent's
  background host launch as ordinary merely from the default-launch notification;
  use the public activation request and current external-session ownership.
  Reopen prioritizes native modal/sheet and the active external panel. Clearing
  that session restores ordinary reopen, without a lingering suppression token.
- External search shows/focuses rather than toggles. Report shown or alreadyVisible
  only when its search input is visible, key and interactive; modal or exclusive
  work returns busy, and failed/timed-out presentation returns unavailable.
  Cancellation cannot queue a later search or overwrite an unfinished query.
- Preferences includes Shortcuts & Launchers after General. It guides project
  notes, upstream workflow text and Quick Search through native Shortcuts,
  Raycast or a public URL. Configuration is transient; no account, persistent
  content preset library or automatic third-party installation is introduced.
  Export only to an explicit save destination. Keep export/real-test guidance
  nonmodal so it does not block the external request it asks the user to run.
- The command generator pauses only its own sheet for a reserved preview, then
  uses the same draft admission and writer. Keep configuration through preview;
  restore it and Preview focus after cancellation or completed creation, only
  when the same settings owner is active/key and has no other modal. A failed
  write or cancelled authorization keeps the draft. Closing settings cancels
  unpresented work and releases configuration; it cannot revive the window or
  destroy an already established independent draft. External callers cannot
  claim the generator's private reservation.
- Raycast export writes one executable script atomically to the user's selected
  location and never edits Raycast configuration. Its one optional runtime name
  is percent-encoded as data; fixed URL values and shell headers are validated.
  Show saved/copied and matching local request-received states separately from
  unverified third-party import. Configuration and content are not persisted.

## File information lifecycle

- Copy File Contents also defaults off independently on new/malformed/old settings,
  preserves its submenu/main placement and holds the shared operation guard until
  reading and clipboard publication or cancellation cleanup finish. Its compact
  feedback panel does not open settings. Quit/update restart cancels and waits.

- Decode the File Info child switch independently, default off for missing or
  malformed values; placement defaults to submenu. Preserve neighboring choices
  and the child choice while its module is disabled. Algorithm selection is
  window-local and always starts at SHA-256, never a persisted insecure default.
- Finder opens only the information panel, preserving settings and existing
  accessory/Dock behavior. Preparation, authorization and reading hold the shared
  operation guard; idle result windows do not. Busy requests are consumed and
  rejected immediately, not queued behind a long calculation. Recalculation
  reclaims the same guard. Closing cancels; quit/updater restart cancels active
  reading and waits for cleanup before proceeding, without an idle-window blocker.

## Batch rename lifecycle

Implementation contract; phase evidence is tracked in the batch-rename task. [File tools](file-tools.md#batch-rename)
owns the operation behavior and private-state format/limits.

- Decode the new batch-rename child switch independently, default off for new,
  missing or malformed values; its placement defaults to submenu. Preserve valid
  neighboring tool choices, icons, placements, preferences and pending moves.
  Disabling switches preserves choices and operation records without new actions.
- Finder rename requests open only the app-owned rename/recovery panel. They do
  not open, restore or close settings; Dock/menu-bar behavior remains determined
  by existing explicit-settings ownership and visibility preferences.
- The active panel, authorization, commit, cancellation/rollback and explicit
  recovery/undo or manual record retirement hold the coordinator's busy/quit/update
  guard until safely closed.
  A second rename request cannot replace the session or expire silently in a queue.
  Idle interrupted-state discovery alone does not hold the app busy or prevent quit.
- Startup reads only the bounded private operation store; no automatic user-folder
  access, unfinished rename, undo or recovery. File & Folder Tools shows passive
  recovery status and explicit Restore / export-and-unblock actions outside
  disabled child settings. Interrupted retirement offers metadata-only finalization
  on explicit action, never automatic restoration or archival on startup.
  The File menu/result window offers normal last-batch undo under current switches
  and scope; compensating recovery follows its separate authority. Closing an idle
  panel never forgets a pending record or starts a write.

## Optional creation features and template recovery

- Creation Behavior retains basic reveal settings and adds independent Create and
  Open / 创建后打开 and Template Preview / 模板预览 switches. Both default off
  for new, missing or malformed values. Valid values persist; failed saves restore
  committed state and do not advance opening-disable generation.
- Decode legacy reveal before seeding missing/malformed per-template actions
  (true → Reveal, false → none); valid neighboring records/actions survive.
  Preserve hidden app choices, defaults, disabled/removed built-ins and grants.
  Normal changes never activate previews, app discovery or opening during decode.
- Save creation applications separately from Finder Open with App entries, with
  stable IDs and validated read-only bookmarks. Save template/app edits atomically.
  Packages contain portable hints only and never read/write feature gates.
- Track serialized import/export/commit work and post-creation dispatch in ordinary
  quit and existing updater pending-work inputs. Recover only the bounded (1 MiB)
  versioned template journal and its exact assets/commit marker on startup. Corrupt
  settings/journals preserve evidence and block further template mutations.

## Working context

- Implementation entry points: `App/FileMint/FileMintApp.swift`, `AppDelegate.swift`, `SettingsWindowController.swift`, `LoginItemService.swift`, `PreferencesModel.swift`, `GlobalShortcut*`, `QuickSearch*`; `Preferences.swift`, `LoginItemPolicy.swift`, `Localization.swift`.
- Verification: [Core checks](../verification/core.md); [window isolation](../../docs/FINDER_QA.md#creation-window-isolation) and [settings](../../docs/FINDER_QA.md#types-and-preferences) for native changes.
- Expand context only when needed: Load the owning domain for each preference being changed: [templates](templates.md), [Finder/permissions](finder-permissions.md) or [updates](updates.md). Load [creation](creation.md) for URL launch and draft-window behavior.
