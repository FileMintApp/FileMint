# FileMint 0.6.3 release verification

Published on 2026-09-30. Version **0.6.3**, build **22**.

## Source and local package checks

- Tag `v0.6.3` points to release commit `5d4d0fa17a2cfac85231df816ee6bf3dc4b3f584` on `main`.
- The user selected the standard distribution workflow for this publication,
  superseding the unfinished exhaustive QA scope recorded in
  [the release task](https://github.com/FileMintApp/FileMint/blob/46882c07d1eee100cb6c200a89e72201c78a36c8/docs/tasks/release-0.6.3.md).
- `make release-local` passed on macOS 27.2 / arm64 with Xcode 27.0 (27A266a).
  It ran `make verify` (178 Core tests, 14 image tests, 5 public Harness cases,
  10 CLI regressions and release-script checks), built the app and Finder
  extension, and passed the production Sparkle driver checks.
- The app, Finder extension and embedded Sparkle executables were Developer ID
  signed and verified as arm64-only. Mounted-DMG checks passed nested signatures,
  resolved sandbox/installer entitlements, version/build, checksum and the signed
  `appcast.xml`. The feed declares macOS 13.0 and arm64.
- Apple notarization submission `b43741cf-3123-4c1c-b5ef-4a4c92889c0d` was
  **Accepted**, confirmed again with `notarytool info`. Stapling and ticket
  validation passed before the final checksum.
- Final DMG size: **5,941,847 bytes**. SHA-256:
  `3d118a00041c46743d60737e54822b2bf9b3e776cca8e573466cedb22eed70c7`.
- Packaging removed its temporary registrations. A subsequent PluginKit query
  listed only `/Applications/FileMint.app`'s 0.6.2 Finder extension.
- Local logs are retained under ignored `build/release-0.6.3/`:
  `verify.log`, `site-build.log`, `release-local.log`, `notary-info.json` and
  `publish-local.log`. The source manifest remains local at
  `build/FileMint-0.6.3.release.json`.

## Published assets and remote checks

[GitHub Release v0.6.3](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.3)
is stable and contains exactly the following three assets. `make publish-local`
downloaded each asset and compared its bytes with the verified local original.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `FileMint-0.6.3.dmg` | 5,941,847 | `3d118a00041c46743d60737e54822b2bf9b3e776cca8e573466cedb22eed70c7` |
| `FileMint-0.6.3.dmg.sha256` | 85 | `de929966a30c84ecd0d7e468d54bf089376810f8a6d921d52920ed12516b0d81` |
| `appcast.xml` | 852 | `9a5de04faaa4571f0f116f8f40a711097317c2747e9e8e7b71816a9c0b1a6de4` |

- [Published-release verification](https://github.com/FileMintApp/FileMint/actions/runs/36677421455),
  [CI](https://github.com/FileMintApp/FileMint/actions/runs/36677408803) and
  [website deployment](https://github.com/FileMintApp/FileMint/actions/runs/36677408736)
  all passed for the release commit.
- `SITE_BASE=/FileMint/ pnpm run site:build` passed before the tag. The bilingual
  guides describe custom symbols/colors, System Monochrome and background Copy
  Paths. Both deployed guide pages returned HTTP 200 and contained those changes;
  readback is recorded in `build/release-0.6.3/site-readback.log`. The final README
  version/link corrections and release evidence also passed context, diff and site
  checks. Historical screenshot version labels retain their original meaning.

## Runtime evidence boundary

Earlier observations for `1926822` plus release preparation and QA-script repairs
remain under `build/qa-0.6.3/`. They include isolated icon/settings/image panels,
sandbox move and app delivery, native creation/clipboard/Office templates, and a
production updater host with test metadata lowered to build 20 that actually
replaced and relaunched with public 0.6.2/build 21. These observations do not
establish an installed public-feed upgrade to the final 0.6.3 DMG.

This publication did not repeat temporary installation, UI review, old-to-new
update acceptance or the remaining exhaustive Finder checklist. Installed 0.6.3
Finder callbacks, highlighted menu colors, macOS 13 runtime, a clean Mac,
NAS/managed-device authorization and uninstalled terminal applications remain
unverified. The owner's installed application and preferences were not changed
in this publication turn.
