# Website feature visibility and Node 26 CI

Status: in-progress
Next action: Verify locally with Node 26, then push and confirm the website build/deployment.

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
Local Node is v26.12.1; the official release index reports v26.13.0 as the newest
stable 26.x on 2026-10-29. CI's rolling 26.x selection will resolve it.
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

Remote source CI, website build and live deployment verification pending.
