# FileMint 0.8.0 release

Status: in-progress
Next action: Commit and tag the reviewed 0.8.0/build 29 source, then run the standard local release and draft-first publication commands.

## Objective and scope

- Publish FileMint 0.8.0/build 29 from the primary main checkout after the user's 2026-10-20 request to build and publish a new version.
- Ship the implemented batch rename and file information/checksum tools, with matching bilingual release notes and usage guidance.
- Require local verification, Developer ID signing, accepted notarization, stapled DMG/app tickets, both signed feeds, exact source CI and draft-candidate verification before stable Latest promotion; deploy the verified website afterward.

## Selected context

- Contracts: [Distribution](../../specs/domains/distribution.md), [File tools](../../specs/domains/file-tools.md), [Presentation](../../specs/domains/presentation.md).
- Procedure: [Distribution](../DISTRIBUTION.md), [HARNESS](../../specs/HARNESS.md), [AI Playbook](../AI_PLAYBOOK.md).
- Feature evidence: [Batch rename workspace](2026-10-16-batch-rename-design.md), [File information/checksums](2026-10-19-file-info-checksums.md). Existing evidence remains tied to its original revisions and environments.

## Decisions and progress

- Live GitHub preflight confirmed Latest v0.7.0 and main `587dd0e960f5986b456f62e7cba4b685eed78b01`, matching the clean primary checkout.
- Authenticated release listing and remote tag lookup found no v0.8.0 candidate. The public v0.7.0 appcast confirms the successor version/build check passes.
- Choose 0.8.0/build 29 for the added file-tool capabilities. Keep older tags/assets immutable and preserve the existing Sparkle key and signing/authorization configuration.
- Both new child tools remain default off. Batch rename documents its local writable APFS scope; checksum guidance distinguishes integrity values from encryption or proof of origin.
- Follow the current policy omitting local downloads/comparisons of uploaded release archives. Read the previous stable appcast only for version/build preflight.
- Homebrew synchronization remains subject to the existing explicit opt-in; this task uses the standard publication command.

## Evidence

Tested commit: pending release-preparation commit/tag.
Environment: arm64 macOS 27.2 (26B5101f), Xcode 27.1 (27A9275).
Local logs and metadata: `build/release-0.8.0.noindex/`, `build/FileMint-0.8.0.release.json`, `build/FileMint-0.8.0.publication.json`.

| Check | Status | Evidence |
| --- | --- | --- |
| Latest and source preflight | passed | Public v0.7.0; matching local/remote main, clean checkout before preparation. |
| Release metadata, context and website build | passed | `make verify-context`: 22 documents / 139 local links; metadata 0.8.0/build 29; task links and `git diff --check`; `make project`; `SITE_BASE=/FileMint/ pnpm run site:build`, [log](../../build/release-0.8.0.noindex/site-build.log). |
| Local release and artifact validation | not-run | `make release-local`. |
| Draft, source CI and candidate checks | not-run | `make publish-local`. |
| Public Latest and website deployment | not-run | Complete only after bound pre-publication checks pass. |
| Installed release, minimum-OS and provider acceptance | not-run | Standard publication does not install/launch the production app or repeat exhaustive native QA. Existing feature acceptance does not prove the final release's full runtime matrix. |
| Local remote-archive byte/hash comparison | not-run | Omitted by current policy; GitHub owns independent remote candidate validation. |

## Handoff

- Preserve final archives, manifests and publication journal. Resume failed stages against their original clean tagged source.
- No new encryption feature is shipped; the separate sealed research remains untouched.
- Installed Finder/UI, macOS 13/14, provider/NAS behavior and actual installed-update acceptance require their own runtime evidence.
