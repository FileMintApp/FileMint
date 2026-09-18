# Startup, settings and preferences

Load for: App/window lifecycle, login items, menu bar visibility, language and persistent defaults.

Part of the [FileMint SPEC](../SPEC.md). This file owns the behavior below; other documents link here.

## Startup and menu bar

- FileMint starts as an accessory app. Explicitly opening settings (including
  About or an ordinary Applications/Spotlight launch) shows its Dock icon for
  that window's lifetime, including while minimized. Closing settings removes
  the Dock icon and keeps Finder integration available. Finder creation never
  opens settings or adds a Dock icon; the creation panel alone stays accessory.
- Launch at login and Show in menu bar default to enabled. Both have persistent
  switches in General. A saved off value must survive upgrades and relaunches.
- Use macOS 13+ SMAppService.mainApp for login registration. Request the default
  once after the app has been placed in /Applications or ~/Applications and
  launched. Do not register development builds or a mounted DMG as login items.
- Display actual service status: active, off, awaiting system approval, unavailable
  or failed. A stored preference alone is never proof of successful registration.
- Respect changes in macOS Login Items; do not silently re-register after the
  user disables/removes the item there. Offer an explicit retry/settings action.
- Hiding the menu bar item takes effect immediately and persists. Opening the app
  from Applications or Spotlight keeps settings reachable. Finder URL actions continue to work when the
  settings window is closed or the menu bar item is hidden.
- New preferences follow the system's supported language; explicit saved English
  or Chinese choices remain authoritative. Users can also select Follow System.

- Settings has one resizable sidebar window. Switching pages preserves the
  in-session page selection without saving navigation into user preferences.
  About/update commands select About in that same window; page navigation does
  not change the explicit-launch and Finder-creation window ownership rules.
- Optional tool modules have their own settings entry under Extensions. Their
  master switches default off on new installs and migration, preserve child
  choices and menu placement when disabled, and never alter existing creation
  preferences. File-tool placements default to submenu, except Move Selected Items
  Here which defaults to main. New deletion/AirDrop switches default off; deletion
  confirmation defaults to required, including absent or invalid saved values.

- An explicitly requested updater relaunch must wait until creation work and
  modal editing are finished. Preserve saved startup preferences and bookmarks.

## Working context

- Implementation entry points: `App/FileMint/FileMintApp.swift`, `AppDelegate.swift`, `SettingsWindowController.swift`, `LoginItemService.swift`, `PreferencesModel.swift`; `Preferences.swift`, `LoginItemPolicy.swift`, `Localization.swift`.
- Verification: [Core checks](../verification/core.md); [window isolation](../../docs/FINDER_QA.md#creation-window-isolation) and [settings](../../docs/FINDER_QA.md#types-and-preferences) for native changes.
- Expand context only when needed: Load the owning domain for each preference being changed: [templates](templates.md), [Finder/permissions](finder-permissions.md) or [updates](updates.md). Load [creation](creation.md) for URL launch and draft-window behavior.
