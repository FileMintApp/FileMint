# Task: Independent website deployment

Status: complete
Next action: None; use the normal main-push website flow for future reviewed updates.

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
- Fix `4d512ce` and the local updates were pushed to `origin/main` together.
  The subsequent website build and actual Pages deployment step both succeeded.
  The official Chinese and English pages now show all four scenes, and each
  Quick Search scene loads its matching-language 1360 × 1000 capture.

## Evidence

Tested commit/worktree: `e644aef` for the local launcher-probe update, and `4d512ce` for the website fix and deployed artifact.
Environment: local macOS, Node 26; remote website build/deployment on GitHub Actions.

| Check / command | Status | Observed result / evidence |
| --- | --- | --- |
| Deployment regression and production website build | passed | `SITE_BASE=/FileMint/ pnpm run site:build`: 27 tests and VitePress production build; real Git history covers both automatic deployment and manual retry after native changes. |
| Full offline verification for pending native-QA infrastructure | passed | `make verify` exited 0; local log `build/website-deployment-fix-20261030/verify.log`, including all 6 launcher transport regressions. No native GUI acceptance was added. |
| Remote exact-commit website deployment | passed | [Build 40992726679](https://github.com/FileMintApp/FileMint/actions/runs/40992726679) succeeded for `4d512ce`; [deploy 40992773821](https://github.com/FileMintApp/FileMint/actions/runs/40992773821) ran configure/upload/Pages deployment successfully rather than skipping them. |
| Live bilingual fourth Quick Search scene | passed | In the requested in-app browser, the [Chinese](https://filemintapp.github.io/FileMint/) and [English](https://filemintapp.github.io/FileMint/en/) official homepages both displayed four tabs and loaded the correct Quick Search capture. Latest stable discovery still points to `v0.8.1`. Screenshots are local under `build/website-deployment-fix-20261030/`. |

## Handoff

- Remaining website work: none. All requested local source updates were committed and pushed.
- The launcher integration remains a prototype with incomplete native acceptance;
  see its [existing task](2026-10-29-shortcuts-and-launchers.md).
