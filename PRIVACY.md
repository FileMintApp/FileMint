# Privacy

FileMint creates files locally. It has no analytics, account system, cloud sync
or advertising. File creation does not require a network connection.

- File names, paths and contents are not uploaded or logged.
- The clipboard is read only when you invoke Paste or a standard paste shortcut.
  It is never watched or saved as a clipboard history.
- Preferences contain enabled file types, custom template content, language,
  login/menu bar choices, automatic-update preference and last check attempt time,
  folder paths and security-scoped bookmarks needed to remember folder access.
  They are stored privately in ~/Library/Application Support/FileMint. The
  Finder extension uses single-use request files there; requests expire after
  60 seconds and are removed when consumed.
- Draft filenames and pasted contents are not persisted by FileMint. Creating a
  file writes the requested content to the destination you selected.
- Launch at login is managed through macOS ServiceManagement; the switch can
  remove the registration. FileMint never enables Full Disk Access itself.
- GitHub hosts source, releases, build attestations and issue reports. Opening a
  GitHub link in your browser is subject to GitHub's own privacy policy.
- Automatic update checks are enabled by default and can be disabled in General.
  While FileMint is running, they request public release metadata at most once
  every seven days; an overdue startup check waits at least one minute. Attempt
  times persist across launches, including failures. Manual checks remain
  available from About or the app/menu bar menu, even with the switch off. FileMint
  requests the public latest release from api.github.com. Choosing Download
  Update fetches the installer and its SHA-256 checksum from GitHub and its
  release asset CDN. These requests expose ordinary connection information,
  such as your IP address and a generic FileMint update-checker User-Agent, to
  GitHub. They do not include filenames, folder paths, templates, clipboard
  contents, an account token, device identifier or usage analytics. The current
  app version is compared locally. Disabling automatic checks stops scheduled
  and in-flight automatic requests. Downloads always require your action.
- Installers are kept in FileMint's private cache. Cancelled or failed downloads
  are removed; the next download clears previous update cache files. A verified
  installer is marked as downloaded from the internet and opened in macOS.
  FileMint does not replace the installed app or quit automatically. The Finder
  extension has no network entitlement and does not check for updates.
- Donation images are supplied by the project owner. Payment is optional and
  processed by the payment service you choose, not by FileMint.
