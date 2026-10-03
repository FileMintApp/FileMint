# FileMint 0.6.5 release verification

Published on 2026-10-03. Version **0.6.5**, build **24**.

- Release source: `v0.6.5` at `c55fa7e6b1d2c7045f07b04ca17b53589f89e83a`.
- `make release-local` passed: 191 Core and 14 image tests, public Harness/CLI,
  production Sparkle-driver checks, Developer ID signing, arm64-only bundles,
  entitlements, accepted notarization, stapling, mounted-DMG and appcast checks.
- Apple submission `89507ebe-0a25-44dc-843f-ca0b94a98438` was **Accepted**, including
  a separate status readback using the existing FileMint Keychain profile.
- Final DMG: 6,077,836 bytes, SHA-256
  `0fd5be2435b951f8520c63e2075f36b031fb27c5eaba2bd66ee26d38520ce56d`.
  Appcast SHA-256:
  `7b71e23911faf16963110461974bd8e86b5fcf43fbcd17ead3e406f1db31c530`.
- Both main app and Finder extension contain the exact blank DOCX/XLSX resources.
- [Stable release](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.5)
  has exactly DMG, SHA-256 and appcast assets. `make publish-local` downloaded and
  compared all three byte for byte.
- [Published-release verification](https://github.com/FileMintApp/FileMint/actions/runs/37100776418)
  and [website deployment](https://github.com/FileMintApp/FileMint/actions/runs/37100768396) passed.
- [Source CI](https://github.com/FileMintApp/FileMint/actions/runs/37100768405)
  failed two Office resource tests: the native SwiftPM engine places resources
  beside `.xctest`, unlike the local Swift Build layout. The failure was reproduced
  locally and is tracked in the [release task](tasks/release-0.6.5.md).
  This is not recorded as a green CI result. Keep published bytes and tag intact;
  the compatibility correction is prepared as 0.6.6/build 25.
- Local evidence remains under `build/release-0.6.5/`. The installed FileMint was
  not replaced; installed Finder, Microsoft Office and minimum-macOS runtime
  checks remain outside the observed evidence.
