# FileMint 0.7.0 release

Status: in-progress
Next action: Commit and tag the prepared 0.7.0/build 28 source, then run the local release gates.

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

## Evidence

Release commit/tag: pending.
Local manifests/logs: `build/FileMint-0.7.0.release.json`, `build/FileMint-0.7.0.publication.json`, `build/release-0.7.0.noindex/`.

| Check | Status | Evidence |
| --- | --- | --- |
| Latest/appcast and source preflight | passed | v0.6.8/build 27; clean primary main checkout; remote main matches local HEAD. |
| Bilingual website build | passed | `SITE_BASE=/FileMint/ pnpm run site:build`; log: `build/release-0.7.0.noindex/site-build.log`. |
| Local release checks | not-run | Run `make release-local` at the prepared clean tag. |
| Native ZIP/legacy DMG update acceptance | not-run | Prior minimal-host ZIP replacement is historical fixture evidence. It does not prove a full installed FileMint update or Finder refresh. |
| Draft candidate, source CI and website | not-run | Run the bound `make publish-local` transaction after applicable local acceptance. |
| Public Latest and website deployment | not-run | Complete only after pre-publication checks pass. |

## Handoff

- Keep candidate archives, source manifest and publication journal intact on interruption.
- Resume a pending Apple submission with its original stage and ID; never rebuild merely to retry notarization or publication.
- macOS 13/14, clean-Mac permissions and exhaustive installed Finder/UI coverage require separate runtime evidence; standard artifacts and hosted CI do not establish them.
