# FileMint 0.5.4 release verification

Verified on 2026-09-17. Release version **0.5.4**, build **12**.

## Source and local checks

- Source tag: `v0.5.4`.
- Source commit: `2d67ea75af7ee3690b8ded45dbde63f3f166c130`.
- The source checkout was clean when the candidate was packaged, submitted and
  published. The release manifest binds that commit to the final DMG checksum.
- `make verify`: **60 tests in 5 suites**, plus **5 JSON harness cases**, passed.
- `SITE_BASE=/FileMint/ pnpm run site:build` passed. Both homepages rendered all
  15 roadmap checkboxes; desktop Chinese and narrow-screen English layouts were
  inspected locally before publication.
- The app and Finder extension both report version 0.5.4, build 12, and contain
  arm64 and x86_64 executables. Nested Developer ID signatures, hardened runtime,
  secure timestamps, extension metadata and bundled license passed validation.

## Apple notarization

The exact locally signed candidate was submitted with `xcrun notarytool` using
the existing local `FileMint` Keychain profile. The same submission was awaited
with `notarytool wait`; no duplicate submission was made.

- Submission ID: `6f350d3b-f195-43a4-a1a7-d68d0fe1bfd1`.
- Apple result: **Accepted**.
- `xcrun stapler staple` and `xcrun stapler validate` passed before publication.
- `scripts/verify_release_artifact.sh` passed for the final DMG, including its
  checksum, ticket and the versions/signatures inside the mounted image.

The checksum was recalculated after stapling. The submitted candidate and final
stapled DMG therefore have different hashes, as expected; the final published
checksum below is the download integrity value.

## Published artifacts

[GitHub Release: FileMint 0.5.4](https://github.com/FileMintApp/FileMint/releases/tag/v0.5.4)

- `FileMint-0.5.4.dmg`: 4,249,758 bytes.
- `FileMint-0.5.4.dmg.sha256`: portable basename-only checksum file.
- Final DMG SHA-256:
  `de5b0ccc144c8b0e4a62408bb8c584409ca2028c02bfb075faf4413c55556397`.
- GitHub's asset digest matches the final DMG checksum.
- Both assets were downloaded after publication and compared byte-for-byte
  with their local originals; both comparisons passed.

Only the DMG and checksum were uploaded. Apple credentials, signing material and
the private local source manifest were not uploaded. The DMG was built locally;
GitHub verification does not claim GitHub build provenance.

## Remote checks and website

- [Core CI](https://github.com/FileMintApp/FileMint/actions/runs/35172572597): success.
- [Published DMG verification](https://github.com/FileMintApp/FileMint/actions/runs/35172588778): success.
- [Website deployment](https://github.com/FileMintApp/FileMint/actions/runs/35172572599): success.
- The public [Chinese homepage](https://filemintapp.github.io/FileMint/) and
  [English homepage](https://filemintapp.github.io/FileMint/en/) returned HTTP 200.
  Both responses include the roadmap anchor and all 15 TODO checkboxes.

## Runtime scope

This release did not replace the owner's installed app or repeat native Finder
interaction tests against the packaged 0.5.4 build. Intel execution, a clean-Mac
first install and real sleep/wake behavior were not tested during this release.
The existing native and controlled automatic-update evidence, with its limits,
is recorded in [ACCEPTANCE.md](ACCEPTANCE.md). Packaging, Apple acceptance and
download integrity checks are not a substitute for those runtime scenarios.
