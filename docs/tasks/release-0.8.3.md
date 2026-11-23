# FileMint 0.8.3 release

Status: complete
Next action: installed-update and older macOS runtime acceptance remain separate.

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

## Replacement release evidence

The published `v0.8.3` tag points to `3894a41030b96fa9fb0fa921b9a86e5ef1a3f947` with build 32. The release ran on arm64 macOS 27.2.1 with Xcode 27.2. Logs and public readback are in `rebuilt/` within the release run directory.

| Check | Status | Evidence |
| --- | --- | --- |
| Local build and artifact checks | passed | `make release-local` passed 467 Swift tests, the offline Harness, production Sparkle driver checks and the Release build. Both archives contain the same arm64 signed app and passed embedded entitlement, checksum and signed update feed checks. |
| Apple notarization and tickets | passed | Submission `47c1b546-2a7c-4d5e-b07c-f709508c205e` returned Accepted. The DMG and the app inside the ZIP had validated stapled tickets. [Manifest](../../build/FileMint-0.8.3.release.json). |
| Exact source CI | passed | [Run 45102083287](https://github.com/FileMintApp/FileMint/actions/runs/45102083287), attempt 1, passed on arm64 macOS 15 and 26. |
| Draft candidate validation | passed | [Run 45102832977](https://github.com/FileMintApp/FileMint/actions/runs/45102832977), attempt 1, verified the six recorded draft assets before promotion. |
| Stable release and update discovery | passed | [FileMint 0.8.3](https://github.com/FileMintApp/FileMint/releases/tag/v0.8.3), Release `454930563`, became public Latest at **2026-11-23 10:55:50 Asia/Shanghai**. The public readback matched the six verified asset IDs, and the tag resolved to the replacement commit. |
| Website | passed | [Build 45102883691](https://github.com/FileMintApp/FileMint/actions/runs/45102883691), attempt 1, produced Pages artifact `14785944131`. [Deployment 45102993977](https://github.com/FileMintApp/FileMint/actions/runs/45102993977), attempt 1, deployed it. Live checks confirmed the three screenshots per language and HTTP 404 for both withdrawn stills. |
| Official Homebrew tap | passed | Tap commit `e4e15f568d618700e9cea568163fae425e4d0f60` passed [exact CI run 45103180359](https://github.com/FileMintApp/homebrew-tap/actions/runs/45103180359), attempt 1, after Cask readback. |
| Publication journal | passed | [Journal](../../build/FileMint-0.8.3.publication.json) records `phase: complete`, `distribution_complete: true` and Homebrew `succeeded`. |

### Published archives

- `FileMint-0.8.3.dmg` is 11,928,092 bytes. SHA-256 `8cd0be550f0b87a73a5408a9220829e6947cf2a657fc81448506080aef8c2757`.
- `FileMint-0.8.3.zip` is 10,913,667 bytes. SHA-256 `3f40f6ec1efafaeed5596482adbd0f99554f6e23f7fc1f9cd0bb21d4aff6e9ec`.
- Public asset IDs are `781268631` (DMG), `781268628` (DMG checksum), `781268627` (ZIP), `781268638` (ZIP checksum), `781268632` (DMG feed) and `781268658` (ZIP feed).
