# FileMint 0.8.3 release

Status: candidate source prepared
Next action: build and notarize the tagged candidate, then validate the GitHub draft and finish distribution.

## Scope

- Publish 0.8.3 with build 32. The public DMG and ZIP appcasts for 0.8.2 both report build 31. Preflight found no v0.8.3 tag or draft.
- [Genie cadence](2026-11-20-file-drawer.md#genie-cadence-at-60-hz--2026-11-23) passed the signed 60 Hz fixture. The repair was committed and pushed separately as `797e3e4`.
- Lead both website homepages with File Drawer and show localized real captures of browsing, search, actions and the Genie transition. Prepare release notes and website changes in the same tagged commit.
- Follow [Distribution](../DISTRIBUTION.md) for Apple notarization, artifact verification, GitHub draft validation, Pages deployment and official Homebrew synchronization.

## Verification

- Local working logs and the public predecessor feeds are in `build/release-runs.noindex/0.8.3-L9xyNu/`.
- Release metadata and context links passed. The VitePress production-base build passed all 34 website tests. Chrome verified both homepages at desktop and 390 px wide, screenshot previews, keyboard scene navigation and both guide anchors.
- The eight website images were captured from the isolated signed drawer on the same application source with localized sample files. No owner folders, file names or settings are shown.
- The release keeps the arm64 and macOS 13.0 minimum. Actual macOS 13/14 runtime and installed-update behavior remain separate from the standard packaging and publication checks.
