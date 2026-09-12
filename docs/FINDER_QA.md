# Finder and native UI acceptance

Use a disposable folder and the same ad-hoc signatures shipped in the DMG.
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
- Open the Full Disk Access guide; verify it explains sandbox folder authorization separately.
- Confirm no file-icon setting or inactive favorites setting is exposed.
- Legacy development JSON/plist settings import through the File menu; protected
  App Group directories are never accessed automatically.

## Finder

- Confirm the extension is listed and enabled in macOS settings.
- Background and file context menus within monitored folders show text-only
  New File actions; the root entry has the FileMint logo. Other apps may contribute similarly named menus.
- Verify each quick action creates on disk, then verify automatic name increments.
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
- Final GitHub asset checksum and attestation match the exact uploaded DMG.
