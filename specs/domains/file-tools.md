# File and folder tools

Load for: Optional Finder file/folder actions, selection snapshots and tool switches.

## Module and menus

- File & Folder Tools / 文件（夹）工具 is a sibling of New File in Finder's
  context menu, never a child of it. Settings has a separate page under Extensions.
- The module defaults off, including when older preferences are loaded. Copy
  Names and Copy Paths each have a persistent child switch, initially on. Turning
  the module off preserves child choices and hides its Finder menu. Settings
  keep every child section visible, grayscale and disabled, including checkboxes,
  menu placement and deletion options; pointer and keyboard input cannot edit them.
  All children off hides the empty Finder menu. Permanent Delete and AirDrop
  have independent switches, initially off. Existing creation behavior stays unchanged.
- Each tool has an independent menu-position picker, initially in the submenu; the
  temporary Move Selected Items Here entry has its own placement, initially main.
  Enabled, applicable entries appear exactly once, either directly in Finder or
  inside File & Folder Tools. Hide the group when no applicable children remain.
  Preserve placement while disabled. New File and its contents stay unchanged.
- Settings use small native switches for the module and child enablement. Each tool
  has a grouped row with a short explanation and its own menu
  position. A disabled child keeps its checkbox available when the module is on,
  but its placement and secondary options are disabled. Re-enabling restores
  all choices without resetting them. Move and deletion options stay in their
  respective sections. Presentation owns the shared settings/Finder icon palette.
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
  将所选项目移到此处 at its configured level (main menu by default).
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

## Permanent deletion

- Permanent Delete / 彻底删除 accepts selected files, folders, packages and links.
  It bypasses Trash; deleting a link must not delete its target. Recursive deletion
  is allowed only inside a folder explicitly selected for this operation.
- A persistent segmented choice offers Require confirmation / 需要二次确认 (default) and
  Delete silently / 直接静默删除. The main app owns the native confirmation dialog,
  shows the selected item count, and explains that deletion cannot be undone.
  Cancel is the default. Silent mode skips this dialog, never system authorization
  or failure reporting. A request captured in confirmation mode cannot become
  silent while in transit; switching back to confirmation always takes effect.
- Capture immutable selection and filesystem identities on the explicit click.
  Transfer via private single-use expiring tickets, never bare path deep links.
  Recheck whole selection scope, switches and identities after authorization and
  confirmation, and before deleting each item. Reject roots, duplicate/overlapping
  selections, missing/replaced items and changed parent paths. Never act on a
  newly selected Finder item or follow a selected symlink to delete its target.
- Only the main app deletes; reuse exact-parent sandbox authorization when needed.
  Cancelled authorization or confirmation deletes nothing. Work runs off the main
  thread, serialized with moves; quit/updater restart waits for completion.
  On partial failure, stop and show completed/remaining counts; do not retry
  automatically or report the whole batch as successful. No path/content logging.

## AirDrop

- AirDrop / 隔空投送 is offered for selected files and folders in scope, not for
  background, toolbar or sidebar contexts. Capture the complete selection.
- A private single-use expiring ticket opens the main app's native
  `NSSharingService(named: .sendViaAirDrop)` flow. Check `canPerform(withItems:)`
  for the complete selection, and report unavailable service or sharing failure.
  The user chooses the recipient in the system UI; never auto-send, imitate that
  UI, or fall back to another sharing service. Do not alter the clipboard.
- Keep the service and any sandbox grants alive through success, failure or
  cancellation. System permission prompts remain authoritative. Opening the
  service must not open settings or change creation behavior.

## Desktop aliases

- Send Alias to Desktop / 发送替身到桌面 creates native Finder aliases for the
  complete selected batch of files, folders or packages. It has an independent
  switch, initially off (also on migration), and the usual menu placement picker,
  initially submenu. Existing aliases and symbolic links use Foundation's native
  bookmark semantics; FileMint does not rewrite their targets.
- A Finder alias opens the original item; it does not copy or move its contents.
  Finder owns the icon and arrow. Use Foundation bookmark data with
  `suitableForBookmarkFile` and `URL.writeBookmarkData`, not a symbolic link,
  AppleScript or a custom shortcut format. Never combine alias bookmark options
  with `withSecurityScope`.
- Capture immutable selection and filesystem identity on the explicit click;
  use the existing private single-use expiring ticket transport. Recheck current
  switches, whole-selection scope and source identities after authorization and
  before each write. Reject roots, duplicates and missing/replaced sources.
- The main app resolves Desktop under the operating-system-resolved real user
  home (including the normal iCloud Desktop location). Desktop need not be a
  configured menu location; authorization never expands menu scope. Authorize
  exact source parents for read access and Desktop for writing using native
  directory pickers only when needed. Keep operation grants in a private bookmark
  store and release active access after each request; cancellation creates nothing.
- Preserve the source name, adding ` 2`, ` 3`, etc. before a file extension (after
  the whole name for folders/packages) on collision. Never overwrite any existing
  Desktop item, including dangling links or an item created concurrently. Write
  to an owned staging directory and publish by an exclusive rename; remove only
  that staging directory. No folder traversal or content reads.
- Serialize with existing file operations, run filesystem work off the main
  thread and hold the app's busy/restart guard. On failure, stop and show created
  and remaining counts; keep successful aliases and original resources intact.
  A successful operation opens no settings or confirmation window.

## Working context

- Core policies: `FileTools.swift`, `PendingFileMove.swift`, `FileOperationTicket.swift`,
  `FileMenuAction.swift`, `Preferences.swift`.
- Native adapters: `FinderSync.swift`, `FileOperationCoordinator.swift`; settings in
  `SettingsSections.swift`. The coordinator's active requests also guard app quit
  and updater relaunch.
- Load [Finder](finder-permissions.md) for scope and native callbacks,
  [startup](startup.md) for preference migration, and [presentation](presentation.md)
  for settings navigation. Checks: [Core](../verification/core.md) and
  [Finder/native](../verification/finder.md).
