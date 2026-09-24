# FileMint 0.6.1 release verification

Published on 2026-09-24. Version **0.6.1**, build **20**.

## Source and local package checks

- Tag `v0.6.1` points to release commit `28d16a8d054a9ab096e76592035946c9902e362f` on `main`.
- `make release-local` passed on macOS 27.2 / Apple silicon with Xcode 27.0 (build 27A266a). It ran `make verify`, signed the app, Finder extension and Sparkle executables, checked entitlements and arm64-only slices, generated the signed appcast, and verified the final DMG.
- Apple notarization submission `b4415c2a-b767-47b1-98fc-1357e88c0eb7` was **Accepted**. Stapling and ticket validation passed before the final checksum.
- Final DMG size: **5,616,465 bytes**. SHA-256: `a851dae03c5dd3983ceca9ac9ce1ec01e3768782cba9f6e3d15fe7d39dda4dd0`.

## Candidate and update acceptance

- The final DMG app was copied to `/private/tmp/FileMint-0.6.1-acceptance/FileMint.app`. Gatekeeper reported **accepted / Notarized Developer ID**, strict nested signature verification passed, and About showed **0.6.1 (20)**. The app and Finder extension contain only arm64 code.
- The temporary candidate showed the Finder-extension setup guidance. I did not enable the extension or grant Accessibility permission; Finder callbacks, extension refresh and the hidden-item action are not claimed as tested.
- Six website screenshots were captured from the notarized 0.6.1 app in Chinese and English. The Finder settings images are cropped to omit the locally configured folder paths. The temporary English-language preference was restored to Follow System and verified. No user files were processed and no feature or permission switches were changed.
- A copy of the published 0.6.0 (19) DMG was launched from `/private/tmp/FileMint-0.6.1-public-update/FileMint.app`. Its production About check discovered 0.6.1 (20) from the public appcast, downloaded the 5.6 MB update, and replaced/relaunched the app at the same temporary path. About showed **0.6.1 (20)** afterward; Gatekeeper accepted it as Notarized Developer ID, strict nested signature verification passed, and the main executable was arm64.
- The isolated Sparkle app used FileMint's production bundle identifier and shared its preference container. No feature switches, folder authorization or system permissions were changed; no full field-by-field preference comparison was made. Both temporary app directories were removed after acceptance.

## Published assets and remote checks

[GitHub Release v0.6.1](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.1) is stable and contains exactly these three assets. `make publish-local` downloaded and compared each asset byte for byte with the verified local file.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `FileMint-0.6.1.dmg` | 5,616,465 | `a851dae03c5dd3983ceca9ac9ce1ec01e3768782cba9f6e3d15fe7d39dda4dd0` |
| `FileMint-0.6.1.dmg.sha256` | 85 | `ee59e0df203833f017b9991498d70c114df149d9244080a23d0bd0aec5cf6685` |
| `appcast.xml` | 852 | `2bb46b98d2cdd28c5c9c0743d4ffbbdaef057e161f1c617e7647f5001625ef18` |

- [Published-release verification](https://github.com/FileMintApp/FileMint/actions/runs/36009515660) passed after upload.
- The bilingual screenshot update is commit `91a322162b25291da8932fe83eb9e3e8a41a64f8`. `SITE_BASE=/FileMint/ pnpm run site:build` passed. [GitHub Pages deployment](https://github.com/FileMintApp/FileMint/actions/runs/36012213815) passed; the live Chinese and English home/guide pages and all six JPEG assets returned HTTP 200, and the deployed page HTML contains the 0.6.1 copy and new image paths.

Installed Finder callbacks and extension refresh, Accessibility permission, macOS 13 runtime, Intel execution and managed-device authorization remain unverified.
