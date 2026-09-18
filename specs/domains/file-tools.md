# File and folder tools

Load for: Optional Finder file/folder actions, selection snapshots and tool switches.

## Module and menus

- File & Folder Tools / 文件（夹）工具 is a sibling of New File in Finder's
  context menu, never a child of it. Settings has a separate page under Extensions.
- The module defaults off, including when older preferences are loaded. Copy
  Names and Copy Paths each have a persistent child switch, initially on. Turning
  the module off preserves child choices and hides its controls and Finder menu.
  All children off hides the empty Finder menu. Existing creation behavior stays
  unchanged.
- Tools appear only for selected items in configured folder scope. Do not use a
  background, toolbar or sidebar menu's stale selection. All selected URLs must
  be local file URLs in scope; never silently operate on a subset.
- Capture the selection in Finder's reported order when building the menu. Menu
  actions use that immutable snapshot, not the later window/selection. Recheck
  current module, child and scope preferences before executing an old menu item.
- Copy Names writes each last path component including its extension; Copy Paths
  writes each full filesystem path. Multiple values are joined by one newline,
  with no trailing newline. Preserve Unicode, spaces and literal characters.
- Only an explicit menu action writes the clipboard. Do not read file contents,
  crawl folders, monitor the clipboard, or log paths. Copy actions do not
  create, rename or delete files. Report clipboard-write failure.
- Chinese product copy uses 拷贝 consistently, including 文件（夹）名称 and
  文件（夹）路径; English uses Copy.

## Two-step move

- Move File / Folder / 移动文件（夹） has a persistent child switch, initially
  on under the default-off module. It accepts files of every suffix, directories,
  application bundles and symbolic links as items, never by inspecting content.
- Choosing it replaces the pending selection with an immutable batch, captured
  with filesystem identity. Only the main app writes this private, atomic state.
  It survives relaunch, has no expiry or cancel entry, and is independent of the
  clipboard. Turning switches off hides/blocks actions but preserves the batch.
- A configured destination context menu displays Move Selected Items Here /
  将所选项目移到此处 at the root, a sibling of New File and File & Folder Tools.
  Multiple items append a localized count. No filenames in the title. This is
  offered for a background directory or one selected ordinary directory, never
  a regular file, application/package, toolbar or ambiguous multiple selection.
- The destination and batch ID are captured with the menu. Execution checks the
  latest switches, folder scope and batch ID. An old menu cannot move a newer
  batch. A bare URL cannot prepare or execute a move: use private single-use
  expiring transport tickets; their expiry does not expire a prepared batch.
- Selection parents and destination require sandbox access. Use existing access
  when available, otherwise ask for the exact folder via the main app's native
  directory picker. Cancelling authorization leaves pending state intact; this
  is not a separate cancellation feature. No broad entitlements or keyboard hooks.
- Reject missing/replaced sources, root items, overlapping selections, same-folder
  destinations, and moving a folder into itself/descendants (including aliases
  through symbolic-link parents). Never overwrite or merge existing targets.
  Symbolic links are moved as links, not their targets. Cross-volume operations
  use the native file manager; a reported failure is not treated as success.
- Execute away from the main thread and serialize requests. Persist completion
  after each successful item; only unfinished items remain after a partial failure.
  A successful batch removes the temporary menu. An error leaves unfinished work
  available indefinitely and explains the failed stage. Normal quit/updater restart
  waits while requests, authorization or moves are in flight.
- Do not log source/destination paths. No directory discovery or background scans;
  recursive I/O occurs only as part of an explicitly requested directory move.

## Working context

- Core policies: `FileTools.swift`, `PendingFileMove.swift`, `FileMoveTicket.swift`,
  `FileMenuAction.swift`, `Preferences.swift`.
- Native adapters: `FinderSync.swift`, `FileMoveCoordinator.swift`; settings in
  `SettingsSections.swift`. The coordinator's active requests also guard app quit
  and updater relaunch.
- Load [Finder](finder-permissions.md) for scope and native callbacks,
  [startup](startup.md) for preference migration, and [presentation](presentation.md)
  for settings navigation. Checks: [Core](../verification/core.md) and
  [Finder/native](../verification/finder.md).
