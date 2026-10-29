# FileMint 0.8.1 release

Status: complete
Next action: None for standard publication. Installed-update and broader native runtime acceptance remain separate work.

## Objective and scope

- Publish 0.8.1/build 30 from primary `main`, including the three Debug fixes
  accepted by the user on 2026-10-29 and all verified main-branch changes since
  0.8.0. The user selected 0.8.1 for this release.
- Keep the signed/notarized DMG, compatible ZIP and both signed update feeds.
  Complete exact source CI, draft-candidate checks, applicable website build and
  deployment, and the official Homebrew tap synchronization/CI.
- Existing tags and public assets remain immutable. Standard publication does
  not repeat installation or a full GUI acceptance run.

## Selected context

- [Distribution contract](../../specs/domains/distribution.md) and
  [procedure](../DISTRIBUTION.md), [Harness](../../specs/HARNESS.md),
  [AI Playbook](../AI_PLAYBOOK.md).
- [Updates](../../specs/domains/updates.md),
  [presentation](../../specs/domains/presentation.md),
  [startup/search](../../specs/domains/startup.md),
  [creation](../../specs/domains/creation.md),
  [file tools](../../specs/domains/file-tools.md).
- [Accepted fixes](2026-10-29-debug-acceptance-fixes.md),
  [quick-search implementation](2026-10-29-quick-search-redesign.md),
  [copy file contents](2026-10-21-copy-file-contents.md).

## Preparation

- Live preflight confirmed Latest `v0.8.0` and no `v0.8.1` Release or remote tag.
  Primary `main` is based on accepted-fix commit `988e65192ee565c0bdec6ed7a8878c97a41fbff7`.
- Version/build now have one source in `project.yml`. Bilingual release notes
  follow the current eight-section template and preserve older release entries.
- README, guides and privacy copy cover direct drafts, Quick Search and explicit
  text-file clipboard publication; optional switches retain their actual defaults.
- Metadata/successor checks, context links and whitespace checks passed. Local
  website build passed all 27 tests and static generation using Node 24.21.0 /
  pnpm 11.26.0, matching the CI toolchain choice. The unrelated Node 26 global
  pnpm launcher stalled while resolving its requested package-manager version;
  it was stopped without changing dependencies or lockfiles.

## Evidence

Release source/tag: `052e35cb25efa61236083189f0769f4f9976de16` / `v0.8.1`.
This source includes the accepted fixes in `988e651`.
Environment: arm64 macOS 27.2, Xcode 27.1, Swift 6.4; website Node 24.21.0 / pnpm 11.26.0.
Local logs: `build/release-runs.noindex/0.8.1-ey_wcz85`.

| Check | Status | Evidence |
| --- | --- | --- |
| Release metadata/context/website | passed | Strictly newer than 0.8.0/build 29; bilingual notes and local links checked. Website: 27 tests and static generation; `site-build-node24.log` in the local run. |
| Canonical `make release-local` | passed | 370 Core / 23 Images tests plus Harness, CLI and offline release/permission checks; production Sparkle driver, Release build, arm64-only app/Finder/helpers, signing and entitlement checks. `release-local.log` in the local run. |
| Apple notarization and stapling | passed | Submission `040d3cba-f4a9-4328-9fc6-8e81c23c8dc5` read back as `Accepted`; DMG and enclosed app tickets stapled/validated. `notarization.json` in the local run. |
| DMG/ZIP and both feeds | passed | Same sealed app in both archives, portable checksums and EdDSA feed signatures verified. [Source manifest](../../build/FileMint-0.8.1.release.json). |
| Exact source CI | passed | [Run 40827055531](https://github.com/FileMintApp/FileMint/actions/runs/40827055531), attempt 1, macOS 15/26 and aggregate succeeded for the tagged source. |
| Bound draft-candidate validation | passed | [Run 40827781592](https://github.com/FileMintApp/FileMint/actions/runs/40827781592), request `9dd4ef19487c434abef0a0cfc4240d9f`, attempt 1; remote checks ran before publication against the six recorded asset IDs. |
| Required website build | passed | [Run 40827867043](https://github.com/FileMintApp/FileMint/actions/runs/40827867043), request `837388f0eda84540a11fa9b47a63305d`, attempt 1; Pages artifact `12877531684`. |
| Stable Latest and online-update availability | passed | [FileMint 0.8.1](https://github.com/FileMintApp/FileMint/releases/tag/v0.8.1), Release `427516942`, public at **2026-10-29 14:13:40 Asia/Shanghai**. Six public assets and final tag URLs read back; no local remote-archive download/comparison. |
| Website deployment/live content | passed | [Run 40827958879](https://github.com/FileMintApp/FileMint/actions/runs/40827958879), request `6a2b5e98797c4eccae287ef73f792df0`, attempt 1, reused the verified artifact. Both live homepages and guides returned successfully; guides include Quick Search and Copy File Contents. HTML saved in the local run. |
| Official Homebrew synchronization | passed | Tap commit `a42bfaa1249c9fd929da52d4c450b6bf62393dec`; [run 40828155801](https://github.com/FileMintApp/homebrew-tap/actions/runs/40828155801), attempt 1, passed. Local metadata checks and exact-commit CI completed through `make publish-local`. |
| Publication journal | passed | [Journal](../../build/FileMint-0.8.1.publication.json) records `phase: complete`, `distribution_complete: true` and Homebrew `succeeded`. `publish-local.log` in the local run. |
| Installed update/older macOS/provider matrix | not-run | Standard publication did not replace the user's working Debug app or replay installed updates. Prior accepted feature fixes remain tied to their own evidence. |

### Final assets

- DMG: `FileMint-0.8.1.dmg`, 10,165,086 bytes; SHA-256 `b9ccc5cefdd6fa91bb7de170b94ccfa2dce796895f26e7c7f1bbb111b56e452b`.
- ZIP: `FileMint-0.8.1.zip`, 9,351,593 bytes; SHA-256 `823c54bc7d14c16c7103bb4ff7a976794d25f92661fb2fc49c2465602ae03cff`.
- Public asset IDs: DMG `687548161`, its checksum `687548159`, ZIP `687548154`, its checksum `687548157`, `appcast.xml` `687548158`, `appcast-zip.xml` `687548203`.

The following evidence-only commit preserves the original release source/tag,
signed archives and journal. These are locally built Developer ID artifacts,
not GitHub-built artifact attestations. External-folder persistence, older macOS,
Homebrew native lifecycle and full installed-update/runtime coverage remain
separate acceptance boundaries.
