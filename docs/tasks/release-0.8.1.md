# FileMint 0.8.1 release

Status: in-progress
Next action: Commit/tag the prepared source, run `make release-local`, then complete `make publish-local` including Homebrew.

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

Local run directory: `build/release-runs.noindex/0.8.1-ey_wcz85`.
Source/tag, checksums, notarization, remote run IDs, public availability and
Homebrew receipt will be recorded after the canonical publication steps finish.
External-folder persistence, older macOS and the full installed-update/runtime
matrix remain separate acceptance boundaries.
