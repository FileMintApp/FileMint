# FileMint 0.8.2 release

Status: complete
Next action: None for standard publication. Older macOS, installed updates and full launcher acceptance remain separate.

## Objective and scope

- Publish the owner's selected 0.8.2/build 31 from the primary `main` checkout.
  Verify the Swift 6.1 compilation repair before building the release.
- Verify the signed, notarized DMG and ZIP, both checksums and Sparkle feeds.
  Complete exact source CI, draft validation, website deployment and official
  Homebrew tap CI before recording completion.
- Document the shipped launcher entry points as the initial integration.
  The full launcher experience and promotional acceptance remain separate.

## Selected context

- [Distribution](../DISTRIBUTION.md) and [Harness](../../specs/HARNESS.md).
- [Hidden-file display](2026-11-10-finder-hidden-files-toggle.md),
  [folder authorization](2026-11-09-file-access-authorization.md), and
  [launcher checks](2026-10-29-shortcuts-and-launchers.md).

## Preparation

- GitHub Latest was `v0.8.1`, Sparkle build 30; `v0.8.2` had no existing
  local or remote tag or Release at preflight.
- [macOS 15 CI](https://github.com/FileMintApp/FileMint/actions/runs/42744566416/job/129593472937)
  failed to compile the async File Info read callback under Swift 6.1.2.
  Commit `aa167ad` explicitly isolates the callback to the main actor while
  keeping the file read on its existing detached worker. Local `make verify`
  and the unsigned main app and Finder extension build passed.
- Both runner builds passed in the
  [CI repair run](https://github.com/FileMintApp/FileMint/actions/runs/42745717477).
  Release metadata, context links and the local Pages build passed (27 site tests).
- The app and installer retain their macOS 13.0 minimum. Only Shortcuts
  and Launchers require macOS 13.3. Existing public assets stay unchanged.

## Evidence

Release source/tag: `e2884d8a64ccf39211412a19b1fd732d26bbd06c` / `v0.8.2`, build 31.
Environment: arm64 macOS 27.2.1, Xcode 27.2, Swift 6.4.2. Local logs:
`build/release-runs.noindex/0.8.2-2Hc26m/`.

| Check | Status | Evidence |
| --- | --- | --- |
| Local build and artifact checks | passed | `make release-local`: 399 Core and 23 image tests, 5/5 public Harness cases, offline regressions, production Sparkle driver and Developer ID Release build. Both arm64 archives contain the same sealed app; embedded entitlements, SHA-256 and EdDSA feeds verified. |
| Apple notarization and tickets | passed | Submission `688b44b6-51cf-46b2-ac2e-0f22f819eddb` returned Accepted. The DMG and the app archived in the ZIP have validated stapled tickets. [Release manifest](../../build/FileMint-0.8.2.release.json). |
| Exact source CI | passed | [Run 42747129787](https://github.com/FileMintApp/FileMint/actions/runs/42747129787), attempt 1, compiled the app and Finder extension on macOS 15 and 26. The aggregate passed. |
| Draft candidate validation | passed | [Run 42747962448](https://github.com/FileMintApp/FileMint/actions/runs/42747962448), attempt 1, validated the six recorded draft assets before promotion. |
| Stable release and update discovery | passed | [FileMint 0.8.2](https://github.com/FileMintApp/FileMint/releases/tag/v0.8.2), Release `439898995`, became public Latest at **2026-11-10 11:15:22 Asia/Shanghai**. Read back the final metadata for all six assets. No local download or byte comparison of the remote archives. |
| Website | passed | [Build 42748134157](https://github.com/FileMintApp/FileMint/actions/runs/42748134157), attempt 1, retained Pages artifact `13731967666`; [deployment 42748253750](https://github.com/FileMintApp/FileMint/actions/runs/42748253750), attempt 1, deployed that artifact. Both live homepages and guides responded and contained the latest-release link or hidden-files guidance. |
| Official Homebrew tap | passed | Cask commit `0d30789e07a66f12c6e2ff28049b524884e2dc66`. [Initial CI](https://github.com/FileMintApp/homebrew-tap/actions/runs/42748668783) failed because Homebrew 7 required [tap trust](https://docs.brew.sh/Tap-Trust). Commit `fa4f955663c62e94200183118994d7a1607d3742` trusts the checked-out tap on the disposable runner and preserves the Cask and full audit. [Exact tap CI 42749108949](https://github.com/FileMintApp/homebrew-tap/actions/runs/42749108949), attempt 1, and Cask readback passed. |
| Publication journal | passed | [Journal](../../build/FileMint-0.8.2.publication.json) records `phase: complete`, `distribution_complete: true` and Homebrew `succeeded`. Network interruptions were recovered from the same candidate and journal. |
| Installed update and native lifecycle | not-run | No new installed-update, older-macOS or Homebrew lifecycle acceptance in this standard release. Earlier Finder and launcher observations remain tied to their original builds. |

### Final assets

- DMG: `FileMint-0.8.2.dmg`, 10,734,630 bytes; SHA-256 `6dc0acb5a5cf6d27468ab7b6437733c2281977160760c3b852daff76816b9350`.
- ZIP: `FileMint-0.8.2.zip`, 9,869,289 bytes; SHA-256 `f15dc907d2922ab10bb1b3abd92cdf84b558a01de92bafdf7b8c91489df1c0f2`.
- Public asset IDs: DMG `729898285`, DMG checksum `729898267`, ZIP
  `729898309`, ZIP checksum `729898291`, DMG feed `729898271` and ZIP feed `729898314`.
