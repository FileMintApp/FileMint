# FileMint 0.5.10 release verification

Published on 2026-09-23. Version **0.5.10**, build **18**.

## Source and local checks

- Tag `v0.5.10` and release commit `664e3b79129e3924569467dc5d6116ff678332ac`.
- Built from a clean tagged `main` with `make release-local` on macOS 27.2 / Apple silicon.
- `make verify` passed on the tagged source: 139 Core tests, 13 image tests, five public harness cases, ten CLI tests, appcast/release-metadata/notarization/entitlement tests and context checks. The production Sparkle driver smoke passed. `SITE_BASE=/FileMint/ pnpm run site:build` passed.
- Release build and artifact checks passed for arm64 and x86_64, app and Finder extension version/build, nested Developer ID signatures, embedded sandbox and Sparkle service entitlements, DMG integrity, and the Ed25519-signed appcast.
- Apple notarization submission `4609309d-7faf-48c0-ad3c-141732670f4b` was **Accepted**. Stapling and validation passed before the final checksum. The final DMG SHA-256 is `8f734a03014eb13036891f1d2d502e850c9386600146a84594b43eaa5882695f`.

## Native candidate and update checks

- A copy from the final DMG passed Gatekeeper as `Notarized Developer ID`, strict nested code-signature verification and launch. About displayed **0.5.10 (18)**. With the isolated copy's Finder extension disabled, General and Finder & Folders displayed the new setup guidance and macOS settings path. The temporary app and extension registration were removed; `/Applications/FileMint.app` remained at 0.5.9 (17).
- The isolated Developer ID-signed Sparkle fixture used the production signing script, a fixture-only signing key and a loopback feed. In `/private/tmp`, build 1 PID 34541 downloaded, extracted, installed and relaunched build 2 PID 34583 at the same path. The old PID exited; the on-disk replacement passed strict signature and sandbox-entitlement checks.
- The first fixture run from the repository's `build/` directory showed an intermediate build 1 relaunch and no final automatic build 2 process, although the disk bundle eventually became build 2. The second run from `/private/tmp` passed. The first run is not counted as a successful relaunch.
- After publication, an isolated copy of the exact published 0.5.9 DMG discovered the public 0.5.10 feed in the production About UI, downloaded the release and updated in place. Old PID 35044 exited; new PID 35119 ran **0.5.10 (18)** at the same temporary path, and the replacement passed strict signature verification. The original `/Applications/FileMint.app` remained at 0.5.9 (17), running with its enabled Finder extension; the temporary extension registration was removed.
- `preferences.json` changed during the public-feed test, which records `lastUpdateCheckAttempt`. Its SHA-256 changed from `b7e1012ec2249f55207bfdac8f31a9f23225b9ec30c4abd44b0ddfa18f8a63f0` to `cb2108780ee4d296d857425999977226997a0c101737c9ef544d1cd4799a1f88`. A pre-run content snapshot was not taken, so other field-level equality is not asserted.

## Published assets and remote checks

[GitHub Release v0.5.10](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.10) is stable and contains exactly these three assets. `make publish-local` downloaded and compared each with the local verified file byte for byte.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| FileMint-0.5.10.dmg | 7,603,211 | `8f734a03014eb13036891f1d2d502e850c9386600146a84594b43eaa5882695f` |
| FileMint-0.5.10.dmg.sha256 | 86 | `1ae7c95a595fa06b252169db75f5be864f4db778842c174efc778abcc9e744bc` |
| appcast.xml | 784 | `b7038584cf2dd66cca808a89f7c04813059c1cfee89cb53fa4e1dc61dc21429f` |

- [Core CI](https://github.com/FileMintApp/FileMint/actions/runs/35812315267): passed on the release commit.
- [Published DMG verification](https://github.com/FileMintApp/FileMint/actions/runs/35812324022): passed on the release tag and commit.
- [Website deployment](https://github.com/FileMintApp/FileMint/actions/runs/35812315344): passed; the Chinese and English guide pages were read back from GitHub Pages.

The isolated test did not enable the candidate Finder extension in System Settings. Installed Finder menu refresh, Intel and macOS 13 runtime, managed-device authorization and a readonly-DMG update remain untested. The local source manifest and Apple/update credentials were not uploaded.

Local logs: `/private/tmp/filemint-0.5.10-release.log`, `/private/tmp/filemint-0.5.10-publish.log`, `/private/tmp/filemint-0.5.10-site.log` and `/private/tmp/filemint-0.5.10-sparkle-qa-build.log`.
