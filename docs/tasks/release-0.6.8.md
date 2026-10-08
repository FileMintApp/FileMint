# FileMint 0.6.8 release

Status: complete
Next action: None for this release. Future installation/runtime QA is a separate request.

## Scope and source

- The user authorized the complete standard release with “构建发布” on
  2026-10-08. Use the primary `main` checkout and the existing local signing keys.
- Version 0.6.8, build 27 follows published 0.6.7, build 26. Never replace an
  existing release or move an existing tag.
- Fix commit: `acfa69e` (`fix(creation): honor configured and default applications`).
- Release source/tag: `8b1a08dc20822675b0b0b6dc1384c79f9f6ce81a` / `v0.6.8`.
- [FileMint 0.6.8](https://github.com/FileMintApp/FileMint/releases/tag/v0.6.8)
  was published at 2026-10-08 08:18:44 UTC (16:18:44 Asia/Shanghai).
- Shipped changes: [release notes](../RELEASE_NOTES.md). Feature evidence:
  [creation/opening chain](2026-10-08-creation-opening.md).

## Selected context

- [Distribution contract](../../specs/domains/distribution.md),
  [standard release procedure](../DISTRIBUTION.md),
  [presentation](../../specs/domains/presentation.md),
  [HARNESS](../../specs/HARNESS.md).
- `make release-local` and `make publish-local` are the required candidate/public
  stages. Keep source, signatures, notarization, stapling, appcast and remote
  byte verification gates intact.

## Evidence

Environment: owner's macOS 27.2 arm64 / Xcode 27.0.

| Check | Status | Evidence |
| --- | --- | --- |
| Latest stable release/appcast and remote main | passed | v0.6.7/build 26; remote main `e0ba136f1cff0f14fb392e55b9a1f37a113330c8`. |
| Applicable opening feature checks | passed | Feature task records standard tests, unsigned build, fresh native route regression and actual VS Code/WPS/TextEdit observations before release preparation. |
| Bilingual README/website includes | passed | `SITE_BASE=/FileMint/ pnpm run site:build`; [log](../../build/release-0.6.8.noindex/site-build.log). |
| Tagged-source candidate checks | passed | `make release-local` reran 220 Core tests, 14 image tests, 5 public cases, 10 CLI regressions and offline release checks at the tagged commit. [Local log](../../build/release-0.6.8.noindex/release-local.log). |
| Developer ID signatures, entitlements and arm64-only bundles | passed | App, Finder extension, Sparkle framework/helpers, resolved installer service names, accessory-launch metadata and production Sparkle driver verified. |
| Apple notarization, stapling, checksum and signed appcast | passed | Submission `b95d6319-80a8-42fb-907c-3ed34854986c` accepted; ticket stapled/validated; mounted bundle and Ed25519 signature verified. [Manifest](../../build/release-0.6.8.noindex/candidate-manifest.json). |
| Published DMG/checksum/appcast byte readback | passed | Stable release contains exactly the three expected assets. Downloaded bytes matched local files with `cmp`. [Publication log](../../build/release-0.6.8.noindex/publish-local.log). |
| Published-release GitHub verification | passed | [Run 37748999896](https://github.com/FileMintApp/FileMint/actions/runs/37748999896), source SHA matches the tag. |
| Release-source CI | passed | [Run 37748981925](https://github.com/FileMintApp/FileMint/actions/runs/37748981925). |
| Website deployment | passed | [Run 37748981928](https://github.com/FileMintApp/FileMint/actions/runs/37748981928). |

## Final artifacts

- DMG: `FileMint-0.6.8.dmg`, 6,715,684 bytes.
- DMG SHA-256:
  `e48996ade2f4322ecf452efb5493f40721d3411fe5023c2e0113080883d0631c`.
- Appcast SHA-256:
  `7ffd03e12801e4f84d51f66d352b8f222eb6eb1e80fe04baf8fd307ed7dbe2aa`.
- Public assets:
  [DMG](https://github.com/FileMintApp/FileMint/releases/download/v0.6.8/FileMint-0.6.8.dmg),
  [checksum](https://github.com/FileMintApp/FileMint/releases/download/v0.6.8/FileMint-0.6.8.dmg.sha256),
  [appcast](https://github.com/FileMintApp/FileMint/releases/download/v0.6.8/appcast.xml).
- `make publish-local` pushed `main` and the immutable tag after candidate
  verification. The evidence-only follow-up commit is not the release source.

## Runtime boundaries

- This follows the repository standard release workflow. Installed Finder,
  macOS 13, managed-device behavior and an old-to-new installed update are not
  inferred from automated/native-fixture results.
- The changed opening path has bounded actual editor observations; this does
  not claim every third-party application's format compatibility.
- No installed FileMint is replaced as part of this release workflow.

## Handoff

- All standard release work completed. Keep final local artifacts and logs for
  reference; never replace the published bytes or retarget `v0.6.8`.
