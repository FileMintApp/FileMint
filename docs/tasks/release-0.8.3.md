# FileMint 0.8.3 release

Status: replacement candidate source prepared
Next action: build and notarize the replacement candidate, then run the GitHub draft and distribution checks.

## Scope

- Publish 0.8.3 with build 32. The public DMG and ZIP appcasts for 0.8.2 both report build 31. Preflight found no v0.8.3 tag or draft.
- [Genie cadence](2026-11-20-file-drawer.md#genie-cadence-at-60-hz--2026-11-23) passed the signed 60 Hz fixture. The repair was committed and pushed separately as `797e3e4`.
- Lead both website homepages with File Drawer and show localized real captures of browsing, search and actions. A motion example may use a recorded GIF. Prepare release notes and website changes in the same tagged commit.
- Follow [Distribution](../DISTRIBUTION.md) for Apple notarization, artifact verification, GitHub draft validation, Pages deployment and official Homebrew synchronization.

## Verification

- Local working logs and the public predecessor feeds are in `build/release-runs.noindex/0.8.3-L9xyNu/`.
- Release metadata and context links passed for `c3c4070`. Its VitePress production-base build passed all 34 website tests. Chrome verified both homepages at desktop and 390 px wide, screenshot previews, keyboard scene navigation and both guide anchors.
- The corrected site keeps six real images captured from the isolated signed drawer with localized sample files. It removes the two Genie stills from the gallery and public images directory.
- The corrected production-base build passed all 34 website tests again before rebuilding the candidate. Both rendered homepages reference the browsing, search and action thumbnails, and the output contains no Genie stills or references to them. The log is `rebuilt/site-build.log` within the release run directory.
- The release keeps the arm64 and macOS 13.0 minimum. Actual macOS 13/14 runtime and installed-update behavior remain separate from the standard packaging and publication checks.

## Withdrawn candidate

- The initial tag pointed to `c3c4070a74f9da405c735362e6c0f3e8f73c1746` with build 32. The signed DMG and ZIP passed local artifact and feed checks. Apple accepted submission `d6876777-d0c9-418e-99db-d6ada1a207ff`.
- Publication paused during source CI run `45100494656`. GitHub Release `454921619` remained a draft with six assets. The 0.8.2 release remained public Latest and Pages served neither of the superseded screenshots.
- The owner authorized withdrawal of the unpublished draft and old remote tag on 2026-11-23. Both were removed and read back. The verified archives, feeds, manifest and journal were retained under `withdrawn-candidate/` in the release run directory. The original source commit remains in history.
