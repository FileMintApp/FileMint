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
