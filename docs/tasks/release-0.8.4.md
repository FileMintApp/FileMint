# FileMint 0.8.4 release

FileMint 0.8.4 (build 33) became public Latest on 2026-11-25 at 15:36:38
Asia/Shanghai. Release `457775444` and `v0.8.4` resolve to the verified candidate
at `512761fff3f02224f67b81c0b095bfa84dd6d855`. The Latest response matched all six
verified asset IDs, names and sizes. [GitHub Release](https://github.com/FileMintApp/FileMint/releases/tag/v0.8.4).

## Verification

| Check | Status | Evidence |
| --- | --- | --- |
| Local build and artifact checks | passed | `make release-local` passed 25 image tests, 446 Core tests, the offline Harness and the production Sparkle driver check on arm64 macOS 27.2.1 with Xcode 27.2. Both archives passed checksum, architecture, minimum macOS, embedded entitlement and Sparkle feed checks. They contained the same sealed app. |
| Apple notarization and tickets | passed | Apple accepted submission `01a89000-d02c-44e7-a572-c518b00e16a4`. Stapled tickets validated for the DMG and the app inside the ZIP. |
| Finder registration after local packaging | passed | `pluginkit` showed the same single registration at `/Applications/FileMint.app` before and after packaging. |
| Exact source CI | passed | Arm64 macOS 15 and 26 completed tests and unsigned app and extension compilation on attempt 1. [Run 45568020721](https://github.com/FileMintApp/FileMint/actions/runs/45568020721). |
| Draft asset verification | passed | GitHub verified both archives, their checksums and their feeds on attempt 1. The publisher then promoted that release. [Run 45569166125](https://github.com/FileMintApp/FileMint/actions/runs/45569166125). |
| Website | passed | The production-base build passed all 34 local website tests. Actions built and deployed Pages artifact `15000878519` on attempt 1. Live checks confirmed both homepages, the FileDraw video and poster, and the updated position and keyboard instructions in both guides. [Build 45569352470](https://github.com/FileMintApp/FileMint/actions/runs/45569352470) · [Deploy 45569524584](https://github.com/FileMintApp/FileMint/actions/runs/45569524584). |
| Official Homebrew tap | passed | The public Cask readback matched version 0.8.4 and the DMG SHA-256. Tap `main` at `97ec2f97d473d46b7fa169af59710a206fc5186e` passed its CI on attempt 1. [Run 45569776143](https://github.com/FileMintApp/homebrew-tap/actions/runs/45569776143). |

`make publish-local` exited successfully. The local journal
`build/FileMint-0.8.4.publication.json` records phase `complete`, distribution
complete and Homebrew `succeeded`. The manifest is
`build/FileMint-0.8.4.release.json`. Logs and readback are in
`build/release-runs.noindex/0.8.4-31C4vo/`.

## Archives

| Archive | Bytes | Local SHA-256 |
| --- | ---: | --- |
| `FileMint-0.8.4.dmg` | 11,937,776 | `37d47f3fb0bfde0a5cb02012ad5085fc10e5d1f885949daa72fb585589859a18` |
| `FileMint-0.8.4.zip` | 10,924,387 | `eb91056d6a210ca7f8d92082ed5d344f95f8b59cde88892b3e5f0c72311251f0` |

The DMG, DMG checksum and DMG feed asset IDs are `790527316`, `790527312` and
`790527317`. The ZIP, ZIP checksum and ZIP feed asset IDs are `790527311`,
`790527313` and `790527355`.

## Runtime evidence

The release reuses the signed drawer and 60 Hz Genie fixture observations after
matching all 325 recorded inputs against the source and environment before the
version bump. The drawer suite passed. An initial cadence sample missed the
target on one right-edge glass dismissal, and the isolated repeat passed all 36
transitions. [Drawer acceptance](../ACCEPTANCE.md#drawer-dismissal-first-frame--2026-11-25).

Installed upgrade, Finder callbacks from an installed 0.8.4, clean-machine
installation and macOS 13/14 runtime remain unverified.
