# Task: FileMint 0.6.7 stable release

Status: in-progress
Next action: Commit and tag the verified preparation, then complete release-local and publish-local.

## Objective and scope

- The owner requested a formal build and publication on 2026-10-08.
- Publish 0.6.7/build 26 from the primary main checkout, including the committed
  template workflows and review fixes after v0.6.6.
- Follow the standard signed, notarized, stapled release procedure through
  downloaded asset comparisons and published-release verification.
- Preserve existing installed applications, real preferences and old release assets.
  Exhaustive native QA and installed-app replacement are outside this request.

## Selected context

- [Distribution contract](../../specs/domains/distribution.md),
  [procedure](../DISTRIBUTION.md), [HARNESS](../../specs/HARNESS.md),
  [AI Playbook](../AI_PLAYBOOK.md), [Presentation](../../specs/domains/presentation.md).
- Feature claims: [Templates](../../specs/domains/templates.md),
  [Creation](../../specs/domains/creation.md),
  [Startup](../../specs/domains/startup.md), [Updates](../../specs/domains/updates.md).
- Applicable native scheduling check: [Update verification](../../specs/verification/updates.md).
- Prior feature evidence remains tied to its source in the
  [template workflow task](2026-10-05-template-workflow.md) and
  [acceptance record](../ACCEPTANCE.md).

## Decisions and progress

- Live stable v0.6.6 was published 2026-10-03; its downloaded appcast reports
  build 25. Live main and the clean local checkout both point to `322b6df`.
  Its [source CI](https://github.com/FileMintApp/FileMint/actions/runs/37734827266) passed.
- Use the next patch version 0.6.7/build 26, set only in `project.yml`.
  Generate the Xcode project normally and retain bilingual release notes.
- Update README release highlights and remove the shipped features from future
  public roadmap lists. Their remaining native acceptance stays recorded separately.
- Run the production-model native regression for modal update-check deferral.
  The fixture uses temporary settings, injected metadata and accelerated timers;
  it does not prove network discovery or signed installation.
- Standard release does not repeat UpgradeQA. Resume retained notarization
  submissions only when their source record matches this release tag and commit.

## Evidence

Preparation base: `322b6dfed4f857d13a8703149e15a3270c653092`, clean main.
Environment: macOS 27.2 arm64, Xcode 27.0 (27A266a); use the Makefile's explicit
`DEVELOPER_DIR` because global xcode-select points to CommandLineTools.
Logs and prior feed: `build/release-0.6.7/`.

| Check | Status | Evidence |
| --- | --- | --- |
| Live version/build/source | passed | v0.6.6/build 25 downloaded; live main equals the clean preparation base. |
| Metadata, generation and site build | passed | `make project`, metadata/successor checks, `make verify-context` and `git diff --check` passed. `SITE_BASE=/FileMint/ pnpm run site:build` passed; `build/release-0.6.7/site-build.log`. |
| Native automatic-check deferral | passed | Current production-model fixture built and passed copied compound-suffix output plus native sheet/modal deferral, single resumption, disable, manual check and cancellation; `native-build.log` and `native.log` under the evidence directory. |
| `make release-local` | not-run | Pending clean tagged source and formal artifact verification. |
| `make publish-local` | not-run | Pending exact candidate and remote asset/workflow checks. |
| Exhaustive installed/native acceptance | not-run | Installed Finder, macOS 13, managed devices, complete keyboard/VoiceOver/appearance coverage and public-feed installation are not established. Office providers were unavailable in earlier isolated checks; installed VS Code failed strict signature validation. |

## Handoff

- Complete the standard release stages; preserve candidate manifests and retained
  notarization state if any stage fails.
- Record commit/tag, notarization ID, final DMG and appcast hashes, remote asset
  readback and workflow URLs after publication.
