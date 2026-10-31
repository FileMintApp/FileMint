# Creation and drafts

Load for: Naming, content, collisions, creation routes and the native draft panel.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## The two creation paths

- Finder creation entries each have an independent Hidden / Main menu / Submenu
  placement: New File…, New File from Clipboard, Paste Image as File and every
  enabled template by stable ID. New entries default to Submenu. Hidden affects
  Finder exposure only; app/menu-bar actions and enabled template choices remain.
  Each level lists the three visible fixed actions in their established order,
  followed by templates in saved order. Insert a separator only between nonempty
  action/template sections. The New File submenu root follows main-level creation
  entries and exists only when it contains entries. No entry appears twice; hide
  the creation group when empty without suppressing other modules.
  Actions/templates retain their own icons across placement changes. The root
  icon applies only to the nonempty submenu. Placement changes never alter routes,
  destination snapshots, template content, order or enabled state.
- Finder → New File → New File… opens one compact persistent native panel.
  Name, editable extension selector, destination, optional plain-text content,
  Cancel and Create are the whole flow. The main app owns this single panel;
  Finder forwards only the target directory for drafts, so requests from either entry point
  focus the same draft. A draft route never writes a file without Create.
  Quick actions instead enqueue an expiring, single-use local request and pass
  its random identifier to the app. The app consumes it only for an enabled
  template and a configured folder; a bare deep link cannot create a file.
- The app, menu bar and Quick Search open creation drafts directly, with the
  first configured folder (or the user's home) initially selected. Change the
  destination through the panel's Save Location control; do not require a
  separate folder picker before showing the draft. Opening/cancelling a draft
  does not add a monitored folder or persist a new authorization.
- Quick Search selects an enabled template by stable ID in that same panel.
  Recheck enablement/existence before opening and preselect the exact template.
  An existing draft is focused unchanged; cancelling or a stale template creates
  nothing. Finder retains its captured destination; if it needs authorization,
  show the draft first and request access only when Create needs it.
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
- Ordinary Quit also waits for in-flight creation and template import work. A
  write in progress cannot be interrupted just because no update is installing.
- Drafts are not stored. Cancelling never creates a file or changes the destination.

## External drafts and launcher requests

- The public version-1 `filemint://draft?v=1` route opens a user-confirmed draft.
  Native Shortcuts parameters and public URLs share one typed request, validation,
  admission and writer. They never enter the private quick-creation trust path.
  The existing `new` route retains its own strict fields and behavior.
  The [feature system gate](startup.md#shortcuts-and-launchers) rejects external
  requests before admission on unsupported systems, without changing this route.
- Draft fields are `v`, `name`, `template`, `text`, `directory`, `favorite`,
  `location` and `id`. Require exactly `v=1`; reject unknown or duplicate fields,
  missing values, empty name/IDs, malformed percent or UTF-8, NUL, userinfo,
  port, fragment and any path. `directory`, `favorite` and `location=ask` are
  mutually exclusive. A directory is an absolute local path suggestion; IDs
  never grant access. Search accepts only `filemint://search?v=1`.
- Validate the received encoded string before URL construction. Decode values
  exactly once; `+` is literal, not a space. The AppKit URL callback exposes the
  representation received by the app, not the caller's original spelling.
  Upstream normalization of malformed percent/Unicode cannot be reversed or
  treated as trust. Exporters encode each value independently.
- Reject, never truncate, inputs above 16 KiB encoded URL, 8 KiB URL text, 1 MiB
  native text, 1 KiB name, 4 KiB directory or 256-byte template/favorite ID
  limits (all UTF-8). Names and identifiers reject controls/path escape;
  text preserves whitespace, Unicode and literal template tokens, except NUL.
- Resolve an enabled exact template before suffix/content. A provided complete
  suffix must match that template; a bare name gains its suffix. Without a
  template use the existing filename/default-format rules. Missing text uses
  template content; present text, including an empty string, is verbatim and
  cannot be supplied to an Office template. Freeze one timestamp per draft.
- Shortcuts retains old values in hidden conditional parameters. Its adapter
  selects only the current location/content enum's fields, validates required
  active values and then creates the same disjoint typed request. Hidden folder
  or text values cannot grant access or override the selected mode. Public URL
  conflicting fields remain invalid.
- Admission is atomic and permits one preparing/presented external session.
  Existing manual drafts retain all input and undo. Native modal/sheet, active
  writes, preparation and exclusive operations reject as busy without queuing.
  Success means a visible, active, keyboard-interactive draft; it never means a
  file was saved. Cancelled/failed preparation cannot later present a window.
- A UUID request ID deduplicates only in memory: the same normalized request
  focuses its active session, a changed request conflicts, and a finished ID
  cannot reopen for ten minutes. Keep at most 512 bounded metadata/fingerprint
  records, never retain finished text/paths or persist/log their fingerprints.
  Unpresented failed preparation releases its reservation for retry.
- The source, exact template and full destination remain understandable in the
  one existing creation panel. Initial external focus selects the filename stem
  while retaining its suffix; refocusing an existing draft preserves selection.
  Ask-location opens that draft before any picker.
  Only Create writes through the existing exclusive/collision/receipt path.
  Explicit destination failures preserve input and never guess another folder.
  Temporary directory access belongs to the session through write cleanup.
  See [Finder and permissions](finder-permissions.md) for access and identity.

## Clipboard text draft

- New File from Clipboard is an explicit Finder New File action and a main-app/menu-bar action. Finder sends only the captured destination in a private, single-use, expiring ticket; the main app reads one clipboard item only when handling the action. Menu construction never reads clipboard data.
- Accept nonempty plain text up to 8 MiB as UTF-8, including whitespace-only text and a plain-text representation of rich text. Reject file references, multiple items, image-only content and oversized text. Never interpret URLs or template tokens in the captured text.
- Prefill the single creation panel as an edited `txt` draft. Format and filename remain editable; switching text formats preserves the exact content. Only Create writes; Cancel or canceled folder selection writes nothing. An existing draft is focused unchanged without reading the clipboard.
- The main-app entry captures text on invocation and opens the draft directly;
  Finder uses its menu-captured destination. Preparation and an open draft block
  updater relaunch. Permission errors retain the draft and use the existing
  directory authorization flow.

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

- Quick creation and the shared panel use the selected template's bundled or
  managed asset.
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

## Frozen content and post-creation actions

- Capture one UTC timestamp per draft/request and share the pure content resolver
  between preview and writer. Unedited template-mode content follows normalized
  filename and selected source; an actual edit becomes exact verbatim bytes.
  Filename, template and visibility changes never resample time or discard edits.
  Collisions still arbitrate exclusively and render the actual candidate name.
- Create and Open is default off. Off uses the legacy reveal/no-action preference.
  On resolves an explicit temporary override, exact selected template action, or
  untemplated fallback. New panels Follow Template; that follows template changes,
  while explicit overrides stick until reset. Cancel/finish never saves overrides.
- Hide action controls when off; label Create and Open only for an effective open
  action. Preview off keeps the editable text field and Office notice; on exposes
  read-only result/Edit Content without changing output or image confirmation.
- Both creation routes inject one app-owned completion executor. Snapshot action,
  application and gate generation at submission, use only the successful receipt,
  and dispatch at most once while holding access/pending-work guards. A successful
  disable advances the generation; off-origin or off/on-stale requests cannot open.
- Before dispatch/retry, check created-file identity/type and app bookmark/bundle
  identity. An explicitly selected local application opens the saved receipt
  through NSWorkspace, including text, Office and binary files; the chosen app
  decides which formats it supports. Portable hints without a validated local
  application remain unable to launch anything. System-default opening passes
  the saved file directly to NSWorkspace so macOS uses its current association,
  including per-file choices; do not substitute a FileMint-selected editor.
  Both routes activate the receiving app and open the file in one native request,
  launching it if necessary. No FileMint editor allowlist, publisher-signing
  profile or text/Office/binary filter may block either configured open action.
  Preserve macOS's own launch/security decisions, never bypass them, and never
  silently fall back to another app or execute a shell command.
- Opening failure closes the saved draft and offers Reveal, retry or another app.
  Distinguish unavailable selected apps, system-default opening failures and
  explicit native handoff errors in the recovery message.
  Retry uses a receipt and cannot invoke the writer. Missing/replaced files cannot
  be recreated or silently substituted. Quit/restart guards include dispatch work
  after the panel closes. Native callback success proves handoff only.

## Working context

- Implementation entry points: `FilenamePolicy.swift`, `TemplateRenderer.swift`, `CustomFileDraft.swift`, `FileCreationService.swift`, `BinaryFileWriter.swift`, `CreationRoute.swift`, `QuickCreationTicket.swift`, `ClipboardImageEncoder.swift`; `SharedUI/CustomFileSavePanelController.swift`, `App/FileMint/PlainTextEditor.swift` and creation handling in `PreferencesModel.swift`.
- Verification: [Core checks](../verification/core.md), [Finder/native checks](../verification/finder.md) when UI or routing changes.
- Expand context only when needed: Load [templates](templates.md) when format selection or saved types change; [Finder and permissions](finder-permissions.md) for target scope, tickets or authorization; [startup](startup.md) for settings-window ownership.
