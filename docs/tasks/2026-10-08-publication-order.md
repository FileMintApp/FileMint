# Task: Verify a draft before public release and deploy the website afterward

Status: complete
Next action: The next authorized release exercises the new draft workflows on
GitHub before promotion. No publication is requested by this implementation task.

## Objective and scope

- Keep all local source, Developer ID signing, notarization, stapling,
  entitlement, architecture, checksum and update-signature checks.
- Upload the verified candidate as a draft. Require source CI, candidate verification
  and applicable website builds before promoting that draft to stable/Latest.
- Preserve Sparkle update compatibility: final signed appcast URLs and metadata,
  public-key/signature checks, helper contents and resolved Mach entitlements.
- Confirm public availability, deploy the already verified website build, and
  distinguish draft failures, uncertain publication and published follow-up failures.
- Omit local remote-asset downloads and content comparisons. Return success and
  continue release records and evidence commits only when all applicable Actions
  succeed; report failures as occurring after publication.
- Preserve historical release evidence and immutable published assets. This
  changes the future workflow; it is not a request for another release.

## Selected context

- [Distribution](../../specs/domains/distribution.md),
  [Updates](../../specs/domains/updates.md),
  [Presentation](../../specs/domains/presentation.md),
  [procedure](../DISTRIBUTION.md), [HARNESS](../../specs/HARNESS.md),
  [update verification](../../specs/verification/updates.md),
  [AI Playbook](../AI_PLAYBOOK.md).
- Entry points: `scripts/publish_local.sh`, `scripts/release_publication.py`,
  `.github/workflows/release.yml`, `build-pages.yml`, `deploy-pages.yml`,
  and release verification targets in `Makefile`.

## Decisions and progress

- Candidate verification is explicitly dispatched while the Release is a draft;
  public release events cannot serve as a pre-publication gate.
- A local journal records candidate, Release/asset identities and exact request/run
  IDs, allowing ambiguous promotion responses and unfinished deployment to resume.
- Source CI and candidate verification gate publication. Changed website inputs
  add a pre-publication build; deployment reuses that artifact only after publication.
- The owner emphasized preserving online updates after the 0.5.8 installer issue.
  Signing/packaging, Sparkle configuration/keys and client code remain unchanged.
  Both local and candidate verification retain the full installer entitlement and
  signing checks; promotion additionally confirms Latest metadata and final URLs.

## Evidence

Worktree: primary `main`, base `27a89a2` plus task changes. The earlier verification
below covered the first revision, which still waited for CI inside `publish-local`.

| Check | Status | Evidence |
| --- | --- | --- |
| Publication CLI with offline adapters | passed | 9 regression tests cover upload/availability ordering, no remote downloads/comparison, local verification/source guards, existing assets, upload failure, invalid metadata and post-check failure. Included in `make verify`. |
| `make verify` | passed | 220 Core tests, 14 image tests, 5 public cases, 10 CLI regressions and offline release checks including the 9 publication tests. [Log](../../build/publication-order-2026-10-08.89p3qcmw.noindex/verify.log). |
| New live publication | not-run | Not requested for this workflow-only change. |

Earlier confirmation-only revision: `make verify` passed on the primary worktree after removing the
CI wait. It includes 9 publication regressions confirming successful return after
GitHub publication confirmation, immediate continuation of the next release step,
no remote downloads/comparison or CI wait, and retained publication/source guards.
[Confirmation-only verification log](../../build/publication-confirmation-2026-10-08.4bxzmeg1.noindex/verify.log).
No app build, signed artifact verification or live publication was run for this
publication-control change; artifact preparation and the remote workflow are unchanged.

Earlier post-publication-wait revision: `make verify` passed on the primary worktree, including 12
publication regressions running the actual publication and Actions-wait scripts
with offline GitHub adapters. They cover exact commit/branch/tag/event matching,
waiting on each of the three workflows before the next step, skipping an untriggered
website deployment, failure/cancellation/non-success conclusions, missing runs,
timeouts, API failures and preservation of source/candidates and published assets.
[Actions-wait verification log](../../build/publication-actions-2026-10-08.mv7jfcb5.noindex/verify.log).
Shell syntax and diff whitespace checks also passed. No live publication or remote
Actions wait was performed; app build, signed artifact checks and website builds
are outside this publication-control change.

Current draft-first revision: implemented and verified on primary `main` at base
`27a89a2` plus this implementation. Apple signing, packaging, Sparkle/client
configuration and appcast generation are unchanged.

| Current check | Status | Evidence |
| --- | --- | --- |
| `make verify` | passed | Includes 32 publication transaction, source-guard, runner and transport regressions. Covers draft-only staging, mandatory CI, source/run/asset binding, failed checks, recovery, public Latest URLs, website artifact reuse and preservation of the existing full Sparkle artifact verifier. [Log](../../build/draft-publication-2026-10-08.0sloh1nu.noindex/verify-final.log). |
| `SITE_BASE=/FileMint/ pnpm run site:build` | passed | [Website build log](../../build/draft-publication-2026-10-08.0sloh1nu.noindex/site-build.log). |
| Existing local 0.6.8/build 27 signed DMG | passed | Read-only artifact verification passed resolved Sparkle Mach entitlements, nested component signatures, notarization/stapled ticket and Ed25519 appcast checks. This is the retained existing artifact, not a new build or installed upgrade. [Log](../../build/draft-publication-2026-10-08.0sloh1nu.noindex/sparkle-artifact.log). |
| Current public Latest metadata | passed | Read-only GitHub queries through the production adapter confirmed v0.6.8/tag commit and canonical public asset URLs; zero asset downloads. [Result](../../build/draft-publication-2026-10-08.0sloh1nu.noindex/latest-metadata.json). |
| Workflow YAML and diff whitespace | passed | Ruby YAML parse of candidate, website build and deployment workflows; `git diff --check`. |
| New remote draft/promotion/deployment and installed upgrade | not-run | No new release, remote workflow dispatch, installation or old-to-new native upgrade was requested. Offline adapters are not live Actions evidence. |

## Handoff

- Script and current distribution/verification instructions now implement the
  requested draft-first ordering. The full artifact verifier is retained behind
  an explicitly dispatched candidate workflow, and website deployment follows
  public availability using the recorded successful build artifact.
- Delivery is local only. The already published 0.6.8 artifacts and
  their historical byte-comparison evidence were not modified.
