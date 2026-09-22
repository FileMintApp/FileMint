# FileMint 0.5.9 release verification

Published on 2026-09-22. Version **0.5.9**, build **17**.

## Source and checks

- Tag `v0.5.9`; commit `6f9c3061f671e86026cb721a539393aa9a802194`.
- Built from clean tagged main with `APP_VERSION=0.5.9 BUILD_NUMBER=17 make release-local`.
- `make verify` passed: 139 Core tests, 13 image tests, 5 public cases, 10 CLI
  regressions, 3 appcast tests, 5 entitlement-preparation tests and context checks.
- Website build with `SITE_BASE=/FileMint/` passed.
- Universal arm64/x86_64 app/extension, matching version/build, nested signatures,
  hardened runtime and DMG integrity passed. Embedded signed entitlements contain
  the exact `io.github.daigua.filemint-spks` / `io.github.daigua.filemint-spki`
  service names with no unresolved variables. Both targets retain sandboxing;
  Finder gains no networking or installer privileges.

## Apple notarization and native evidence

- User explicitly authorized Apple submission with existing local credentials
  and publication of 0.5.9 after acceptance.
- Apple submission `74bfb972-9039-4c96-9302-dcc922d7faa1`: **Accepted**.
- Stapling and validation passed. Final checksum and signed appcast were generated
  after stapling. Mounted app, extension and Sparkle/helper verification passed.
- A copy from the final DMG passed Gatekeeper (`Notarized Developer ID`) and
  launched on macOS 27.2/Apple silicon; About showed **0.5.9 (17)**.
- The copy was quit and removed with its own registrations. Installed 0.5.7
  remained running, and owner preferences matched the pre-check SHA-256.
- The [fix task](tasks/sparkle-entitlements-fix.md) records a real isolated,
  Developer ID-signed sandbox update through download, extraction, replacement
  and relaunch: PID 60859/build 1 → PID 60910/build 2 at the same installation
  path, with post-install signatures/permissions verified. Production custom-driver
  callback, cancellation and restart-protection smoke passed separately.
- The upgrade fixture uses a minimal driver, loopback feed and inert extension.
  This does not establish production public-feed/custom-driver end-to-end,
  installed Finder refresh, Intel execution or macOS 13 runtime evidence.

## Published assets

[FileMint 0.5.9](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.9)
is the latest stable release. Its body matches the prepared bilingual fix notes
and states that affected old builds require one manual installation.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| FileMint-0.5.9.dmg | 7,587,555 | `5562c6f2fe09d402ef0011947d3b57dd2149e57d58aa6b34197560d1333a9ba3` |
| FileMint-0.5.9.dmg.sha256 | 85 | `6864a43c7f054acc8b7855f15fb341547741cda02155473e2e7cfd5877987683` |
| appcast.xml | 779 | `08e73393f751b4b70c29b393821ca539ed5e21d6c7d8eddcfb1f46320a6edbdd` |

`make publish-local` downloaded and byte-compared all three assets; GitHub sizes
and digests match. Credentials and the local source manifest stayed local.
Previously published version bytes were preserved.

## Remote checks

- [Core CI](https://github.com/FileMintApp/FileMint/actions/runs/35715542724): passed.
- [Published DMG verification](https://github.com/FileMintApp/FileMint/actions/runs/35715557664): passed, including embedded entitlements.
- [Website deployment](https://github.com/FileMintApp/FileMint/actions/runs/35715542598): passed.

All runs refer to the source commit above. Logs: `/tmp/filemint-0.5.9-release.log`,
`/tmp/filemint-0.5.9-publish.log`, `/tmp/filemint-0.5.9-site.log`.
