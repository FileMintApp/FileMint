# FileMint 0.8.0 release

Status: complete
Next action: None for standard publication. Installed-update and broader native runtime acceptance remain separate work.

## Objective and scope

- Publish FileMint 0.8.0/build 29 from the primary main checkout after the user's 2026-10-20 request to build and publish a new version.
- Ship the implemented batch rename and file information/checksum tools, with matching bilingual release notes and usage guidance.
- Require local verification, Developer ID signing, accepted notarization, stapled DMG/app tickets, both signed feeds, exact source CI and draft-candidate verification before stable Latest promotion; deploy the verified website afterward.

## Selected context

- Contracts: [Distribution](../../specs/domains/distribution.md), [File tools](../../specs/domains/file-tools.md), [Presentation](../../specs/domains/presentation.md).
- Procedure: [Distribution](../DISTRIBUTION.md), [HARNESS](../../specs/HARNESS.md), [AI Playbook](../AI_PLAYBOOK.md).
- Feature evidence: [Batch rename workspace](2026-10-16-batch-rename-design.md), [File information/checksums](2026-10-19-file-info-checksums.md). Existing evidence remains tied to its original revisions and environments.

## Decisions and progress

- Live GitHub preflight confirmed Latest v0.7.0 and main `587dd0e960f5986b456f62e7cba4b685eed78b01`, matching the clean primary checkout.
- Authenticated release listing and remote tag lookup found no v0.8.0 candidate. The public v0.7.0 appcast confirms the successor version/build check passes.
- Choose 0.8.0/build 29 for the added file-tool capabilities. Keep older tags/assets immutable and preserve the existing Sparkle key and signing/authorization configuration.
- Both new child tools remain default off. Batch rename documents its local writable APFS scope; checksum guidance distinguishes integrity values from encryption or proof of origin.
- Follow the current policy omitting local downloads/comparisons of uploaded release archives. Read the previous stable appcast only for version/build preflight.
- Homebrew synchronization remains subject to the existing explicit opt-in; this task uses the standard publication command.
- Committed release preparation as `ab25fb7bf42ac3806ca725cd107b912da47ba010` and created/pushed `v0.8.0` at that source. Both canonical commands completed successfully without rebuilding or replacing the candidate during publication.
- Stable Latest became public at **2026-10-20 09:43:55 Asia/Shanghai**, Release ID `417913389`: [FileMint 0.8.0](https://github.com/FileMintApp/FileMint/releases/tag/v0.8.0).
- All required remote checks passed before promotion. Website deployment then reused Pages artifact `12234434852`; HTTP readback of both homepages and both guides confirmed the shipped batch rename and checksum copy.

## Evidence

Tested release commit/tag: `ab25fb7bf42ac3806ca725cd107b912da47ba010` / `v0.8.0`.
Environment: arm64 macOS 27.2 (26B5101f), Xcode 27.1 (27A9275).
Local logs and metadata: `build/release-0.8.0.noindex/`, `build/FileMint-0.8.0.release.json`, `build/FileMint-0.8.0.publication.json`.

| Check | Status | Evidence |
| --- | --- | --- |
| Latest and source preflight | passed | Public v0.7.0; matching local/remote main, clean checkout before preparation. |
| Release metadata, context and website build | passed | `make verify-context`: 22 documents / 139 local links; metadata 0.8.0/build 29; task links and `git diff --check`; `make project`; `SITE_BASE=/FileMint/ pnpm run site:build`, [log](../../build/release-0.8.0.noindex/site-build.log). |
| Tagged-source local verification | passed | `make release-local`: 337 Core tests / 34 suites, 22 image tests / 2 suites, public JSON Harness, CLI and offline signing, publication, notarization/resume, native-QA infrastructure and restricted permission regressions. [Log](../../build/release-0.8.0.noindex/release-local.log). |
| Production Sparkle driver | passed | Real-framework callback checks covered cancellation, progress, draft deferral, relaunch choice, retry and errors. This does not perform an installed update. |
| Developer ID signing and Apple notarization | passed | Arm64-only app/Finder/Sparkle payload, compression runtime and embedded entitlements verified. Apple submission `2dc362a0-16b3-475c-a4ce-ab9d7be3819c` read back as `Accepted`; DMG/app tickets stapled and validated. [Apple result](../../build/release-0.8.0.noindex/notarization.json). |
| Both archives and signed feeds | passed | DMG/ZIP checksums and EdDSA feeds passed; archives contain the same sealed application code hash. [Source manifest](../../build/FileMint-0.8.0.release.json). |
| Source CI | passed | [Run 39354176234](https://github.com/FileMintApp/FileMint/actions/runs/39354176234): macOS 15/26 arm64 tests, unsigned main-app/Finder-extension builds and aggregate succeeded for the exact release commit. |
| Bound draft-candidate verification | passed | [Run 39354889036](https://github.com/FileMintApp/FileMint/actions/runs/39354889036), request `5b1d60ed001b4882977e18a8aaf58527`; verified the same six asset IDs before publication. |
| Required website build | passed | [Run 39354990375](https://github.com/FileMintApp/FileMint/actions/runs/39354990375), request `697bc5256e704487a4e2bedf540360ae`; retained Pages artifact `12234434852`. |
| Public stable Latest | passed | Release `417913389` is public, stable and Latest; six public asset names, IDs, sizes and final immutable tag URLs match the journal. [Metadata](../../build/release-0.8.0.noindex/published-release.json), [publication log](../../build/release-0.8.0.noindex/publish-local.log), [journal](../../build/FileMint-0.8.0.publication.json). |
| Website deployment and live copy | passed | [Run 39355066196](https://github.com/FileMintApp/FileMint/actions/runs/39355066196), request `e5c874cfa772468ab53fb131df2762e3`; deployed the verified artifact after publication. Both live homepages and guides contain the new feature copy; HTML retained in the evidence directory. Current-release labels still use public Latest discovery. [Website](https://filemintapp.github.io/FileMint/). |
| Homebrew synchronization | not-run | Explicit opt-in was not enabled; no tap update or native brew operation was performed. |
| Installed release, minimum-OS and provider acceptance | not-run | Standard publication does not install/launch the production app or repeat exhaustive native QA. Existing feature acceptance does not prove the final release's full runtime matrix. |
| Local remote-archive byte/hash comparison | not-run | Omitted by current policy; GitHub owns independent remote candidate validation. |

### Final artifacts

- DMG: `FileMint-0.8.0.dmg`, 9,733,892 bytes; SHA-256 `c112cf39c36d14d225dd44ae8d487213f792db554d2c37262b18098b486f11dc`.
- ZIP: `FileMint-0.8.0.zip`, 8,982,066 bytes; SHA-256 `c6e2edf40f9ad2c9abd7c138b60b012bb01db8d7d011ed1a8db98692b74b7c5c`.
- Exactly six public assets: both archives, both portable `.sha256` files, `appcast.xml` and `appcast-zip.xml` (852 bytes each).
- Complete local summary: [evidence.json](../../build/release-0.8.0.noindex/evidence.json). Local artifact records are not GitHub build attestations.

## Handoff

- Application publication and website deployment are complete. Preserve final archives, manifests and publication journal; never replace these assets or move `v0.8.0`.
- The following evidence-only commit does not change the tagged release source or candidate. Any transaction diagnosis must use the original source and journal.
- No new encryption feature is shipped; the separate sealed research remains untouched.
- Installed Finder/UI, macOS 13/14, provider/NAS behavior and actual installed-update acceptance require their own runtime evidence.
