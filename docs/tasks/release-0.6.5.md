# Task: FileMint 0.6.5 release

Status: in-progress
Next action: Run the standard local and remote release stages from the clean tagged release source.

## Objective and scope

- Publish FileMint 0.6.5 (build 24) as a stable release using
  [Distribution](../DISTRIBUTION.md), through remote asset readback and the
  published-release verification workflow.
- Include built-in blank Office templates and the committed folder-access,
  creation, favorite-identity and image-preview fixes since v0.6.4.
- The user explicitly authorized formal publication and routine QA-app access
  prompts. Preserve the standard signing, notarization, stapling and appcast gates.

## Selected context

- [Distribution contract](../../specs/domains/distribution.md),
  [Presentation](../../specs/domains/presentation.md),
  [HARNESS](../../specs/HARNESS.md), [release procedure](../DISTRIBUTION.md).
- Feature evidence: [Office templates](2026-10-03-built-in-office-templates.md),
  [folder access](2026-10-03-issue-6-open-with-folder-access.md), and the
  2026-09-30 review-fix section of [acceptance](../ACCEPTANCE.md).
- Version source: `project.yml`; bilingual release body: `docs/RELEASE_NOTES.md`.

## Decisions and progress

- Live latest release is v0.6.4, published 2026-09-30; downloaded appcast reports
  build 23. Remote main is `85535ff`; local main additionally contains `f30425f`.
  No v0.6.5 remote tag or local release outputs exist at preparation time.
- Use 0.6.5/build 24. Existing Office presets are appended disabled on upgrade.
- Standard publication does not repeat UpgradeQA or replace the installed app.
  Preserve native limitations rather than reporting old fixtures as acceptance
  of the final signed DMG. Verify Office resources inside the final mounted DMG.
- Resume an interrupted notarization only with its saved submission and source
  record. Keep final release files immutable once created.

## Evidence

Preparation base: `f30425f`, clean main; macOS 27.2, arm64.
Logs and prior feed: `build/release-0.6.5/`.

| Check | Status | Evidence |
| --- | --- | --- |
| Version/build vs live stable | passed | v0.6.4/build 23 downloaded from GitHub; next version 0.6.5/build 24. |
| Feature verification | passed before release preparation | Office task includes 191 Core tests, 14 image tests, native panel and WPS checks; other feature evidence remains tied to its tested source. |
| Source generation and website | passed | `make project`, metadata/successor/context checks, `git diff --check` and bilingual site build; log at `build/release-0.6.5/site-build.log`. |
| `make release-local` | not-run | Pending clean tagged release source. |
| Final signed DMG Office resources | not-run | Pending candidate. |
| `make publish-local` | not-run | Pending validated candidate; includes three-asset byte comparison and GitHub verification. |
| Installed Finder, Microsoft Office, minimum macOS | not-run | Not represented by isolated UI, WPS or build evidence. |

## Handoff

- Continue through `make release-local` and `make publish-local`; inspect retained
  state before retrying a failure. Do not weaken or skip a failed release gate.
- Record the release commit, notarization ID, final DMG/feed hashes, asset URLs
  and completed verification workflow in the final evidence.
