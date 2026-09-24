# FileMint 0.6.0 release verification

Published on 2026-09-24. Version **0.6.0**, build **19**.

## Source and local package checks

- Tag `v0.6.0` points to release commit `80fe9ade30108a825b77c7728d88c4c4b5aa821f` on `main`.
- `make release-local` passed on macOS 27.2 / Apple silicon with Xcode 27.0. The run included `make verify`, Release packaging, nested-signature and embedded-entitlement checks, appcast signing, arm64-only checks, DMG verification and checksum generation.
- The generated project and final appcast both set the macOS 13.0 minimum. The appcast requires `arm64`; the app, Finder extension and Sparkle executables contain only arm64. The About UI reported **0.6.0 (19)**.
- Apple notarization submission `be9afbb5-c6ea-442c-858e-b59074ade9c0` was **Accepted**. Stapling and ticket validation passed before the final checksum.
- Final DMG size: **5,162,039 bytes**. SHA-256: `9e242275bc3b4e27aede260656e54975b8b949ac6b69eceb8e9cdc635d393f29`.

## Candidate and update acceptance

- A copy of the final DMG app launched from `/private/tmp`. Gatekeeper returned **accepted / Notarized Developer ID**, strict nested signature verification passed, and About showed **0.6.0 (19)**. The main executable was arm64.
- The temporary copy displayed Finder-extension setup guidance. It was not enabled in System Settings. PluginKit continued to load the existing `/Applications/FileMint.app` extension at **0.5.10**; no 0.6.0 Finder callback or refresh is claimed.
- The signed sandbox two-version Sparkle fixture discovered, downloaded and installed build 2, then relaunched it at the same fixture path. The old PID `16714` exited; PID `16748` launched build 2. The replacement passed strict code-signature verification. The fixture used an in-memory test key and a loopback feed.
- After publication, an isolated copy of the published 0.5.10 (18) DMG discovered 0.6.0 through the production About UI and public appcast (5.2 MB). Update and Restart replaced the copy at the same temporary path and relaunched FileMint. About showed **0.6.0 (19)**; Gatekeeper and strict signature verification passed afterward. The original `/Applications/FileMint.app` remained at **0.5.10 (18)**.
- The public-update copy used FileMint's production bundle ID, so it shared the app's existing preference container. No settings were toggled; a full field-by-field preference comparison was not made. PluginKit remained on the original 0.5.10 Finder extension.
- Installed Finder callbacks and extension refresh for 0.6.0, a clean-Mac installation, Intel execution, macOS 13 runtime and managed-device authorization remain unverified.

## Published assets and remote checks

[GitHub Release v0.6.0](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.0) is stable and contains exactly the following three assets. `make publish-local` downloaded each asset and compared it byte for byte with the verified local file.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| FileMint-0.6.0.dmg | 5,162,039 | `9e242275bc3b4e27aede260656e54975b8b949ac6b69eceb8e9cdc635d393f29` |
| FileMint-0.6.0.dmg.sha256 | 85 | `6af9e4a6136a79c96550a076fa84ed7646a02eb19cc67ccbb090e89bad463964` |
| appcast.xml | 852 | `e8292de3d23c40972c417d0e5c419a63f2091b4667c288cb5a08d13d924e9faa` |

- [Source CI](https://github.com/FileMintApp/FileMint/actions/runs/35948442974): passed on the release commit.
- [Published-DMG verification](https://github.com/FileMintApp/FileMint/actions/runs/35948451000): passed after upload.
- [Website deployment](https://github.com/FileMintApp/FileMint/actions/runs/35948443029): passed on the release commit. `SITE_BASE=/FileMint/ pnpm run site:build` passed, and the live [Chinese installation page](https://filemintapp.github.io/FileMint/install.html) and [English installation page](https://filemintapp.github.io/FileMint/en/install.html) both state that 0.6.0 cannot be installed or updated on Intel Macs.
