# FileMint 0.5.5 release verification

Verified on 2026-09-18. Release version **0.5.5**, build **13**.

## Source and local checks

- Source tag: v0.5.5.
- Source commit: 846f128ec8da4a47f0e2cd01ddd5c886f0da6a1d.
- The remote annotated tag peels to the same commit, and main was clean before the release candidate was built.
- The release-local process reran make verify successfully: 97 Swift tests in 9 suites, 5 JSON harness cases, 10 CLI regressions and 3 appcast tests.
- SITE_BASE=/FileMint/ pnpm run site:build rendered the Chinese and English website with the FileMint base path.
- The unsigned candidate build and the signed release package both contain universal arm64 and x86_64 main-app and Finder-extension binaries. Both report version 0.5.5, build 13.
- make verify-sparkle-driver passed the production update driver’s selector, cancellation, progress, draft deferral, relaunch choice, retry and error paths.

## Apple notarization

The exact signed DMG was submitted with xcrun notarytool using the existing local FileMint Keychain profile. The release process waited for this submission; it did not publish a pending candidate.

- Submission ID: 12215c00-123f-4332-b449-1c3bb7c1f31e.
- Apple result: **Accepted**.
- xcrun stapler staple and xcrun stapler validate both passed.
- The final mounted-image verification passed for the DMG, Finder extension, main app, embedded Sparkle framework and its installer helpers.

The checksum was calculated after the ticket was stapled, so it identifies the final downloadable bytes.

## Published artifacts

[GitHub Release: FileMint 0.5.5](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.5)

- FileMint-0.5.5.dmg: 5,861,325 bytes.
- Final DMG SHA-256: 50902f54f949aaee87c4094a1c48589b7e4cde1c0848a0ca773634a04ed82ebd.
- FileMint-0.5.5.dmg.sha256: 85 bytes.
- appcast.xml: 779 bytes; SHA-256 0b24fb1bb713c5ce4caf438ed57741c3684e7899526e4f7bfc11bf71efb45e39.
- GitHub’s published DMG digest matches the final local DMG checksum.
- publish-local downloaded the DMG, checksum and appcast after publication and compared all three byte-for-byte with the local notarized artifacts.

Only the DMG, checksum and appcast were uploaded. Apple credentials, signing material and the private release manifest remain local. The DMG was built locally and does not claim GitHub Actions build provenance.

## Remote checks and documentation

- [CI](https://github.com/FileMintApp/FileMint/actions/runs/35302722123): success.
- [Website deployment](https://github.com/FileMintApp/FileMint/actions/runs/35302722198): success.
- [Published-release verification](https://github.com/FileMintApp/FileMint/actions/runs/35302740705): success.
- The public [Chinese homepage](https://filemintapp.github.io/FileMint/) and [English homepage](https://filemintapp.github.io/FileMint/en/) both returned HTTP 200 after deployment.
- The published release notes, README, website, installation guide, privacy policy and roadmap describe the settings sidebar, File & Folder Tools and in-app update installation.

## Runtime scope

The signed package was mounted and inspected, but this release did not replace the owner’s installed application or complete a real signed old-to-new Sparkle replacement. It also did not repeat every Finder interaction against the signed 0.5.5 install, including a physical two-step move, cross-volume move, clean-Mac first install or Intel execution. Existing Debug/native observations remain in [ACCEPTANCE.md](ACCEPTANCE.md); they are not substituted for those unrun signed-release scenarios.
