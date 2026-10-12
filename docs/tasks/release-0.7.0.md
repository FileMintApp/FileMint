# FileMint 0.7.0 release

Status: complete
Next action: None for standard publication. Full installed DMG/ZIP update acceptance remains separate runtime work.

## Objective and scope

- Build and publish FileMint 0.7.0/build 28 through the standard draft-first release transaction.
- Verify Developer ID signing, accepted Apple notarization, stapled tickets, matching DMG/ZIP payloads and both signed update feeds before staging the six assets.
- Require source CI, bound candidate verification and the website build before public Latest availability; deploy the same website artifact afterward.

## Selected context

- Contracts: [Distribution](../../specs/domains/distribution.md), [Updates](../../specs/domains/updates.md), [Presentation](../../specs/domains/presentation.md).
- Procedure: [Distribution](../DISTRIBUTION.md), [HARNESS](../../specs/HARNESS.md), [Update checks](../../specs/verification/updates.md), [ZIP compatibility task](zip-update-compatibility.md).
- Release preparation: `project.yml`, `docs/RELEASE_NOTES.md`, bilingual README and website homepages.

## Decisions and progress

- User explicitly requested building and publishing version 0.7.0 on 2026-10-12.
- Live GitHub preflight confirmed Latest v0.6.8/build 27 and remote main `25f438fa728e0d8e521b3cc7d8db05393b691b07`; no v0.7.0 release/tag exists.
- Set 0.7.0/build 28 once in `project.yml`. Keep published older assets and update feeds immutable.
- Ship the implemented settings/menu-placement changes, dedicated compression engine and compatible ZIP update set. The access-migration prototype remains separate from production permissions.
- Preserve the current policy omitting local downloads/comparisons of uploaded release assets. The previous stable appcast was read only for version/build preflight.
- Committed release preparation as `318ee90f217b4c254c23d1a78553b79047afa118` and created/pushed `v0.7.0` at that source commit.
- `make release-local` and `make publish-local` completed successfully. The same six-asset draft passed all required remote checks before promotion; website deployment reused artifact `11723719802` afterward.
- Stable Latest became public at **2026-10-12 11:00:06 Asia/Shanghai**. Release ID: `410098527`; [public release](https://github.com/FileMintApp/FileMint/releases/tag/v0.7.0).
- At the owner's request, associated Issues #8 and #7 in both the local and public 0.7.0 release notes, posted Simplified Chinese release/implementation follow-ups, and closed both as `completed`. Issue #8's comment describes the shipped layout/menu scope and retains the existing authorization boundaries; it does not claim the deferred permissions work shipped.

## Evidence

Release commit/tag: `318ee90f217b4c254c23d1a78553b79047afa118` / `v0.7.0`.
Environment: arm64 macOS 27.2, Xcode 27.0 (27A266a).
Local manifests/logs: `build/FileMint-0.7.0.release.json`, `build/FileMint-0.7.0.publication.json`, `build/release-0.7.0.noindex/`.

| Check | Status | Evidence |
| --- | --- | --- |
| Latest/appcast and source preflight | passed | v0.6.8/build 27; clean primary main checkout; remote main matches local HEAD. |
| Bilingual website build | passed | `SITE_BASE=/FileMint/ pnpm run site:build`; log: `build/release-0.7.0.noindex/site-build.log`. |
| Tagged-source local checks | passed | `make release-local`: 235 Swift tests, 5 public Harness cases, 10 CLI regressions and offline appcast, ZIP, notarization/resume, publication, entitlement and native-QA infrastructure tests. [Log](../../build/release-0.7.0.noindex/release-local.log). |
| Production Sparkle driver | passed | Real framework compilation/callback checks covered cancellation, progress, draft deferral, relaunch choice, retry and errors; included in the local release log. |
| Release signatures and Apple notarization | passed | Developer ID app/Finder/compression/Sparkle signatures, arm64-only payload and resolved installer entitlements verified. Apple accepted `94c19d76-6cd3-4258-b6f3-be2ffd25a32f`; DMG and app tickets stapled and validated. |
| Both archives and signed feeds | passed | DMG/ZIP checksums and EdDSA feeds verified, with identical sealed app code hashes. [Source manifest](../../build/FileMint-0.7.0.release.json). |
| Source CI | passed | [Run 38197755992](https://github.com/FileMintApp/FileMint/actions/runs/38197755992): macOS 15/26 arm64 jobs and aggregate succeeded for the release source commit. |
| Bound draft candidate verification | passed | [Run 38197905786](https://github.com/FileMintApp/FileMint/actions/runs/38197905786), request `9f5f081ebc1a4691b56b9737889446bd`; remote signatures, tickets, entitlements, checksums and both feeds passed before publication. |
| Required website build | passed | [Run 38197960081](https://github.com/FileMintApp/FileMint/actions/runs/38197960081), request `9d899db946864650819e423e2f160545`; retained Pages artifact `11723719802`. |
| Public stable Latest | passed | Release `410098527` is public, stable and Latest. All six asset IDs/names/sizes match the journal. [Publication log](../../build/release-0.7.0.noindex/publish-local.log), [journal](../../build/FileMint-0.7.0.publication.json), [public metadata](../../build/release-0.7.0.noindex/published-release.json). |
| Website deployment | passed | [Run 38198021071](https://github.com/FileMintApp/FileMint/actions/runs/38198021071), request `adfb210084ba41e797e188abe421da7b`; deployed the verified build after publication. [Website](https://filemintapp.github.io/FileMint/). |
| Live website copy | passed | HTTP reads of both public homepages contain 0.7.0 and its final release link; retained as `site-zh.html` and `site-en.html` in the local evidence directory. |
| Resolved-issue association and closure | passed | [#8 follow-up](https://github.com/FileMintApp/FileMint/issues/8#issuecomment-6117041818), closed at 11:09:41; [#7 follow-up](https://github.com/FileMintApp/FileMint/issues/7#issuecomment-6117047463), closed at 11:10:20 on 2026-10-12 Asia/Shanghai. REST readback confirmed `closed`/`completed` and one matching follow-up each. Release-note readback confirmed both links and unchanged asset records. Local evidence: `build/release-0.7.0.noindex/issue-followup/evidence.json`. |
| Native ZIP/legacy DMG update acceptance | not-run | This standard release run did not replace/launch the installed production app. The full FileMint old-DMG/new-ZIP runtime check from the ZIP compatibility task remains pending; historical minimal-host replacement and current artifact/CI checks do not prove it or installed Finder refresh. |
| Local remote-asset byte/hash comparison | not-run | Omitted under the current publication policy. Remote candidate validation and public metadata identity checks passed; no local/remote content equality claim. |

### Final local artifacts

- DMG: `FileMint-0.7.0.dmg`, 8,687,783 bytes; SHA-256 `ad1e52082e1443ca2cfcac56eb3c795feede57e8d6cb44504a3820a759aa16d1`.
- ZIP: `FileMint-0.7.0.zip`, 8,057,615 bytes; SHA-256 `6b67f00286c172a76d41caa339e1cbe2e6c0834c6749fadaee60efce052aa59b`.
- Public assets: DMG, ZIP, their two `.sha256` files, `appcast.xml` and `appcast-zip.xml`. Each feed is 852 bytes and points to its own final tag-based archive URL.
- Complete local summary: [evidence.json](../../build/release-0.7.0.noindex/evidence.json). These are local build/artifact records, not GitHub build attestations.

## Handoff

- Publication and website deployment are complete; preserve the final archives, manifests and publication journal. Never replace assets or move `v0.7.0`.
- The later evidence-only commit does not change the release source or candidate. Any future transaction diagnosis must use the original tagged source and journal.
- macOS 13/14, clean-Mac permissions and exhaustive installed Finder/UI coverage require separate runtime evidence; standard artifacts and hosted CI do not establish them.
