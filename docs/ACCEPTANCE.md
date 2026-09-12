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

## GitHub build provenance

[CI run 34701708737](https://github.com/FileMintApp/FileMint/actions/runs/34701708737)
passed both universal packaging and trusted-branch provenance verification for
commit `6075d1dcadde40315b295f2b5d901c2a9df90053`.

The downloaded GitHub DMG was independently checked locally:

- SHA-256 file verification passed.
- `gh attestation verify --repo FileMintApp/FileMint` passed, with a matching
  `https://slsa.dev/provenance/v1` subject.
- DMG SHA-256: `3995eb61b3af90d7a258c01f1ada81502a02c87a2a12e07d7906c05c58d8cb77`.
- Read-only mounted app: both architectures, matching versions and nested
  ad-hoc signatures passed verification.

This is GitHub source/build authentication, not Apple notarization.

## Remaining release gate

Final native regression after the storage/IPC change is not complete. A public
GitHub Release has not been published; complete that regression before tagging.
Intel execution and a clean-Mac first-install check are unavailable on this host;
universal compilation is not evidence of those runtime checks.
