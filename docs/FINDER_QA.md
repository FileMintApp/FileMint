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
- Without changing system keyboard settings, Tab/Shift-Tab cycles through name,
  format, destination, content, Paste, Cancel and Create with visible focus.
  Tab from the content editor must not insert text or submit. PNG drafts skip
  the fixed format and absent text controls; verify forward and reverse wrap.
- Existing-name confirmation defaults to Cancel. Cancelling preserves the file;
  confirming replaces only the selected file.
- Clipboard images: use an owned PNG/TIFF fixture, inspect the full preview,
  create twice and verify PNG dimensions/alpha, numbered names and preserved
  original bytes. Cancel writes nothing; an existing draft remains unchanged.
- Office templates: import owned DOCX/XLSX files through the picker, then create
  with both Finder quick actions and the panel. Compare bytes with the source and
  managed asset; remove the source and repeat. Missing/damaged assets must not
  create a file. Text already entered in a draft must survive attempted document
  selection. No Office app is launched by creating a copy.

## Types and preferences

- Save two same-suffix templates with different default filenames and contents.
  Select each by name, change the format default, disable/remove that default,
  restart and check fallback and migration. Imported document templates retain
  their format/content while display name and default filename remain editable.

- Confirm File Creation (Templates & Types / Creation), Extensions (file tools /
  resources / Open with App), and Preferences (General / Finder & Folders / About) remain distinct
  at 840×600. Sidebar arrow navigation follows this visual ordering.

- Navigate General, Creation, Templates & Types, Finder & Folders and About
  using the sidebar and Up/Down keys. Verify selection and keyboard focus remain
  distinguishable in light/dark mode, without a bright solid selection block.
- At the 840×600 minimum content size, check both languages, list actions, editor
  sheets and scrolling of the expanded Full Disk Access guide. New File remains
  accessible from each page. About menu commands reuse the same settings window.
- With the Finder extension disabled, open General in both languages and confirm
  the setup card and manual Settings button are visible at 840×600. Open system
  settings from the button; return without enabling and confirm the card remains.
  Enable FileMint there, return to the app and confirm its actual status refreshes
  and the card disappears. Disable it again and confirm the card returns.
- Add `.toml` with starter content; verify it appears in the selector and Finder.
- Edit, disable, reorder and remove that custom type. Built-ins remain intact.
- Restore built-ins; verify custom types remain after explicit confirmation.
- Choose a working folder once, relaunch, and verify access is remembered.
- Switch Follow System/English/Chinese; verify settings, Finder menus and panel labels agree.
- In General, Theme and Interface language pickers share the switches' trailing
  edge in both languages. Check the same alignment in Creation and tool settings.
- Switch Theme between Follow System, Light and Dark. Verify the sidebar, native
  controls, title bar, open creation/resource panels and sheets update immediately.
  Relaunch and import settings to check persistence. Return to Follow System and
  change the system appearance; FileMint follows without rewriting the saved choice.
  Finder and the system appearance remain independently controlled by macOS.
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

## Image resource tools

- With Finder resource integration off, choose an image through the main app's
  Use Tools tab and process it. The explicit app entry must work while Finder
  switches and monitored-folder scope remain unchanged. Cancelling the system
  picker creates nothing; all selected-file grants end when the panel closes.
- Inspect the preview/inspector/footer layout at 820×560 in both appearances and
  languages. Selecting a later batch image loads a bounded preview without growing
  the cache past 20. Changing parameters reuses previews rather than decoding again.
- Edit OCR text, including clearing all of it and typing again. Copy/Save use the
  edited literal text; smart quotes/replacement remain disabled. Results disappear
  on panel close.

Build `bash scripts/build_resource_tools_harness.sh` for an isolated native fixture.
Its app automatically exercises all six production panels in Chinese/light and
English/dark and processes only its synthetic images. Inspect visible windows
with native screenshots; AppKit view-cache renders omit SwiftUI drawing layers.
It neither loads owner preferences nor proves installed Finder or sandbox grants.

- Use only a disposable image folder. Old preferences leave Resource Tools off;
  toggling off/on preserves its six child choices and never changes file-tool settings.
- Select PNG/JPEG/HEIC files in scope: Resource Tools is a sibling root. Mixed
  images/PDF/WebP, out-of-scope selections and background/toolbar contexts have no
  resource entries. Opening a menu does not decode images or run Vision.
- Open each of the six production parameter panels; verify Chinese/light and
  English/dark at minimum size, list order, labels, scrolling and Run/Cancel.
- Cancel a folder picker and confirm no outputs. Check parent-folder authorization
  separately from source reads; select another output folder without changing menu scope.
- Convert transparent PNG to JPEG: white background; PNG preserves transparency.
  Compression retains format; resize honors longest edge without enlargement.
- ICNS/ICO contain all advertised resolutions; PNG icons create a complete new
  folder. Repeat operations and include existing names/dangling links: no overwrite.
- Stitch two visibly different images, change order and orientation, and inspect
  actual pixels. Oversized canvas fails before allocation with an actionable message.
- OCR fixture text remains local; no clipboard change before Copy. Cancel Save
  without writing; TXT bytes match the displayed text. Empty text is not an error.
- Cancel a batch; finished outputs remain and no partial file is published. Closing
  or quitting during processing cannot interrupt a committed output or release grants early.
- Verify Finder callbacks on the installed signed build, source/output sandbox grants,
  cloud placeholders and macOS 13/Intel separately from isolated native fixtures.

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

## Open with App

- In the Extensions settings page, add VS Code using the native picker. Check
  default submenu placement, app icon, name and location. Cancel adding and verify
  no changes. Add multiple apps; re-add one and verify no duplicate or placement reset.
- Switch entries between main/submenu; relaunch and check persistence. Remove the
  last entry and verify the empty state. Removal must not uninstall the application.
- Drag apps up and down, then check their order in each Finder menu level and after
  relaunch. Re-add a reordered app and verify it keeps its saved position. Check
  the keyboard reorder buttons too.
- Check Chinese/English, light/dark and 840×600, including keyboard controls,
  long app names, unavailable apps and scrolling with a long list. Add again after
  moving an app to repair its saved location/access.
- In installed Finder, select a file, folder and mixed batch in scope. Each entry
  appears once at its configured level, using the app's native icon. The group uses
  the shared stack symbol and disappears when all entries are main-level or absent.
  Background/toolbar/sidebar and partly out-of-scope selections have no app entries.
- Open using a configured app; observe the complete batch and settings-window
  isolation. Open an older menu after changing selection/configuration: never open
  the new selection or a removed/replaced app. Include Unicode and literal symbols.
- Remove/move the target app or source file, cancel any exact-parent authorization,
  and use an app that cannot open folders. Verify clear errors, no default-app or
  clipboard changes, and no remaining busy guard after completion/cancellation.
- Use `bash scripts/build_open_with_harness.sh` for the isolated sandbox transport
  and NSWorkspace check; it does not replace installed Finder or third-party QA.

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
- Background and file context menus within monitored folders show New File under
  its own submenu by default; its root entry has the FileMint logo and action rows
  are text-only. Switch its location to the main menu and verify New File…,
  Paste Image as File and each enabled type appear directly, once and in template
  order; switch back and relaunch to check persistence. Other apps may contribute
  similarly named menus.
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
