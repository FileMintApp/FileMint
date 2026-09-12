# FileMint 0.2 acceptance

Host: macOS 26.6.2, Apple silicon. Build: universal arm64 + x86_64, macOS 13 minimum.

## Automated and package checks

- 28 Swift Testing cases pass, including 40 simultaneous creations with distinct
  payloads, exact `demo.js` naming, literal UTF-8, symlinks, collision handling,
  custom types, preference storage, expiring single-use tickets and captured
  Finder destinations.
- All 5 public JSON harness cases pass.
- Release builds for both architectures. Nested app/extension code signatures
  validate; version metadata agrees. No Swift compiler warnings; Xcode emits
  its standard unused AppIntents metadata extraction notice.
- The local DMG passes `hdiutil verify`; checksum uses a portable basename.

## Native observations during development

- The compact native settings and creation panel were inspected in dark mode.
- The actual UI created `demo.js`. Its bytes matched the pasted Chinese, emoji,
  multiline JavaScript and literal `{{year}}` text exactly.
- Command-Return created and revealed the file in Finder.
- Finder displayed the text-only submenu with extension labels.
- Runtime testing found and fixed XPC-thread UI assertions and unsupported
  `representedObject` menu routing. Menu tags now map to bounded value snapshots.
- Runtime testing also exposed the ad-hoc build's App Group access blocking.
  The final build uses an application-owned support directory, a narrow sandbox
  path exception and main-app-owned creation instead. It does not access the
  old protected container.

## Remaining release gate

Final native regression after the storage/IPC change is awaiting the owner's
at-action approval to launch the locally built, non-notarized app. Automatic
computer-use approval rejected that launch; it has not been bypassed.

GitHub CI passed for the implementation commit (be5fe48). The subsequent folded-F
icon refresh updates branding assets. CI now packages a DMG and verifies GitHub
provenance for trusted main-branch builds in a separate job. GitHub Release
publication and final downloaded-asset verification have not yet run.
Intel execution and a clean-Mac first-install check are unavailable on this host;
universal compilation is not evidence of those runtime checks.
