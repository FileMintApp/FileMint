# Task: FileMint 0.6.5 release and 0.6.6 compatibility follow-up

Status: in-progress
Next action: Build the clean tagged 0.6.6 source, wait for its source CI after the validated candidate push, then run publish-local.

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
- The existing FileMint Keychain profile initially returned an unavailable-item
  error. After the user requested an access retry, the same profile succeeded;
  no credential replacement or private-key export was needed.
- v0.6.5 was signed, notarized, stapled and published successfully. Its remote
  artifact verification and website deployment passed, but source CI failed two
  Office resource tests on the native SwiftPM engine. The failure was reproduced
  locally: the resource bundle is a sibling of `.xctest`, while the process main
  bundle belongs to `swiftpm-testing-helper`.
- The compatibility fix adds a relative sibling candidate only for `.xctest`
  hosts. A regression test verifies both the native layout and that `.app`/
  `.appex` hosts never use external sibling bundles. Preserve v0.6.5's bytes and
  tag; deliver the correction as 0.6.6/build 25.
- After local 0.6.6 artifact validation, push its source/tag and require source
  CI success before `make publish-local` creates the Release. The normal publish
  stage still revalidates the manifest, reads back all three assets and waits for
  the published-release check.

## Evidence

Preparation base: `f30425f`, clean main; macOS 27.2, arm64.
Logs and prior feed: `build/release-0.6.5/`.

| Check | Status | Evidence |
| --- | --- | --- |
| Version/build vs live stable | passed | v0.6.4/build 23 downloaded from GitHub; next version 0.6.5/build 24. |
| Feature verification | passed before release preparation | Office task includes 191 Core tests, 14 image tests, native panel and WPS checks; other feature evidence remains tied to its tested source. |
| Source generation and website | passed | `make project`, metadata/successor/context checks, `git diff --check` and bilingual site build; log at `build/release-0.6.5/site-build.log`. |
| 0.6.5 `make release-local` | passed | `c55fa7e`; notarization `89507ebe-0a25-44dc-843f-ca0b94a98438` Accepted; signing, staple, mounted app and appcast verified. |
| 0.6.5 final signed DMG Office resources | passed | Both host bundles contain exact source bytes; `build/release-0.6.5/final-office-resources.json`. |
| 0.6.5 `make publish-local` | passed | Three assets matched byte for byte; [published-release verification](https://github.com/FileMintApp/FileMint/actions/runs/37100776418) passed. |
| 0.6.5 source CI | failed | [CI](https://github.com/FileMintApp/FileMint/actions/runs/37100768405): two `builtInUnavailable` failures among 205 tests. Same failure reproduced locally with `--build-system native`; not an absent DMG resource. |
| 0.6.6 focused native SwiftPM regression | passed | Six Office tests pass, including the host-boundary regression; `build/release-0.6.6/native-fix.log`. |
| 0.6.6 complete checks | passed | Native SwiftPM: 206 tests in 24 suites; default `make verify`: 192 Core, 14 image tests, Harness/CLI and offline release checks. Site build also passed. Logs under `build/release-0.6.6/`. |
| 0.6.6 formal release | not-run | Pending corrected clean tagged source and candidate. |
| Installed Finder, Microsoft Office, minimum macOS | not-run | Not represented by isolated UI, WPS or build evidence. |

## Handoff

- Continue through `make release-local` and `make publish-local`; inspect retained
  state before retrying a failure. Do not weaken or skip a failed release gate.
- Record the release commit, notarization ID, final DMG/feed hashes, asset URLs
  and completed verification workflow in the final evidence.
