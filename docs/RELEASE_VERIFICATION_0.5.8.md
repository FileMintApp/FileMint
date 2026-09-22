# FileMint 0.5.8 release verification

Published on 2026-09-22. Release version **0.5.8**, build **16**.

## Follow-up: automatic installation failure

A user-reported 0.5.7 → 0.5.8 installation failure on 2026-09-22 exposed a
manual-signing defect: both versions embed unexpanded build-variable strings
instead of the actual Sparkle installer Mach service names. Sandbox logs confirm
the installed 0.5.7 is denied those lookups. The signature, notarization and
startup results below remain valid, but did not establish working in-app updates.
The old installed permissions cannot be repaired by an appcast; a corrected
installer requires one manual replacement. Existing published bytes are preserved.
See [the diagnosis and fix](tasks/sparkle-entitlements-fix.md).

## Source and checks

- Source tag: `v0.5.8`.
- Source commit: `eb487e3250dc1a7d631332cfe4500ae769b96269`.
- The candidate was built from clean `main`; the release manifest binds this
  commit, the signing certificate, final DMG and appcast hashes.
- `make verify` passed: 139 Core tests, 13 image tests, 5 public Harness cases,
  10 CLI regressions, 3 appcast tests and context checks.
- `SITE_BASE=/FileMint/ pnpm run site:build` passed.
- Universal arm64/x86_64 main app and Finder extension built with matching
  version 0.5.8/build 16. Nested Developer ID signatures, hardened runtime,
  DMG integrity and Ed25519 update signature checks passed.

## Apple notarization and runtime

- The user explicitly authorized uploading the prepared DMG to Apple using the
  existing local FileMint Keychain profile and continuing publication after acceptance.
- Submission ID: `537c15c3-c7c3-449f-ab32-702932dff1b7`.
- Apple status: **Accepted**. The same DMG was stapled and validated; its checksum
  and appcast signature were generated after stapling.
- `verify_release_artifact.sh` passed for the mounted app, Finder extension,
  Sparkle framework, Installer/Downloader XPC services, Autoupdate and Updater.app.
- A temporary copy taken from the final DMG passed Gatekeeper with
  `source=Notarized Developer ID`. It launched on macOS 27.2 (26B5086k), Apple
  silicon. General displayed Follow System and About displayed **0.5.8 (16)**.
- Owner preferences matched their pre-launch SHA-256 after the runtime check.
  The temporary app was closed and its own registrations/copy removed.
- Earlier production-view fixtures covered the new creation/template workflows
  and settings; see [acceptance](ACCEPTANCE.md) and [settings evidence](tasks/settings-appearance.md).
- Installed Finder callbacks, a full updater replacement/relaunch, clean-Mac
  permissions, Intel execution and macOS 13 runtime were not exercised by this
  release check. Universal compilation is not runtime evidence for those systems.

## Published assets

[GitHub Release: FileMint 0.5.8](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.8)

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| FileMint-0.5.8.dmg | 7,587,657 | `7237193d9bc899ddc45c35c93952034dc57ac7e49a9d37bd0d19aa9af4212b7a` |
| FileMint-0.5.8.dmg.sha256 | 85 | `cc1a3512fa0eeee0c201832e0454674b5d1cb44c1d292b6b1147178e14012f37` |
| appcast.xml | 779 | `d163bdfc756dedb84a20bd620c74e23fbf5f94739a2f31905c5ae14c916c4426` |

`make publish-local` downloaded all three published assets and compared them
byte-for-byte with the local files. GitHub's asset digests also match. The public
release is stable, and its body was read back against the prepared 0.5.8 notes.

Only these three assets were uploaded. Credentials, private signing keys and
the local manifest remain local; this is not a GitHub Actions-built DMG.

## Remote checks

- [Core CI](https://github.com/FileMintApp/FileMint/actions/runs/35709321295): passed.
- [Published DMG verification](https://github.com/FileMintApp/FileMint/actions/runs/35710059070): passed.
- [Website deployment](https://github.com/FileMintApp/FileMint/actions/runs/35709321266): passed.

All three runs refer to the exact release source commit above. Local logs:
`/tmp/filemint-0.5.8-verify.log`, `/tmp/filemint-0.5.8-package.log`,
`/tmp/filemint-0.5.8-artifact.log`, `/tmp/filemint-0.5.8-publish.log`.
