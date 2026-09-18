# FileMint 0.5.6 release verification

Published on 2026-09-18. Release version **0.5.6**, build **14**.

## Source and local checks

- Source tag: `v0.5.6`.
- Source commit: `c5b3359e7a44ac0d19ab99be706f8068d73484e8`.
- The remote annotated tag peels to the same commit. The release process required
  a clean `main` checkout before it built the candidate.
- `make verify` passed: 104 Swift tests in 10 suites, 5 JSON harness cases, 10
  CLI regressions and 3 appcast tests.
- The release process built universal arm64 and x86_64 main-app and Finder-extension
  binaries, all reporting version 0.5.6, build 14.
- The release process generated and verified the Ed25519-signed `appcast.xml`.

## Apple notarization

- The exact signed DMG was submitted with the existing local `FileMint` Keychain
  profile and waited for review before publication.
- Submission ID: `89e1ab05-24a3-4472-9099-f6a88d058eb3`.
- Apple result: **Accepted**.
- `xcrun stapler staple` and `xcrun stapler validate` both passed.
- Mounted-image verification passed for the DMG, Finder extension, main app,
  embedded Sparkle framework and its installer helpers.

## Published assets

[GitHub Release: FileMint 0.5.6](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.6)

- FileMint-0.5.6.dmg: 6,001,041 bytes.
- Final DMG SHA-256: `38cc793e54525db2ef375298aa69b77f6efac7cab2ade2efbfc32232d80a05a8`.
- FileMint-0.5.6.dmg.sha256: 85 bytes.
- appcast.xml: 779 bytes; SHA-256
  `82e9c717014dfc72f3e2c429b680cfbdaa83997f5fc0204274a437721286ef5f`.
- The project publish script downloaded all three GitHub assets and compared them
  byte-for-byte with the final local notarized files.

Only the DMG, checksum and appcast were uploaded. Apple credentials, signing
material and the local release manifest remain local. The DMG was built locally
and does not claim GitHub Actions build provenance.
