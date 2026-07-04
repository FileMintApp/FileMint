# Finder QA

Headless tests prove the deterministic core. Finder integration still needs a manual pass before a public release.

## Local Build

```sh
make doctor
make project
make build
```

Install `build/DerivedData/Build/Products/Release/FileMint.app` into `/Applications`.

## Checklist

- Open FileMint and confirm the settings window launches.
- Enable the Finder Sync extension in macOS Extension settings.
- Confirm Desktop, Documents, and Downloads are listed as monitored locations.
- Open Desktop in Finder.
- Right-click the folder background and confirm `New File` appears.
- Create a text file and confirm `Untitled.txt` appears.
- Repeat and confirm `Untitled 2.txt` appears.
- Create Markdown, JSON, Swift, HTML, CSS, and Shell Script files.
- Disable a template in FileMint and confirm it disappears from the Finder menu.
- Toggle reveal-after-creation and confirm Finder selection behavior changes.
- Remove a monitored folder and confirm the menu no longer appears there after Finder reload.

## Troubleshooting

- Relaunch Finder with `killall Finder` after changing extension settings.
- Confirm the app and extension share the same App Group entitlement.
- Confirm the current folder is inside one of the monitored locations.
- Rebuild the Xcode project after changing `project.yml`.
