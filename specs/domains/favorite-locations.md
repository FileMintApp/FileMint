# Favorite locations

Load for: saved file/folder shortcuts, quick lookup, Finder add and locate menus, or favorite-bookmark recovery.

## Entry and behavior

- Favorite Locations / 常用文件（夹） has its own settings page under Extensions and its own Finder menu root. It does not depend on File & Folder Tools. The settings page and menu bar remain usable when the Finder extension is off.
- In already-configured Finder folders, an eligible selected file or folder has one direct **Add to Favorite Locations** action by default. A separate settings switch hides this add entry. Finder never offers an action outside its configured scope. Adding a favorite never changes monitored folders.
- The favorite submenu appears only when saved entries exist and its separate switch is on by default. It shows at most six pinned and four most recently located distinct entries, then Search All. The menu bar offers the same bounded shortcuts and Search All. Menu construction uses only cached display data, with no filesystem checks or directory reads.
- A right-click add captures the complete selection in reported order and transfers it through a private one-use ticket. The main app rechecks folder scope, local URLs, identities and authorization before storing anything. Never silently add a valid subset of an invalid selection. Already saved targets are skipped and reported separately. Normal adds go to Ungrouped without a modal form.
- The app can add multiple files/folders via NSOpenPanel or a user drop on the management page, including locations outside Finder menu scope. The user-selected items must be local, available files or directories, not symlinks; resolve packages as files. No folder crawl or content read is needed.
- Locating a saved folder opens that folder in Finder. Locating a file or package opens its parent and selects it. Direct file opening is an explicitly labeled secondary action. A saved path is never executed simply by activating a favorite.

## Large-list interaction and persistence

- The settings page has one virtualized list with search over saved display names, groups and stored path text; file/folder/unavailable filters; flat groups; pinned order; and batch pin, group and remove actions. The quick palette focuses search on open, supports arrows, Return and Escape, and searches the saved catalog only. A common name is disambiguated by parent path. Duplicate entries are not created.
- Pin order is user controlled. The recent section ranks explicit additions and successful locate actions, so a newly added item is immediately reachable. Users can clear locally stored locate timestamps; pinned and recent entries are deduplicated. Neither menu nor search discovers files on disk.
- Store user-created security-scoped bookmarks, stable file identity, display name, kind, group, pin order and last-used time in a private, atomically replaced catalog. Only the main app writes. The Finder extension reads a cached bounded projection. On use, resolve and validate the bookmark and identity; a same-path replacement, missing item, unavailable volume or changed authorization must not open a guessed target. Keep the entry and offer explicit Relink or Remove. A damaged catalog blocks new writes; the settings page offers a confirmed backup-and-reset operation that preserves its original bytes, without changing Finder scope or overwriting main preferences.
- The interface stays responsive with at least 1,000 saved entries; large lists do not increase Finder menu item count. Saved paths/content are never logged. Use bilingual native controls, keyboard operation, VoiceOver labels, and restrained adaptive FileMint styling.

## Working context

- Rules and storage: `FavoriteLocation*` in FileMintCore. Native access and quick UI: `App/FileMint/Favorite*`, `PreferencesModel`, `FileMintApp`. Finder adapter: `FinderSync.swift` and `FileOperationTicket.swift`.
- Load [Finder](finder-permissions.md) for scope and authorization, [startup](startup.md) for settings navigation, [presentation](presentation.md) for native style. Verification: [Core](../verification/core.md) and [Finder/native](../verification/finder.md).
