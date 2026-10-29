# File and folder tools

Load for: Optional Finder file/folder actions, batch rename, selection snapshots and tool switches.

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
- Selection tools appear only for selected items in configured folder scope.
  Copy Paths also appears when right-clicking a folder's background in scope,
  including a configured root, and copies that current folder's path. No other
  selection tool uses the background directory. Do not use a background, toolbar
  or sidebar menu's stale selection. All selected URLs must be local file URLs
  in scope; never silently operate on a subset.
- Capture the selection in Finder's reported order, or the background container
  directory for Copy Paths, when building the menu. Menu actions use that
  immutable target, not the later window/selection. Recheck current module,
  child and scope preferences before executing an old menu item. Background
  Copy Paths keeps the existing switch, icon and menu-placement preference.
- Copy Names writes each last path component including its extension; Copy Paths
  writes each full filesystem path. Multiple values are joined by one newline,
  with no trailing newline. Preserve Unicode, spaces and literal characters.
- Only an explicit menu action writes the clipboard. Copy Names and Copy Paths
  never read file contents. Do not crawl folders, monitor the clipboard or log paths. Copy actions do not
  create, rename or delete files. Report clipboard-write failure.
- Chinese product copy uses 拷贝 consistently, including 文件（夹）名称 and
  文件（夹）路径; English uses Copy.

## Hide and unhide selected items

- Hide & Unhide / 隐藏与取消隐藏 is a File & Folder Tools child with an independent
  switch, initially off for new/missing/invalid settings, and the usual submenu/main
  placement. It replaces the Finder-wide hidden-item toggle in settings/menu bar.
- Operate only on the complete captured selection of 1–1,000 ordinary local files
  or directories in configured scope. Packages and aliases are opaque entries;
  never inspect their contents or follow aliases. Reject symbolic links, special
  files, duplicate objects and missing/replaced entries. Background/toolbar/sidebar
  contexts never use a stale selection for this action.
- Read bounded selected-entry metadata to name the menu. All visible gives one
  **Hide This Item / 隐藏此项目** (plural **Hide Selected Items / 隐藏所选项目**).
  All hidden gives one **Unhide This Item / 取消隐藏此项目** (plural **Unhide Selected
  Items / 取消隐藏所选项目**). Mixed or unknown visibility offers both explicit
  actions at the same configured menu level. Never label an attribute action
  “Show Hidden Files”, “Display” or “Toggle”.
- Capture item and real-parent identities only after the click, then transfer
  them with the existing private single-use ticket. The main app rechecks switches,
  resolved scope, complete selection and identities after exact-parent write
  authorization and around mutation. Reuse existing folder grants; additional
  picker grants last only for the operation and never expand monitored roots.
- Use no-follow descriptors and metadata APIs to set/clear the BSD hidden flag
  on the captured objects. Read the bounded 32-byte FinderInfo metadata as well;
  Unhide also clears its legacy invisible bit. Pin parent/item identities, preserve other flags and FinderInfo fields,
  filenames, contents and directory descendants, and verify the result. No shell,
  simulated input, Accessibility permission, Finder preference change or restart.
  Already matching attributes are idempotent; the menu's explicit requested state
  remains authoritative if another action changed visibility after menu creation.
- Names beginning with a period stay name-hidden. Reject an Unhide request
  containing such a name before changing any selected item, and explain that this
  action never renames it. Reject other known hidden mechanisms that cannot be
  removed through these metadata operations, rather than reporting them as visible. Unsupported
  filesystems/permissions fail explicitly. Preflight the complete batch before
  edits; a later failure reports processed/total counts without claiming atomicity.
- Success is silent. Serialize with existing file operations and keep access alive
  through worker cleanup. Settings explain that Finder's Command-Shift-Period
  shortcut can temporarily reveal hidden items so they can be selected and unhidden.

## Copy file contents

- Copy File Contents / 拷贝文件内容 has an independent child switch, default off
  for new, missing or malformed preferences, and the usual submenu/main placement.
  It replaces opening a text file and copying its entire content. Offer it only
  for one captured ordinary local file in scope, never a directory, package,
  alias, symbolic link, special file, background or multiple selection.
- Menu construction probes bounded name/type metadata only. Common code, script,
  configuration, markup and plain-text names, system-declared text types and
  extensionless files are candidates; eligibility is not proof of valid content.
  Images (including SVG), PDF, Office and RTFD are excluded. HTML, Markdown,
  XML and code copy their source text, never rendered content or highlighting.
- Read only after the explicit click, in the main app via a private single-use
  60-second ticket containing the captured item/real-parent identities. Recheck
  current switches, resolved folder scope and identities after read authorization
  and before clipboard publication. Use the file-information read guarantees:
  coordinated background I/O, pinned parent/descriptor, no following links,
  change detection and complete cleanup. No content in tickets, logs or caches.
- Bound both source bytes and decoded UTF-8 text to 8 MiB. Read to completion
  within the bound; never truncate. Decode plain text as UTF-8 (optional BOM) or BOM-declared
  UTF-16 LE/BE strictly, excluding exactly one encoding BOM from the text. A
  subsequent leading U+FEFF belongs to the content and must be preserved. Preserve all
  remaining characters, whitespace, indentation and line endings. Reject invalid
  encodings, NUL, binary control characters and empty content; whitespace-only
  text is valid. Do not guess legacy encodings or replace malformed sequences.
  When clipboard text starts with U+FEFF, its UTF-8 representation needs a separate
  encoding BOM so native pasteboard readers do not consume the content character.
- RTF is conditional on production-path integrity and native paste compatibility
  checks. When admitted, publish the original validated RTF bytes together with
  complete plain text in one clipboard item. Do not flatten/re-encode the rich
  representation. Malformed, attachment/object-bearing or unsupported RTF must
  fail without publishing a partial text extraction. Receiving apps choose the
  representations they support; arbitrary cross-app layout fidelity is not promised.
  Admit a deliberately bounded RTF 1 subset: a single body of text with font and
  color tables, character styles (font, size, bold, italic, underline, strike,
  foreground/background color and baseline), and paragraph alignment, spacing,
  indentation and tab stops. Allow only explicitly recognized formatting and
  document-metadata controls; unknown controls and destinations fail closed.
  Headers/footers, footnotes, annotations, fields/links, lists, tables, hidden text,
  discretionary-hyphen and quarter-em-space controls, Unicode alternate
  destinations (`upr`/`ud`), embedded objects and attachments
  are outside this subset, even if a native importer could partially read them.
- Accepted RTF text uses ASCII, ANSI Windows-1252 (implicit or explicit code page
  1252), and/or UTF-16 Unicode `u` escapes, with group-scoped `uc0` or `uc1`
  fallback. Accept signed 16-bit values and Cocoa's unsigned 16-bit spelling
  (the numeric range is -32768 through 65535). Other positive code-page
  declarations are accepted only for ASCII/Unicode-escape text; reject encoded
  high-bit text bytes that would depend on those code pages. Font tables may use
  ANSI charset 0, never a font-specific or system-default text encoding.
  Recognized Cocoa version/platform/text-scaling metadata and expanded color
  tables are allowed; they must not introduce another text destination. Native
  newline escapes and `par` produce LF; `line` produces U+2028; literal tabs and
  `tab` produce TAB. Font, color and expanded-color tables belong only to the document header, before
  body text; header declarations cannot be introduced inside the body.
  Validate control parameters, fallback consumption and paired UTF-16 surrogates
  strictly; never repair malformed text. Independently extract the complete body
  in Core, then require the native importer's UTF-8 text bytes to match exactly
  before publishing either representation. Keep both source and extracted output
  within 8 MiB. Native rich/plain-text checks must cover accepted Unicode, original
  bytes, fonts, colors and paragraph attributes, plus rejection of unsupported or
  malformed RTF without changing the clipboard. Extend this subset only with
  explicit SPEC changes and corresponding integrity/native-receiver evidence.
- Reuse configured access or request the exact file with a native read-only
  picker. Do not expand Finder scope, add persistent grant stores or request Full
  Disk Access. Known undownloaded placeholders require downloading in Finder first;
  unknown providers may materialize during ordinary reads. Report actual errors.
- Capture only the clipboard change counter on the click and check it again on
  publication; no polling or content inspection. If another copy has occurred,
  discard the old request instead of overwriting it. Prepare every representation
  before replacing the clipboard. Read/decode/cancel/policy failures leave it
  untouched; report a final pasteboard-write failure without claiming restoration.
- Serialize active work with other file operations. Consume/reject busy tickets
  promptly. Cancel/close and quit/update restart cancel and wait for worker cleanup
  before releasing grants or the busy guard. Successful copies are silent: do not
  show a success panel or notification. Show a compact cancellable progress panel
  only for slower work and close it as soon as the operation succeeds or finishes
  cancelling. Keep actionable failures visible until dismissed; never open settings
  or require an additional Run/Copy step after the menu click.

## File information and checksums

- File Info… / 文件信息… has an independent child switch, default off for new,
  missing or malformed preferences, and the usual submenu/main placement. It is
  offered only for one captured ordinary local file in scope, never a background,
  toolbar, sidebar or multiple selection. Hide it for directories, packages,
  symbolic links, Finder aliases, special items and unavailable type metadata.
  Menu construction may probe only the selected item's type metadata; never
  open content, follow a selected link, enumerate folders or query providers.
- Opening the native panel reads metadata only: name, kind, logical file size,
  location, creation and modification dates. Unknown values say unavailable.
  Ordinary directories show their own metadata without content size, enumeration
  or item counts. Packages, symbolic links, Finder aliases and special items are
  explained as unsupported if reached through an older capture; never read their
  content or follow their target. These defensive states do not make them eligible
  for a new menu entry.
- Each window starts with SHA-256 selected. SHA-512, SHA-1, MD5 and All Four
  Algorithms are available. Calculate is explicit; opening, changing selection
  and focusing never calculate. Freeze selection during a calculation. Changing
  algorithms or recalculating invalidates old results and disables copying.
- Group Close and Calculate/Recalculate together at the footer's right edge,
  with the primary calculation action last. During work, Cancel occupies that
  same action position; Close remains beside it and retains cleanup semantics.
- Use system CryptoKit and a bounded 1 MiB buffer off the UI thread. Update only
  selected algorithms from the same verified descriptor, in a single pass for
  All. Hash file data bytes only, including sparse logical zero bytes; exclude
  names, paths, resource forks and extended attributes. Empty files are valid.
- Capture item and real-parent identities asynchronously on the click, transfer
  via a private single-use 60-second ticket (at most 1 MiB), then recheck current
  switches, resolved scope and identities after read authorization. Coordinate
  reading on the worker thread, verify the coordinated URL, open without following
  the final symlink and verify the descriptor. Compare identities, byte counts,
  size, modification/change timestamps and available generation/version metadata
  at both ends. Discard all digests on incomplete reads, changes, errors or cancel.
  This is change detection, not an atomic snapshot against noncooperating writers.
- Known undownloaded placeholders (including dataless items) require downloading
  in Finder first. Never request a download or crawl provider domains. Ordinary
  reads on unknown providers may still cause provider materialization or network
  access; report actual access/I/O failures without claiming universal offline I/O.
- Show actual byte progress, cancellable waiting, and per-window results only.
  Close/Escape cancels and releases handles/grants after worker cleanup. Active
  preparation/reading is mutually exclusive with other FileMint file operations;
  consume and reject new busy requests promptly, focusing the panel. Idle result
  windows release the guard; recalculation obtains it again and revalidates.
  Quit/update restart requests cancel active reads and wait for cleanup.
- Copy each digest as continuous lowercase hexadecimal; All copies MD5, SHA-1,
  SHA-256, SHA-512 as four `ALGORITHM: value` lines, LF-separated without a trailing
  newline or hidden path. Report clipboard failure. No clipboard polling,
  persistent digest/history cache, content/path logging or upload.
- Comparison accepts explicit user input for one selected algorithm: trim only
  leading/trailing whitespace, accept ASCII hex in either case and exact length.
  Distinguish invalid input, match and mismatch with text and symbols. All mode
  asks for a single algorithm first. Checksums are not encryption or proof of
  origin; MD5/SHA-1 have persistent compatibility-only warnings.

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
- Consume ordinary operation tickets when the main app receives them, using
  receipt time for the existing 60-second validity check. Preserve FIFO execution
  behind an active operation or panel, but do not let that waiting time expire an
  already accepted request. Recheck current scope, preferences and identities
  when executing; expired or replayed inbound tickets remain invalid.
- Selection parents and destination require sandbox access. Use existing access
  when available, otherwise ask for the exact folder via the main app's native
  directory picker. Cancelling authorization leaves pending state intact; this
  is not a separate cancellation feature. No broad entitlements or keyboard hooks.
- Reject missing/replaced sources, root items, overlapping selections, same-folder
  destinations, and moving a folder into itself/descendants (including aliases
  through symbolic-link parents). Never overwrite or merge existing targets.
  Symbolic links are moved as links, not their targets. Cross-volume operations
  use the native file manager; a reported failure is not treated as success.
- Before a move or permanent deletion becomes irreversible, claim the source
  entry into a private sibling staging location and verify that the claimed entry
  is still the captured filesystem object. Restore an unexpected replacement
  exclusively and stop; never act on it. Keep same-volume publication exclusive
  and copy into private destination staging before exclusive publication across
  volumes; restore the source on copy failure.
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
- Batch duplicate/overlap validation scales with selected path depth rather than
  comparing every pair, so large valid selections do not cause quadratic work.
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

## Batch rename

Implementation contract; completed phases and native verification are tracked separately. The
[task](../../docs/tasks/2026-10-14-batch-rename.md) records phase status and evidence.
The following rules apply only to batch rename, not to the existing tools above.

### Selection and availability

- Batch Rename… / 批量重命名… is a File & Folder Tools child, default off for
  new, absent and malformed saved values. Its independent placement defaults to
  submenu. The module switch and configured scope govern normal rename and undo;
  interrupted-operation recovery has the separate authority defined below.
- Offer the Finder entry for 2–1,000 distinct local URLs with one lexical parent
  inside configured scope. Use cached preferences and URL/count checks when
  constructing the entry; inspect no additional filesystem metadata there.
  Background, toolbar and sidebar menus have no batch rename entry. No app-local
  item picker, menu-bar rename entry or global hotkey in this version.
- On the explicit click capture the complete selection and filesystem identities;
  main-app authorization and validation must confirm one real parent object,
  available regular files or ordinary directories, and distinct volume/file
  identities. Two selected hard links to the same object are unsupported.
  Invalid, missing, replaced or unsupported neighbors reject the entire batch.
- Initial support is local, writable APFS with known case-sensitivity, exclusive
  rename support and stable parent/item identities. Validate the selected items,
  actual parent, scope, grants, availability and required filesystem capabilities.
  Missing or failed required checks reject the batch; a file URL alone does not
  prove locality. System permissions and native operation results remain
  authoritative. Do not copy, request downloads or broaden access to bypass a
  denied, unavailable or unsupported operation.
- Ordinary local files and ordinary directories are both in the first version.
  Renaming a directory changes its own entry; do not enumerate, rename or classify
  its descendants. Possible unverified descendant environments do not by
  themselves disqualify an otherwise eligible ordinary directory.
- Proving that a location is unmanaged is not an admission or implementation
  prerequisite. Do not require provider lookups, custom-service queries or
  cloud-root exclusion scans. Missing optional provider information is neither
  proof of safety nor a reason by itself to reject an otherwise valid request;
  it never substitutes for required identity, authorization or operation checks.
- NAS, iCloud and third-party sync compatibility remain unverified, not a gate
  for ordinary local implementation or acceptance. Do not promise universal
  compatibility or infer it from a successful local call. Requests still obey
  the same first-version filesystem scope and native safety checks; no separate
  provider-specific support path is part of this task.
- Reject symlinks, Finder aliases, packages and nonregular nodes. Protect root
  and volume-root objects; the canonical /System, /Library, /Applications,
  /Users and /Volumes directory objects; the OS-resolved real user home and its
  Desktop, Documents, Downloads, Library, Applications, Pictures, Movies, Music
  and Public directory objects; every configured observation-root object; and
  FileMint's storage and known owned operation-workspace subtrees. Also reject
  selected directories that contain any such private storage/workspace: renaming
  an ancestor must not move preferences, tickets, pending moves or recovery state.
  Check resolved ancestor relationships against known protected locations without
  enumerating directory contents; unresolved protection checks reject the batch.
  Match actual canonical locations/identities, not any ordinary folder sharing
  those names. A special directory's ordinary children remain eligible only when
  they satisfy these protections; for example, the real user's Library/Application
  Support cannot be renamed because it contains FileMint's private storage.
- Keep the 1,000-item cap and existing 1 MiB serialized ticket limit independent;
  report either limit and reject rather than truncate. A selection may contain
  unchanged rows and commit fewer than two changes. A zero-change plan writes
  nothing and cannot be submitted.

### Names and ordering

- Freeze each original filename's exact UTF-8 spelling, hidden marker, body and
  suffix once per session. Detach one leading period as a protected hidden marker.
  Directories have no suffix. For files, use the longest case-insensitive suffix
  match from tar.gz, tar.bz2, tar.xz, tar.zst and d.ts, requiring a nonempty body;
  otherwise the last remaining period separates a suffix only when both sides
  are nonempty. Preserve the suffix's original bytes, including its period/case.
  Thus .env has marker '.', body 'env', no suffix; .env.local has marker '.',
  body 'env', suffix '.local'; archive.TAR.GZ keeps '.TAR.GZ'. No type/content
  inference or dependency on the configured creation-template catalog.
- Rules and name-list lines operate only on the body. Reattach the protected
  marker and suffix after calculation; do not reparse the generated body.
  Changing hidden status or extensions is unavailable. For regular files whose
  captured suffix is empty, a changed body must contain no period (U+002E):
  README -> README.txt and .env -> .env.local are invalid. This guard uses the
  frozen input kind/suffix; it does not reparse or repair the generated body.
  Directories and files with a protected suffix may contain literal periods
  inside the body; Photos -> Photos.2026 is valid for an ordinary directory.
  A list line containing a suffix is not guessed or stripped.
- Validate changed outputs without trimming, substituting, truncating, fallback
  names or output Unicode normalization. Reject an empty body, a body beginning
  with a period, complete names '.'/'..', leading/trailing Unicode whitespace,
  trailing periods, /, :, backslash, Unicode control category Cc and line/paragraph
  separators. Preserve format scalars needed for emoji, including ZWJ; do not use
  the creation sanitizer's broader control-character set for rename.
- Changed output components are at most 255 UTF-8 bytes, additionally bounded by
  the positive native name limit when available. This conservative product cap
  is not a claim about the filesystem's universal maximum. Original components
  up to 1,024 UTF-8 bytes may be captured. Unchanged originals are not rewritten
  to satisfy the output policy. Recovery/undo restores the exact previously
  captured original component without applying the new-output body, character
  or length policy, including the suffixless-period restriction. It must still
  validate a single component with no slash/NUL and never '.' or '..'.
- Default to natural ascending original-name order: numeric, case-insensitive
  Foundation comparison with en_US_POSIX, then raw UTF-8 byte order, then captured
  ordinal as stable tie breakers. Descending reverses that total order. Sorting
  is independent of system-language changes and not a claim about Finder's
  display or user click order. Freeze the order in every submitted plan.
- Compare final-name namespace keys using canonical decomposition and, only on
  a known case-insensitive volume, Unicode case folding with en_US_POSIX; no
  diacritic, width or compatibility folding. This conservative precheck is not
  a complete filesystem emulator. Probe exact candidate locations and let native
  exclusive rename be authoritative. Unchanged means byte-identical spelling,
  not namespace equivalence: case-only changes remain changes.
- All final rows, including unchanged ones, reserve their final names. Duplicate
  targets or an occupied target outside the batch are errors. A target currently
  held by another changing row is a permitted dependency, not an external conflict.
  Do not treat a metadata/access error as target absence.

### Rules and name lists

- Rule mode supports ordered literal, case-sensitive replace/delete; prepend or
  append text; numbering before/after a current body or a unified body; and
  locale-independent Unicode uppercase/lowercase. No regex, ignore-case search,
  dates, arbitrary-position insertion or extension editing. Recompute from
  original bodies on every revision; validate final names rather than silently
  repairing intermediate text. Replace all nonoverlapping scalar-exact matches
  left-to-right once; do not search again inside inserted replacement text.
  An empty search string is invalid; deletion uses an empty replacement.
- Numbering covers all selected rows in order: start + zero-based sorted ordinal × step.
  Start is 0…Int64.max; step is 1…Int64.max; padding width is 1…20 and is a minimum,
  never digit truncation. Check arithmetic before allocation. Defaults are start 1,
  step 1, width 3 and separator '_'. For an empty chosen body emit digits alone;
  otherwise join body/digits with the explicit separator in the chosen position.
- At most 32 rules, 1 KiB UTF-8 per literal parameter and 4 KiB UTF-8 per working
  body. Reject an oversized intermediate before building it. Invalid parameters
  block the whole plan even if some rows would be unchanged.
- Name-list mode is exclusive with rule mode, has a 1 MiB UTF-8 input cap, and maps
  one body to every selected row, including unchanged rows. Normalize CRLF and CR
  to LF for line splitting; ignore exactly one final line terminator. Preserve
  all line text; internal blank/whitespace-only lines, count mismatch or invalid
  resulting names are errors, not skipped or trimmed entries.
- Changing order with a populated active list requires explicit reassignment
  confirmation, with Cancel as default. Confirmation retains the text, rebuilds
  the mapping and invalidates the old plan; cancellation preserves mapping/order.
  Mode changes preserve both in-memory drafts and invalidate submission. Returning
  to a populated list after its order changed requires the same reassignment;
  cancellation keeps the previous mode/order. Clipboard text is read only on
  explicit Paste; oversized input leaves previous text intact. There are no saved
  rule/list presets or clipboard history.

### Preview and request ownership

- One app-owned rename/recovery panel and one immutable source batch at a time.
  Show every original/final name, state and actual changed/unchanged/error counts.
  Async metadata work is bounded and off the UI thread; outdated generations
  cannot enable Execute. Any rule, mode or order change invalidates submission
  until its newest preview checks finish. No filesystem watches or directory scans.
- Explicit Rename N Items / 重命名 N 个项目 is the final confirmation; there is
  no silent/quick mode or second generic confirmation dialog. Invalid, checking,
  conflicting or zero-change plans disable it. Before execution, closing/cancelling
  changes no user directory entry and creates no recovery workspace.
- Consume rename tickets promptly at intake, including while another operation
  owns the coordinator, preserving the current 60-second/single-use validation.
  Busy requests are consumed and explicitly rejected, focusing an existing rename
  panel when present; never replace its inputs or queue a rename behind a long
  preview. Other operation types retain FIFO execution after prompt ticket intake.
  An accepted panel has no ticket-age expiry; it is revalidated on submission.
- Submission freezes batch/parent identities, complete original/final components,
  row order, parameters and revision. Recheck preferences, resolved scope, grants,
  identities and targets just before the first mutation and before each forward
  step. Menu eligibility and per-step continuation are distinct: do not apply the
  two-item menu minimum to a remaining single item.

### Execution and recovery

P1's immutable naming plan contains the captured name descriptors, order, mode,
parameters and revision, and may consume caller-supplied exact-target observations.
The pure planner performs no filesystem I/O. Missing target observations remain
checking; failures are not absence. Observations from another batch/revision or
different planning inputs cannot validate the current preview. Freezing this
plan does not grant filesystem authority or satisfy the native rechecks below.

- The main app alone renames, serialized with existing file operations. Hold exact
  parent write access and a pinned parent identity/directory handle; use same-volume
  relative exclusive operations where available. No content reads/copies or user-item chmod,
  cross-volume fallback, shell, AppleScript, wider observation or new entitlements.
- Before the first source mutation, persist an immutable versioned manifest with
  operation ID/kind, original batch, parent/volume identities and bookmark, stable
  row IDs, original/target components, and known staging-directory/slot names and
  identities. Reserve the bounded private operation slot before allocating its
  staging directory, so an interrupted preparation is visible even before a full
  manifest exists. Unverified staging ownership is preserved for explicit manual
  resolution. Record each step's intent before the syscall and observed outcome
  afterwards. Journal errors stop forward work; a save failure is not success.
- Stage all changing sources into the batch's private 0700 sibling directory,
  exclusively, then verify each claimed object's identity before publishing any
  result. An unexpected replacement is preserved and restored exclusively, never
  published as the captured item. Staging preserves unchanged rows and supports
  case-only changes, swaps and cycles without overwriting user entries.
- Publish the frozen targets exclusively; native collision or unsupported-operation
  errors stop. Verify identity at each publication. Failure, explicit Stop and
  preference/scope revocation initiate bounded best-effort rollback, not automatic
  forward retries or a revised naming plan.
- Rollback first claims any already-published owned entries back into staging,
  then restores pre-operation components exclusively. A conflict/replaced parent
  must not overwrite, delete or redirect another object. Retain originals still
  in staging and report each row's actual state/location when restoration fails.
  Cleanup may remove only verified owned state and empty staging directories;
  it must never recursively erase remaining or unknown entries.
- Recovery reads only known manifest locations after an explicit user action,
  checks original/stage/target locations and identities, and reconciles syscall/
  journal-update crash gaps. Deduplicate same-namespace aliases for case-only
  changes; multiple independent identity matches, missing objects, corrupt records
  or unverifiable parent identity stop recovery and preserve evidence. Never infer
  success from a logged phase alone or scan user folders to find missing objects.
- On restart offer Restore Pre-operation Names / 恢复操作前名称, not Resume Rename.
  For an interrupted undo, pre-operation names are the renamed names at undo start.
  Compensation may restore the same parent object through its valid bookmark or
  an explicit exact-object picker even when the feature/scope is now disabled;
  it cannot move into a different directory or widen configured scope. Cancellation
  or denied access preserves the recovery record without writes.
- Each exclusive step can succeed independently; the batch is not atomic. Report
  restored, renamed and recovery-required states honestly. Guarantee no silent
  overwrite and preservation of owned originals, not unconditional rollback or
  persistence across power loss. An unresolved/corrupt rename record blocks new
  batch rename and undo until restored or explicitly retired by the manual
  resolution protocol below; it does not disable unrelated idle tools.

### Manual resolution of recovery records

- When restoration is unavailable or the user has handled the files manually,
  offer Export Recovery Evidence and Unblock… / 导出恢复证据并解除阻塞… outside
  disabled feature settings. This explicit action acquires or retains exclusive
  coordinator ownership, rejects unrelated in-flight work, and holds the
  busy/quit/update guard through export and metadata finalization.
  It works for missing objects, corrupt records and unsupported record versions;
  preserve opaque bytes instead of requiring a valid rename manifest to proceed.
- Explain that this action does not restore or verify user files, that remaining
  staging files stay in place, and that automatic recovery and the current last
  rename undo will no longer be available. Require explicit acknowledgement of
  manual handling and these consequences, with Cancel as default. Report the
  result as manually closed, never restored or successfully renamed.
- Before retiring state, export the raw bytes of the known private rename control
  files, including indexes, manifest/journal and the current receipt when present,
  to a user-chosen local destination. Preserve corrupt/unsupported bytes, verify
  the complete export, and never overwrite an existing export. Fixed, bounded
  atomic-write scratch slots are control files too and are included in this
  snapshot. Only after verified export and an unchanged snapshot may the exact
  exported index-write scratch slot be reused to publish the retirement marker.
  Reuse retains a blocking control entry throughout the write/rename crash window;
  it never clears or overwrites the active index before atomic marker publication. Access only owned
  control-file locations; do not trust paths in corrupt records, inspect user
  staging directories, or include preferences, tickets or pending moves.
- After verified export, atomically persist a versioned retirement marker in the
  same unresolved-operation slot, binding the exported snapshot to the state
  being retired. Finalization invalidates the exported receipt and removes only
  the exact private control files covered by the verified snapshot before clearing
  the blocker. Changed, unreadable or unexported state, denied export access, and
  any export/verification/journal/cleanup failure keep the blocker and evidence.
  The action never renames, deletes or recursively cleans user items or staging.
- An interrupted retirement remains blocked and offers explicit metadata-only
  finalization from the durable marker; it must never replay the retired rename
  or undo. A damaged marker preserves evidence and permits a fresh raw export.
  Cancellation before retirement leaves active state intact; cancellation/close
  afterwards pauses metadata finalization with the blocker intact and never
  reactivates the retired operation. Temporary retirement state uses the existing
  bounded operation slot, not a second operation or an
  app-managed archive history; completed exports are user-managed evidence files.

### Persistent state and undo

- Reusable parent-folder grants live separately from operation/receipt state,
  as specified by [batch rename authorization](finder-permissions.md#batch-rename-authorization).
  Consuming or forgetting undo, replacing its receipt, or retiring a recovery
  record does not forget directory authorization. This private grant store is
  excluded from operation-evidence and preferences/template export and sync.
- Keep a private, bounded versioned operation store, separate from preferences,
  ticket files and existing pending moves: at most one unresolved operation and
  one most-recent successful rename receipt, 8 MiB per manifest/receipt or operation
  event stream; atomic-write scratch uses a fixed finite set of known slots with
  the same per-file bound. Interrupted scratch is unresolved state, never invisible
  debris or an automatically discarded record. Directories use 0700 and files
  0600. Per-step state can use compact
  bounded records; do not repeatedly expand names/paths into unbounded history.
- A valid commit marker atomically binds a successful operation to its receipt
  after every target is verified. A crash during receipt/cleanup must not turn a
  committed success into an instruction to automatically restore. Retain failed
  cleanup/recovery state; do not automatically purge or replace it to make space
  for a new batch. Explicit manual retirement follows the separate protocol above.
- Retain one successful receipt until it is explicitly forgotten, successfully
  undone, explicitly retired with recovery evidence, or replaced by the next
  successful normal rename. Failed/zero-change attempts do not replace it.
  Receipt fields contain only parent authorization/
  identity and the original/final components and item identities needed for undo;
  persist no rule inputs, clipboard, file contents or telemetry/path logs. Do not
  include operation state in preferences/template import/export or cloud sync.
- Undo Last Batch Rename… / 撤销上次批量重命名… is available in the result panel
  and main app's File menu, not Finder menus or Finder Command-Z. It requires the
  normal module/child switches, current resolved scope and exact-parent grants.
  Show a complete reverse preview and require explicit Undo N Items. Preflight
  all current identities and original-name destinations before any write.
- Undo uses the same journal/staging/exclusive machinery. A failed/cancelled undo
  rolls back to its own pre-operation state and preserves the successful receipt;
  completed undo consumes the receipt and does not create a redo/history entry.
- Startup inspects only private indexes/records, presents passive recovery status,
  and does no user-directory probe or mutation until an explicit action. Damaged
  or unsupported-version records retain their bytes; do not silently reset,
  reinterpret names, grant access or treat an unreadable store as empty.

## Working context

- Core policies: `FileTools.swift`, `PendingFileMove.swift`, `FileOperationTicket.swift`,
  `FileMenuAction.swift`, `Preferences.swift`.
- Native adapters: `FinderSync.swift`, `FileOperationCoordinator.swift`; settings in
  `FileToolsSettingsView.swift`. P1 rename rules/planning are `BatchRenameRule`,
  `BatchRenamePlanner` and `RenameNamePolicy` in Core; native execution and private
  state live in `BatchRenameService`, `BatchRenameNative` and `BatchRenameStore`.
  The app owns `BatchRenameController`, `BatchRenameView`, `BatchRenameOperations`
  and exact-parent access. The coordinator's active requests also guard app quit
  and updater relaunch.
- Load [Finder](finder-permissions.md) for scope and native callbacks,
  [startup](startup.md) for preference migration, and [presentation](presentation.md)
  for settings navigation. Checks: [Core](../verification/core.md) and
  [Finder/native](../verification/finder.md).
