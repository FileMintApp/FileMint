# Privacy

FileMint creates files and optional Finder file/folder actions locally. It has no
analytics, account system, cloud sync or advertising. File creation and local file
tools do not require a network connection; AirDrop is performed by macOS's system
sharing service only when you explicitly choose it.

- File names, paths and contents are not uploaded or logged.
- The clipboard is read only when you invoke Paste or a standard paste shortcut.
  Copy Names and Copy Paths write to it only after you explicitly choose either
  Finder menu action. It is never watched or saved as a clipboard history.
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
