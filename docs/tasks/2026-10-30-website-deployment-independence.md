# Task: Independent website deployment

Status: in-progress
Next action: Verify the deployment fix, commit the requested local updates, then confirm the exact remote deployment and live Quick Search entry.

## Objective and scope

- Deliver the already reviewed bilingual Quick Search promotion and fourth homepage scene.
- Remove the false dependency on App source equality with the latest stable tag.
- Preserve successful-build provenance, public stable Release validation, ancestry,
  current-main checks, artifact identity/expiry and download-race checks.
- Commit the user's existing launcher-probe work separately, preserving its P0 limitations.
- No application release, tag, asset or installed-app change is part of this fix.

## Selected context

- [Presentation](../../specs/domains/presentation.md#product-presentation),
  [Distribution](../../specs/domains/distribution.md),
  [website procedure](../DISTRIBUTION.md#website-only-updates).
- `website/scripts/prepare-deployment.mjs`, `website/tests/deployment.test.mjs`,
  `.github/workflows/deploy-website.yml`.
- [Harness](../../specs/HARNESS.md): website checks; full offline checks also apply
  to the user's pending executable native-QA infrastructure changes.

## Decisions and progress

- Commit `07d1323` built successfully in [run 40990306128](https://github.com/FileMintApp/FileMint/actions/runs/40990306128).
- [Deployment run 40990356063](https://github.com/FileMintApp/FileMint/actions/runs/40990356063)
  reported success while its actual Pages deployment step was skipped. The log says
  application or unsupported source changes await a published release.
- The old gate compares all paths since `v0.8.1`; earlier App changes such as
  selection-scoped visibility and copy feedback therefore block a later website-only commit.
  Uncommitted local files are not part of that comparison.
- Deploy the verified static artifact independently of those App differences.
  Review public feature claims under the owning presentation contract; the
  release-dispatched path and public-release checks retain their existing roles.
- Add a regression using a real Git history with native changes after a stable
  tag, plus a later website change, rather than only testing a mocked path list.
- The requested pre-existing local launcher-probe work was committed separately
  as `e644aef`; its task still records P0 as in progress.

## Evidence

Tested commit/worktree: `07d1323` plus this fix and the user's pending launcher-probe updates.
Environment: local macOS, Node 26; remote website build/deployment on GitHub Actions.

| Check / command | Status | Observed result / evidence |
| --- | --- | --- |
| Deployment regression and production website build | passed | `SITE_BASE=/FileMint/ pnpm run site:build`: 27 tests and VitePress production build; real Git history covers both automatic deployment and manual retry after native changes. |
| Full offline verification for pending native-QA infrastructure | passed | `make verify` exited 0; local log `build/website-deployment-fix-20261030/verify.log`, including all 6 launcher transport regressions. No native GUI acceptance was added. |
| Remote exact-commit website deployment | not-run | Must verify the actual Pages step, not only the workflow conclusion. |
| Live bilingual fourth Quick Search scene | not-run | Use the requested in-app browser. |

## Handoff

- Remaining work: local checks, scoped commits/push, actual deployment and live verification.
- The launcher integration remains a prototype with incomplete native acceptance;
  see its [existing task](2026-10-29-shortcuts-and-launchers.md).
