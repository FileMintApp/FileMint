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
  its location; never silently launch a different app as a fallback.

## Finder and opening

- Offer entries only in item context menus with a nonempty, complete selection
  of local files/folders in configured scope. Background, toolbar and sidebar
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
- Report missing apps, changed configuration, missing files and native open
  failures clearly. Do not change default file associations, clipboard, selected
  file contents, settings-window ownership or existing creation behavior. No shell
  commands, AppleScript, directory crawling, or path/content logging.

## Working context

- Core: `OpenWithApplication.swift`, `Preferences.swift`, `FileMenuAction.swift`,
  `FileOperationTicket.swift`. Native: `OpenWithApplicationAccess.swift`,
  `OpenWithSettingsView.swift`, `PreferencesModel.swift`, `FinderSync.swift`,
  `FileOperationCoordinator.swift`.
- Related contracts: [Finder](finder-permissions.md), [startup](startup.md),
  [presentation](presentation.md). Checks: [Core](../verification/core.md) and
  [Finder/native](../verification/finder.md).
