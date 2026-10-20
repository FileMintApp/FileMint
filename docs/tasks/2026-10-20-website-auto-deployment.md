# Task: Automatic website build and deployment

Status: in-progress
Next action: Deliver the verified workflow and confirm automatic deployment online.

## Objective and scope

- A main website push builds, then automatically deploys the exact successful Pages artifact.
- Preserve application publication gates, public release assets and existing release deployment.
- Retain manual deployment retries and serialize both deployment paths.
- Preserve unrelated concurrent token/CI work in the primary checkout.

## Selected context

- [Presentation](../../specs/domains/presentation.md), [distribution](../../specs/domains/distribution.md).
- [Website distribution](../DISTRIBUTION.md#website-only-updates), [Harness](../../specs/HARNESS.md).
- `.github/workflows/build-pages.yml`, `.github/workflows/deploy-website.yml`, `website/scripts/prepare-deployment.mjs`.

## Decisions and progress

- Use `workflow_run` after a successful original-repository main-push website build.
- Resolve exact build/artifact/release identities from GitHub APIs and revalidate after downloading.
- Compare against the public stable application, allowing independent docs/CI/publication-tooling maintenance.
- Skip superseded builds and unpublished application changes before fetching artifacts; other validation errors fail closed.
- Add regression cases for automatic identity discovery, rejected origins/events, skipped sources and download races.

## Evidence

| Check | Status | Evidence |
| --- | --- | --- |
| Local website tests/build and context | passed | `SITE_BASE=/FileMint/ pnpm run site:build`: 22 tests and production build; context 22 documents/139 links; whitespace check passed. |
| Workflow syntax and gates | passed | Parsed YAML; evaluated actual job and candidate-step expressions for success, failure, cancellation, fork, branch, release-dispatch and manual-retry cases; pinned actions/shared concurrency checked. |
| Release publication regression | passed | `python3 scripts/test_publish_release.py`: 48 tests; release-bound flow unchanged. |
| Automatic hosted build/deployment | not-run | Requires workflow delivery |
| Live Chinese/English content | not-run | Requires deployment |

Local verification used primary checkout `236a79f` plus this website automation change.
Logs and the workflow check script are in ignored `build/website-auto-deploy-20261020/`.
