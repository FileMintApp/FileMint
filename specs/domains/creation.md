# Creation and drafts

Load for: Naming, content, collisions, creation routes and the native draft panel.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## The two creation paths

- Finder → New File → a file type creates immediately in the captured target
  directory. Menu labels include the extension. The top-level entry shows the
  FileMint logo plus localized “New File” / “新建文件”; submenu rows remain text only.
- Finder → New File → New File… opens one compact persistent native panel.
  Name, editable extension selector, destination, optional plain-text content,
  Cancel and Create are the whole flow. The main app owns this single panel;
  Finder forwards only the target directory for drafts, so requests from either entry point
  focus the same draft. A draft route never writes a file without Create.
  Quick actions instead enqueue an expiring, single-use local request and pass
  its random identifier to the app. The app consumes it only for an enabled
  template and a configured folder; a bare deep link cannot create a file.
- The app and its menu bar also offer New File… with a native folder picker,
  so creation remains useful without Finder integration.
- Creation requests open or focus only the single creation panel. A Finder URL
  must not open or restore settings, including a cold launch or a request after
  settings was closed. Closing/cancelling the panel leaves settings closed.
  Settings is a separately owned native window, shown by an ordinary app
  launch or explicit Open FileMint / About / Settings actions, with no automatic
  SwiftUI primary-window creation or restoration during URL handling.
- Return creates from single-line fields; Return in the content editor inserts a
  newline; Command-Return creates anywhere; Escape cancels; Tab moves focus.
- Tab and Shift-Tab cycle explicitly through filename, format, destination,
  editable content, Paste, Cancel and Create. Skip hidden/disabled controls,
  including fixed image formats, without requiring the system's full keyboard
  navigation setting. Tab in the editor navigates rather than inserting a tab;
  it never creates a file. Focus remains visible and wraps within the panel.
- The editor supports standard copy/paste, select-all and undo. A visible Paste
  button inserts clipboard text at the selection. Clipboard is read only at the
  user's explicit paste action. Non-text clipboard data produces a short message.
- Typed/pasted content is written as exact UTF-8, including whitespace, Unicode,
  and literal `{{fileName}}` or `{{year}}`. Changing the extension preserves it.
- All code/content editors disable smart quotes, dashes and text replacement.
  Template token expansion is a single pass; tokens inside a substituted filename
  are literal data and are never expanded again.
- Until content is edited, known formats seed their saved template content and
  render supported placeholders (`{{fileName}}`, `{{date}}`, `{{isoDate}}`, `{{year}}`).
  Date placeholders use UTC for deterministic output.
- The extension selector searches preset names, aliases and saved custom types.
  Same-suffix templates remain distinct choices by template ID, and the selected
  template name is visible. Unedited names use its saved default filename.
  Its menu can always show all choices, even after a format has been selected.
- A full filename typed or pasted into Name is authoritative: `demo.js` is saved
  as exactly `demo.js`, and synchronizes the extension selector to `js`, even if
  that type is disabled or not saved. Selecting another format then updates the
  displayed filename. Typing just `demo` appends the currently selected suffix.
- Custom extensions are text-file suffixes, not converters for binary formats.
  Empty suffixes, whitespace, controls, path separators, trailing dots and empty
  extension components are invalid. Surrounding whitespace and leading dots are
  normalized. The most recently edited name or suffix wins; changing a compound suffix
  replaces the entire prior suffix. File names cannot escape the destination.
- An update-triggered restart waits for an open draft or in-flight creation;
  it never discards the draft or interrupts a file write.
- Drafts are not stored. Cancelling never creates a file or changes the destination.

## Clipboard image creation

- Paste Image as File is an explicit New File menu action in Finder and the app.
  Building a menu never reads the clipboard. Finder passes only an expiring,
  single-use private ticket containing the captured in-scope destination.
- The main app captures one PNG/TIFF bitmap on the action, then decodes/encodes
  off the main thread. File references and multiple clipboard items are rejected;
  never fetch paths, URLs or remote content. No clipboard writes or monitoring.
- Accept one static image, at most 64 MiB encoded, 16 million pixels and 16,384
  pixels per dimension. Normalize orientation, preserve transparency and displayed
  dimensions, produce PNG and a bounded 512-pixel preview using system Image I/O.
- Reuse the single creation panel with image preview, filename and destination.
  Keep PNG fixed; hold captured bytes until cancellation/creation. An existing
  draft is focused unchanged without reading a new clipboard image.
- Only Create writes the encoded bytes. Collisions increment; cancel creates
  nothing. Missing authorization offers the existing directory picker. Preparation
  and open drafts block updater relaunch. Errors never discard another draft.
- Binary creation receives explicit bytes; a filename extension alone never
  changes text into an image/document. Binary bytes bypass template rendering.

## Creating an Office document

- Quick creation and the shared panel use the selected template's managed asset.
  The panel identifies the document template, fixes its suffix, and replaces the
  text editor with a concise original-format/content notice. It does not render
  binary data as text or apply text variables to Office package bytes.
- Selecting a document template while a text draft contains edited content is
  rejected with guidance to save/cancel that draft first. Filename edits are
  preserved, applying the document's correct suffix. Image drafts stay separate.
- Both paths create an independent exact-byte copy. Same-name documents are
  never replaced. Import/validation and creation block updater relaunch while
  active; failed imports do not expand Finder folder scope or clipboard access.

## Safe creation and performance

- Normal creation uses exclusive filesystem creation, never check-then-overwrite.
  Racing creations retry the next incremented name without overwriting data.
- Default collision names: `Untitled.txt`, `Untitled 2.txt`, `Untitled 3.txt`.
- Quick creation supports increment or fail. Replace is never a stored default.
- Custom creation asks before replacement, with Cancel as the default button.
  A directory is never replaced. Replacement atomically replaces the directory
  entry, not the content of a symlink's target.
- Finder captures the destination with the menu action, rather than resolving a
  potentially different target later. No path or clipboard content is logged.
- A background context menu uses Finder's container URL directly, including
  Desktop; missing sandbox metadata must never turn that directory into its
  parent. Missing targets never guess another destination.
- After either creation route, the Finder extension remains available for the
  next context menu and creation. App-launch completion callbacks may run on a
  background queue; they must not inherit main-actor isolation. Error UI is
  dispatched explicitly to the main actor.
- Preference refresh is notification-driven, with no polling timers or background
  directory enumeration. File I/O runs away from the main thread, and duplicate submission
  is disabled until it completes. Draft inputs are locked during the write so
  completion cannot discard edits made after submission. An actionable error keeps the draft intact.

## Working context

- Implementation entry points: `FilenamePolicy.swift`, `TemplateRenderer.swift`, `CustomFileDraft.swift`, `FileCreationService.swift`, `BinaryFileWriter.swift`, `CreationRoute.swift`, `QuickCreationTicket.swift`, `ClipboardImageEncoder.swift`; `SharedUI/CustomFileSavePanelController.swift`, `App/FileMint/PlainTextEditor.swift` and creation handling in `PreferencesModel.swift`.
- Verification: [Core checks](../verification/core.md), [Finder/native checks](../verification/finder.md) when UI or routing changes.
- Expand context only when needed: Load [templates](templates.md) when format selection or saved types change; [Finder and permissions](finder-permissions.md) for target scope, tickets or authorization; [startup](startup.md) for settings-window ownership.
