# Website feature visibility and Node 26 CI

Status: complete
Next action: None.

## Scope and decisions

- Follow the newest stable Node 26.x in source CI and website project-script
  jobs using `check-latest: true`, with version logs. Pinned Actions retain their
  own bundled runtimes; the project's pnpm version and frozen lockfile stay fixed.
- Add a bilingual homepage section for Quick Search/global shortcut, Copy File
  Contents, direct creation and keyboard-navigation improvements. Link to actual
  guide anchors and retain current defaults, authorization rules and text limits.
- Reuse the site's colors, layout and native links. Current-release discovery
  continues to use public Latest metadata.

## Context

- [Presentation](../../specs/domains/presentation.md),
  [distribution](../../specs/domains/distribution.md),
  [website-only deployment](../DISTRIBUTION.md#website-only-updates),
  [Harness](../../specs/HARNESS.md).
- `modern-web-guidance`: consulted `card`, `responsive-design` and `css`.
  Applied semantic article/footer links, intrinsic card columns, existing theme
  tokens and logical spacing; no new dependency or interactive mock app.

## Evidence

Starting source: primary `a38c4a58afb60e9ae105cf385585d22bec16f2a5`.
Local Node is v26.12.1. CI is configured to resolve the newest stable 26.x
available to setup-node rather than pinning a patch. Actual Node versions below
come from completed job logs, not the preflight release-index lookup.
Local evidence: `build/website-node26.noindex/run.juhc925w`.

- `SITE_BASE=/FileMint/ pnpm run site:build`: passed, 27 tests and generation.
  Node 26.12.1 runs the existing pnpm 11.26.0 CLI through task-local symlinks;
  no global runtime or package-manager installation was changed.
- `make verify` and unsigned `make build`: passed. Main and embedded Finder
  executables compiled; no native UI replay or app installation was required.
- Ruby's standard YAML parser accepted all three workflows; permissions,
  deployment gates, matrix and aggregate dependencies match their prior values.
  Each setup-node step selects `26.x` with `check-latest: true`.
- Generated Chinese/English homepage guide links all resolve to existing anchors
  (13 each). Chrome visual checks cover the Chinese desktop section and English
  at 390px, with no horizontal overflow; temporary viewport override was reset.

## Remote and live evidence

Implemented source: `2a8831ba8a9b4bfa50e2251b71e00f24929ac85f`.

| Check | Result |
| --- | --- |
| Source CI | [Run 40829886204](https://github.com/FileMintApp/FileMint/actions/runs/40829886204) passed both macOS 15/26 and the aggregate. Both jobs logged v26.12.1. |
| Website build | [Run 40829886222](https://github.com/FileMintApp/FileMint/actions/runs/40829886222) passed; setup-node logged `26.x`, `check-latest: true`, and resolved v26.12.1, matching local. Pages artifact `12877674896`. |
| Website deployment | [Run 40829935018](https://github.com/FileMintApp/FileMint/actions/runs/40829935018) passed on Node v26.12.1; the final deployment step executed successfully, not skipped. |
| Live content | Chinese and English homepages each contain three new cards; both live guides contain the Copy File Contents anchor. Public HTML and remote logs are retained in the local evidence directory. |
| Browser observation | Reused the user's existing Chrome website tab. Observed the deployed Chinese section with three cards, no horizontal overflow and a latest-release label resolving to v0.8.1. [Screenshot](../../build/website-node26.noindex/run.juhc925w/live-home-zh.jpg). English local 390px rendering was also inspected; an English live navigation timeout was covered by HTTP content/anchor checks. |

A concurrent task changed the app's successful-copy feedback. Those app, test and
file-tools contract edits were excluded from this website/CI commit; they were
subsequently committed independently as `260686c`. The deployed site and CI
evidence above remain tied to `2a8831b`. No application release/tag/assets were
changed by this task. This following record-only update does not redeploy the site.
