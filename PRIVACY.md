# Privacy

FileMint creates files and optional Finder file/folder actions locally. It has no
analytics, account system, cloud sync or advertising. File creation and local file
tools do not require a network connection; AirDrop is performed by macOS's system
sharing service only when you explicitly choose it.

- File names, paths and contents are not uploaded or logged.
- The clipboard is read only when you invoke Paste, a standard paste shortcut,
  New File from Clipboard or Paste Image as File. The text creation action reads
  one plain-text item when explicitly chosen and uses it to prefill a draft;
  only Create writes it to a file. Copy Names and Copy Paths write to the
  clipboard only after you explicitly choose either Finder menu action. The
  clipboard is never watched or saved as a history.
- Open with App passes selected items or Finder's captured, authorized directory
  to a local app you configured. It does not change default file associations;
  the receiving app controls what it does afterward.
- Copy File Contents reads one supported ordinary local text file only after
  its explicit Finder action. Source and decoded text are each limited to 8 MiB.
  It validates complete text or a supported RTF subset before publishing the
  clipboard; failures and cancellation do not publish partial results. Content
  is not logged, cached or uploaded. Another copy supersedes pending publication.
- Quick Search matches the existing configured actions, templates, favorites and
  settings locally, without crawling folders. Query and selection restoration
  stays in memory for the current app session. The optional global shortcut
  registers only its configured key combination with macOS while FileMint runs;
  it does not record unrelated keys or require Input Monitoring or Accessibility.
- Resource Tools reads only explicitly selected local images. Conversion,
  compression, resizing, icons, stitching and Vision text recognition run on the
  Mac without uploading images or recognized text. Previews and OCR results are
  held for the open panel and released on close. OCR writes the clipboard only
  after Copy Text, and writes a TXT file only after Save. Original images are
  preserved; owned temporary output is cleaned up on completion or cancellation.
  Cloud placeholders must be downloaded by the user before processing.
- Preferences contain enabled file types, custom template content, language,
  login/menu bar choices, automatic-update preference and last check attempt time,
  file-tool switches, menu placement, deletion-confirmation choice, folder paths and security-scoped bookmarks needed to remember
  folder access. They are stored privately in ~/Library/Application Support/FileMint.
  Single-use requests there expire after 60 seconds and are removed when consumed.
  A prepared move, permanent deletion or AirDrop request keeps only its captured
  item identities and required scoped-folder bookmarks for the explicit operation.
  This state is not uploaded, logged as telemetry or used to inspect file content.
- Draft filenames and pasted contents are not persisted by FileMint. Creating a
  file writes the requested content to the destination you selected.
- Launch at login is managed through macOS ServiceManagement; the switch can
  remove the registration. FileMint never enables Full Disk Access itself.
- Delete Permanently acts only after an explicit Finder action. It deletes selected
  items locally, bypassing Trash after the configured confirmation choice, and does
  not log their paths or contents. AirDrop is started only by an explicit Finder
  action and hands selected file URLs to macOS's system sharing service; recipient
  selection and any related system networking are governed by macOS and Apple.
- GitHub hosts source, releases, build attestations and issue reports. Opening a
  GitHub link in your browser is subject to GitHub's own privacy policy.
- Automatic update checks are enabled by default and can be disabled in General.
  While FileMint is running, they request public release metadata at most once
  every seven days; an overdue startup check waits at least one minute. Attempt
  times persist across launches, including failures. Manual checks remain
  available from About or the app/menu bar menu, even with the switch off. FileMint
  requests the public latest release from api.github.com. Choosing Update and
  Restart fetches that release’s update feed and signed installer from GitHub and its
  release asset CDN. These requests expose ordinary connection information,
  such as your IP address and a FileMint/Sparkle User-Agent (including app version), to
  GitHub. They do not include filenames, folder paths, templates, clipboard
  contents, an account token, device identifier or usage analytics. The current
  app version is compared locally. Disabling automatic checks stops scheduled
  and in-flight automatic requests. Downloads always require your action.
- Sparkle stages and verifies user-requested updates, replaces the installed app
  and relaunches it. It manages temporary update files and installation helpers.
  Administrator authorization may be requested by macOS. FileMint preserves
  preferences and folder bookmarks and defers restart while creation work is active.
  Sparkle's independent automatic checks/downloads and system profiling are
  disabled. The Finder extension stays offline and does not check for updates.
- Donation images are supplied by the project owner. Payment is optional and
  processed by the payment service you choose, not by FileMint.
