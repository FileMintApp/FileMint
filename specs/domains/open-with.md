# Open with App

Load for: Configured applications, their Finder menu placement and opening selections.

## Settings and persistence

- Open with App / 使用 App 打开 is a separate page under Extensions. The list
  starts empty, including when older preferences are loaded. Adding an application
  enables its entry immediately; there is no additional module switch.
- Add App opens a native application picker, initially at Applications, allowing
  one or more application bundles. Validate real application bundles and store
  their display name, bundle identifier, URL and read-only security-scoped bookmark.
  Do not crawl Applications or launch an app while adding it.
- Bound each application Info.plist read to 1 MiB and perform bundle validation away from the
  main UI thread; a malformed or unusually large Info.plist fails validation
  without hanging the settings panel.
- Preserve the saved list order and reject duplicates by bundle identifier or
  canonical URL. Users can drag rows to reorder them; each menu level follows
  that relative order. During a drag, show a high-contrast insertion line at the
  exact boundary where the app will land; animate the guide and row settling,
  respecting Reduce Motion. Clear the guide when the drag leaves or ends.
  Choosing an existing app refreshes its location/bookmark
  while preserving its stable ID, order and placement. Malformed entries must not
  discard valid neighbors.
- Each row shows the native app icon, name, location, menu-position picker and
  remove action, with a visible drag handle and keyboard-accessible reorder
  controls. New entries default to Submenu / 二级菜单; Main menu / 一级菜单 is
  independently configurable. Removal changes configuration only.
- Match existing adaptive surfaces, spacing and mint accents. Include a concise
  empty state with Add App and explain where entries appear. Support Chinese,
  English, keyboard/accessibility navigation, light/dark appearance and minimum
  window size. An unavailable app remains removable and can be re-added to repair
  its location; never silently launch a different app as a fallback. Keep menu
  placement in the application rows; omit the simulated Finder menu preview and
  its context switch from settings.

## Finder and opening

The same configured App list and Finder group also serve a background container menu. A background action passes Finder's captured directory, while an item action preserves the complete selected item list and its order. A single selected ordinary folder uses the folder itself as a directory target; packages, symlinks, aliases, files and multiple selections keep the ordinary selection action. The menu never reuses a later Finder selection. Toolbar and sidebar menus do not gain this action. Directory targets must be local, within configured and resolved folder scope and still exist as directories when used.

Terminal, iTerm2 Stable, Ghostty and Warp Stable are the initial recognized terminal identities. Recognition is by validated bundle identity and a supported adapter, never by display name. Adding an identified terminal defaults to New Tab; older saved entries and malformed mode values use Follow App. A terminal row shows Follow App, New Tab and New Window. Mode affects directory actions only; file selections retain the existing opening behavior. Each App still has one Finder menu item and one placement. A directory menu title shows the chosen terminal mode. An old menu whose saved mode changed must not silently perform the new mode.

Terminal, iTerm2 and Ghostty use their published macOS folder Services with a private pasteboard. Warp uses its published action URL sent to the configured application. No shell command, simulated keystroke, user clipboard write or silent mode fallback is permitted. A successful dispatch is not proof that the terminal opened the requested folder; the actual working directory and window/tab mode require native acceptance for each adapter.

- Offer entries for a nonempty, complete item selection of local files/folders
  in configured scope and for an in-scope background container. Toolbar and sidebar
  contexts never reuse a previous selection. Files, folders and mixed selections
  are passed together in Finder order; the chosen app decides supported types.
- Each configured entry appears exactly once as Open with <App> / 使用「App」打开,
  at its configured level. The Open with App group is a sibling of New File and
  is hidden when no submenu entries remain, including an empty application list.
  Main-menu entries remain visible when the submenu group is hidden.
- Capture the selected URLs and the configured app identity at menu construction.
  Recheck current app configuration and whole-selection scope on click and again
  in the main app after any authorization. Removing or replacing the app rejects
  its old menu; later Finder selections never replace the captured selection.
- Use the existing private, single-use, expiring operation ticket transport.
  A bare URL cannot name an app or files to open. The main app resolves the saved
  app bookmark, validates bundle identity, obtains exact-parent read access only
  when needed, and calls native NSWorkspace opening for the entire selection.
  Hold access and the busy/restart guard until the completion callback.
- When Open with App needs folder access, explain the first-use sandbox request
  and label the picker action Allow Folder / 允许访问. Authorize only the captured
  directory or exact selection parent. Save a read-only security-scoped bookmark
  in a private, bounded, atomically replaced Open with App access store; reuse it
  after relaunch for that folder and its descendants while the saved grant and
  requested target remain in configured, resolved scope. Never add observation
  roots or write permissions as a side effect. Compare the bookmark's saved file
  identity, volume and creation date with fresh directory metadata; a replacement
  at the saved path requires explicit authorization. Revalidate bookmark identity and
  refresh stale bookmarks; unusable grants require explicit authorization again.
  Cancellation, choosing a different folder or failed post-authorization checks
  must neither dispatch the request nor save new grants. Release restored access
  at request completion, including failures. Storage errors must be visible.
- Settings explain that initial folder authorization may be required and saved
  access is reused. Provide a shortcut to the existing folder settings for users
  who want to authorize a configured folder in advance; Full Disk Access does
  not replace sandbox folder authorization.
- Report missing apps, changed configuration, missing files and native open
  failures clearly. Do not change default file associations, clipboard, selected
  file contents, settings-window ownership or existing creation behavior. No shell
  commands, AppleScript, directory crawling, or path/content logging.

## Creation application registry

- Template post-creation applications are selected explicitly and stored in a
  separate registry; selection never exposes a Finder menu entry or changes file
  associations. Reuse bounded capture/bookmark/bundle validation helpers.
- Imported bundle/name hints are inert unless they match an already selected,
  freshly validated local reference. No application crawling or implicit grant.
- Creation uses the receipt executor described in
  [Creation](creation.md#frozen-content-and-post-creation-actions). Explicit local
  application selections use bookmark/bundle validation, and system-default
  opening goes directly through the native default-application API. Neither
  route has a FileMint editor/type/publisher allowlist. Finder selection opening
  retains its own existing tickets and menu behavior.

## Working context

- Core: `OpenWithApplication.swift`, `Preferences.swift`, `FileMenuAction.swift`,
  `FileOperationTicket.swift`. Native: `OpenWithApplicationAccess.swift`,
  `OpenWithSettingsView.swift`, `PreferencesModel.swift`, `FinderSync.swift`,
  `FileOperationCoordinator.swift`.
- Related contracts: [Finder](finder-permissions.md), [startup](startup.md),
  [presentation](presentation.md). Checks: [Core](../verification/core.md) and
  [Finder/native](../verification/finder.md).
