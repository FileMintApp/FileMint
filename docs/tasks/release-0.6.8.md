# FileMint 0.6.8 release

Status: in-progress
Next action: Build and verify the signed/notarized candidate, then publish and read back all remote assets.

## Scope and source

- The user authorized the complete standard release with “构建发布” on
  2026-10-08. Use the primary `main` checkout and the existing local signing keys.
- Version 0.6.8, build 27 follows published 0.6.7, build 26. Never replace an
  existing release or move an existing tag.
- Fix commit: `acfa69e` (`fix(creation): honor configured and default applications`).
- The release commit/tag are bound by the candidate's source manifest. Record
  their exact values after the canonical pipeline completes.
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
| Tagged-source candidate checks | not-run | Pending `make release-local`. |
| Developer ID signatures, entitlements and arm64-only bundles | not-run | Pending candidate. |
| Apple notarization, stapling, checksum and signed appcast | not-run | Pending candidate. |
| Published DMG/checksum/appcast byte readback | not-run | Pending `make publish-local`. |
| Published-release GitHub verification | not-run | Pending publication. |

## Runtime boundaries

- This follows the repository standard release workflow. Installed Finder,
  macOS 13, managed-device behavior and an old-to-new installed update are not
  inferred from automated/native-fixture results.
- The changed opening path has bounded actual editor observations; this does
  not claim every third-party application's format compatibility.
- No installed FileMint is replaced as part of this release workflow.

## Handoff

- If notarization is pending, retain the exact stage, source identity and Apple
  submission ID and resume them. If remote publication fails, retain the final
  candidate and rerun publication without replacing assets.
