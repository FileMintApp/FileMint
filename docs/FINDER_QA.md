# Finder and native UI acceptance

Use a disposable folder and the exact signatures shipped in the DMG (Developer
ID and Apple notarization starting with 0.5.3).
Do not treat a menu click or a successful build as evidence of a created file.
Record actual results in ACCEPTANCE.md.

## Creation

- Enter `demo.js`, paste multiline Unicode including `{{year}}`, create with
  Command-Return; inspect the resulting filename and exact UTF-8 bytes.
- Change a selected format; verify filename synchronization and preserved edits.
- Type an unknown suffix; verify it is used verbatim without being registered.
- Cancel the destination picker; verify the previous location and draft remain.
- Return in the editor inserts a newline; paste, select-all and undo work.
- Existing-name confirmation defaults to Cancel. Cancelling preserves the file;
  confirming replaces only the selected file.

## Types and preferences

- Navigate General, Creation, Templates & Types, Finder & Folders and About
  using the sidebar and Up/Down keys. Verify selection and keyboard focus remain
  distinguishable in light/dark mode, without a bright solid selection block.
- At the 840×600 minimum content size, check both languages, list actions, editor
  sheets and scrolling of the expanded Full Disk Access guide. New File remains
  accessible from each page. About menu commands reuse the same settings window.
- Add `.toml` with starter content; verify it appears in the selector and Finder.
- Edit, disable, reorder and remove that custom type. Built-ins remain intact.
- Restore built-ins; verify custom types remain after explicit confirmation.
- Choose a working folder once, relaunch, and verify access is remembered.
- Switch Follow System/English/Chinese; verify settings, Finder menus and panel labels agree.
- Toggle Show in menu bar off/on, relaunch, and verify the choice survives.
- Install in Applications; verify default login registration and the actual
  ServiceManagement status. Disable/re-enable through both app and macOS
  settings; confirm the app never silently re-registers an externally disabled item.
- With settings closed and the menu bar hidden, test both Finder creation routes.
- Open the Full Disk Access guide in Chinese and English. Confirm it explicitly
  says the system switch is authoritative and that a visible guide does not mean
  access is denied. Both the enabled and off/missing-entry instructions must be
  readable, with the folder list and its action buttons still usable.
- “Check in System Settings…” must open Full Disk Access. Observe the existing
  FileMint switch without changing it; returning to FileMint must not claim that
  merely visiting settings granted or revoked access.
- Folder labels must describe only a saved folder authorization or a request to
  choose that folder once, separately from the Full Disk Access guide.
- Confirm no file-icon setting or inactive favorites setting is exposed.
- Legacy development JSON/plist settings import through the File menu; protected
  App Group directories are never accessed automatically.

## File and folder tools

For isolated settings regression checks, build with
`bash scripts/build_file_tools_settings_harness.sh` and open its printed QA app.
It uses the production settings view and icons with disposable preferences;
`last-state.json` beside the app supports readback after disabled-control attempts.
The QA toolbar changes only fixture language/appearance and exposes native icon
menus. The initial checks reject missing, template or monochrome tool icons.
This fixture does not prove that Finder has loaded the new extension.

- Start with old preferences: File & Folder Tools is off and New File is unchanged.
- Enable the module; verify its root is a sibling of New File in item context menus.
- Verify the tools root has a mint/blue wrench/screwdriver icon and the temporary
  Move Selected Items Here action has a mint/teal boxed right-arrow icon. Every
  tool has its matching settings icon in either menu location: blue names,
  indigo paths, teal move, orange deletion, purple AirDrop and blue desktop aliases. Icons remain readable
  in light, dark and highlighted menus. New-file format rows remain text-only.
- Toggle each child independently, then disable all; no empty root remains.
- Disable/re-enable the module and relaunch: child choices and placement are preserved.
- With the module off, all tool settings sections remain visible and grayscale.
  Try their checkboxes, placement pickers, move destination and deletion options
  with pointer and keyboard: none can change. The module checkbox still works.
  Re-enable and verify all previous choices return. With only one child disabled,
  its checkbox remains usable while its secondary settings are disabled.
- Set tools to all main, all submenu, and mixed placements: each enabled action
  appears exactly once, empty groups disappear, and New File remains unchanged.
  Move Selected Items Here has an independent placement and remains conditional.
- Enable Permanent Delete using disposable fixtures only. Default confirmation
  has Cancel as the default; cancel preserves every item, confirm bypasses Trash.
  Silent mode skips that dialog; permissions and failures still surface. Verify
  files, nonempty folders, packages, links, multi-selection and partial failures.
- Enable AirDrop for files/folders/multiple items: the system recipient window
  opens with the captured selection. Cancel without sending, then verify the next
  tool action and normal quit work. Test unavailable AirDrop and folder access.
- Enable Send Alias to Desktop (off on migration). Select a file, a nonempty
  folder and an App bundle; verify Desktop entries are Finder aliases with the
  native arrow, double-click opens the originals, and originals are unchanged.
  Repeat to check numbered names and select items already on Desktop. Existing
  files, folders and dangling links must never be overwritten.
- Cancel source or Desktop authorization: create nothing and release the busy
  guard. Grant only the exact fixture folders, relaunch and verify saved grants
  work without another picker. Menu scope must remain unchanged. Check partial
  failures and removed/replaced originals. A redirected/iCloud Desktop and
  disconnected/file-provider originals require separate native evidence.
- Confirm native checkboxes, descriptions and both placement/deletion controls remain
  readable at minimum window size in both languages and appearances.
- Select files, folders and multiple items with Unicode/spaces/compound extensions;
  paste copied names and paths into a scratch document and compare exact lines.
- Verify background, sidebar, toolbar and out-of-scope menus do not expose the
  selection-tools submenu. A pending move may add its separate root action to an
  in-scope background folder or one selected non-package directory.
- Open menus in two windows and execute the older one: captured items must be used.
- Check Chinese/English at minimum settings size, keyboard navigation and light/dark.
- Select a file, image, script, App bundle, folder, symlink and multiple items;
  Move File / Folder must save the selection without moving anything yet.
- Right-click the destination: Move Selected Items Here appears at its configured
  main-menu or submenu level, without a filename; multiple items show a count.
  No cancel item or expiry exists.
- Relaunch before completing the move: the pending selection and source grants
  survive. Changing selections in Finder alone must not change the pending batch.
- Prepare a new selection, then use an older open menu: it must not move the new
  batch. Reopen the menu to use the new batch.
- Disable/re-enable the master and move child switches: entries hide and restore,
  pending state stays. Existing New File actions continue working.
- Verify exact-folder authorization and closing its dialog without moving.
- Complete moves on the same volume and across volumes; check contents and source
  removal. Verify same-name conflicts never overwrite, including dangling links.
- Test partial failure: completed items stay moved, remaining items can be retried.
- Test missing/replaced sources, same-folder and descendant destinations; no wrong
  file is moved. Quit/updater restart must defer while a move is in flight.
- For isolated sandbox checks without replacing FileMint, build with
  `bash scripts/build_move_sandbox_harness.sh` and run the generated app explicitly.
  It uses synthetic external fixtures and its own preferences/container. This
  does not prove the installed Finder extension's visible menu behavior.

## Finder

- Confirm the extension is listed and enabled in macOS settings.
- Test the actual desktop wallpaper background separately from opening Desktop
  in a Finder window. Both must show New File, and both creation routes must use
  Desktop, including when no Finder window is open. Repeat after relaunch.
- With home removed and scope restricted to Desktop, Documents must not receive
  a menu merely because the shared observation ancestor is registered. Missing
  targets must never become Desktop requests. A known Downloads target must
  remain Downloads. Default settings must show menus for the dynamically resolved
  home background and files, including after upgrading the old three-folder defaults.
- Background and file context menus within monitored folders show text-only
  New File actions; the root entry has the FileMint logo. Other apps may contribute similarly named menus.
- Verify each quick action creates on disk, then verify automatic name increments.
- Create at least three files consecutively from fresh context menus. After each
  completed creation/reveal, right-click again and confirm FileMint is still
  present. Repeat New File… and cancellation. Check that the extension process
  survives app-launch completions and no new crash report appears.
- Move to another Finder folder after opening a menu: its action must keep its
  captured destination, not pick up the later selection.
- New File… opens the same main-app panel; repeated requests focus the same draft.
- No Finder callback invokes main-actor UI directly on the XPC callback queue.
- Quick routes require a matching single-use, unexpired local ticket. The app
  validates enabled templates and monitored paths before creating anything.
- Check no temporary request tickets remain after successful consumption.

## Distribution

- `make verify`, Release build, nested signatures, both architectures, matching
  app/extension versions, DMG verification and portable checksum all pass.
- Launch the copied DMG app, not only the DerivedData app.
- Repeat Gatekeeper approval and extension activation on a clean Mac when one
  is available. A development Mac cannot prove clean-install trust behavior.
- Final GitHub asset checksum, Developer ID signatures and stapled Apple ticket
  match the exact uploaded DMG. GitHub build attestations apply only to versions
  through 0.5.1.
- About shows Special Thanks / 特别感谢, the exact nickname 阿逼, the
  `https://github.com/bibinocode` link and the localized signing acknowledgement.
## Creation window isolation

- Close settings, then Finder → New File → New File…. Only the creation panel
  should appear. Cancel it; settings must remain closed.
- Quit FileMint completely and repeat from Finder. The URL launch should open
  only the creation panel, including when Show in menu bar is disabled.
- Type a draft name, then invoke New File again. The existing draft should be
  focused with its contents preserved.
- Open the app explicitly or choose Open FileMint / About. Settings should still
  be reachable. About and the update commands should use the same settings window.
- Explicitly open settings and confirm FileMint appears in the Dock; minimizing
  keeps it reachable there. Close settings and confirm the Dock item disappears.
  Both Finder creation routes, including a cold launch and a creation panel on
  its own, must leave settings closed and add no Dock item. With the menu bar
  hidden, reopening from Applications or Spotlight must still open settings.
- When automating this check, do not treat an inspection tool's explicit app
  reopen as part of the Finder URL action. Observe the URL and reopen separately.
