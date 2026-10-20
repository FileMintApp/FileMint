# Task: Update summaries and online help

Status: complete
Next action: No first-phase implementation or acceptance work remains. The user
approved the reviewed changes for ordinary commit and push, without publication.

## Objective and scope

- Show the value of an available update without leaving the app, and make the
  existing online guide reachable from the app.
- In scope: future bilingual release-note format, About/sidebar summaries,
  Help/menu-bar/About guide entry points, regression coverage and affected checks.
- Out of scope: first-run checklists, offline manuals, contextual tours,
  post-upgrade announcements, read-state persistence, version bumps and publication.
- Acceptance: optional malformed notes never block a valid update; summaries
  match the offered version and current app language; guide actions open the
  fixed matching-language site; existing installer validation remains effective.

## Selected context

- Contracts: [Updates](../../specs/domains/updates.md),
  [Presentation](../../specs/domains/presentation.md),
  [Distribution](../../specs/domains/distribution.md),
  [Startup](../../specs/domains/startup.md).
- Workflow: [AI Playbook](../AI_PLAYBOOK.md).
- Entry points: `AppUpdate.swift`, `Localization.swift`, `AboutPane.swift`,
  `ContentView.swift`, `FileMintApp.swift`, `scripts/release_metadata.py`,
  `docs/RELEASE_NOTES.md` and the existing `website/guide.md` translations.
- Verification: [HARNESS](../../specs/HARNESS.md),
  [updates](../../specs/verification/updates.md),
  [native QA](../../specs/verification/native-qa.md).
- Load more context only if installer, scheduling, permissions or guide content
  must change.

## Decisions and progress

- 2026-10-20: Updated owning SPECs before implementation.
- Keep historical release records; require the new format for releases after
  0.8.0. Do not assign a new version during feature implementation.
- Extract optional summaries from the existing metadata response. Render literal
  text and keep the full release-page fallback. No new endpoint or dependency.
- Reuse the online guide and default browser for this phase.
- Available updates now precede credits in About; minimum-size screenshots
  confirmed that the summary and update actions fit together for the fixture.
- Native accessibility inspection found that combining selectable bullet
  containers hid their text. Removing the extra grouping restored both
  languages' complete summaries in the accessibility tree.
- 2026-10-20: After reviewing the installed Debug app and simulated summary,
  the user confirmed “我看过了，效果没问题” and requested all first-phase changes
  be committed and normally pushed to the existing `origin/main`, without release.

## Evidence

Tested commit/worktree: primary checkout, based on `164bb0c`; uncommitted work.
Environment: arm64 macOS 27.2, Xcode 27.1 (27A9275), Swift 6.4.
The final UI-only accessibility adjustment was followed by a fresh unsigned build
and native run; Core/release checks already passed for their final source.

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | Core 348, Images 22, Harness and all required offline suites, including 9 release metadata and 48 publication tests. [Log](../../build/update-summary-qa.noindex/verify.log). |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Release main app and embedded Finder executable exist; no installation. [Log](../../build/update-summary-qa.noindex/build.log). |
| Native scope selection | passed | Reviewed shared-file/runner changes; selected only `update-summary`. Installer, Finder delivery and scheduling behavior are unchanged. [Plan](../../build/update-summary-qa.noindex/native-plan.json). |
| `NATIVE_QA_SUITES=update-summary make verify-native-affected` | passed | Fresh signed `design-ui` fixture `run.F3puX2`, fixed QA identity, simulated release metadata and isolated preferences. Language changes, missing-note fallback, available install action and eight minimum-size captures passed. [Report](../../build/native-checks.noindex/run.rhoip_b5/report.json). |
| Native appearance review | passed | Inspected Chinese/light summary, English/dark sidebar and missing-summary views at 960 × 680. [Final Chinese preview](../../build/design-ui-harness.noindex/run.F3puX2/update-summary-review/summary-zh-Hans-about.png); version 9.9.9 is test data. |
| Production update-client metadata smoke | passed | Public 0.8.0 selects ZIP; equal-version check returns no update. Historical notes correctly yield no structured summary. No archive download or installation. [Log](../../build/update-summary-qa.noindex/metadata-smoke.log). |
| Guide URL and native interaction checks | passed | Both guide URLs returned HTTP 200 and matching-language titles. Clicked About's Chinese guide link and observed the official guide in Chrome. Native language switching updates English link/summary; sidebar action enters About; both languages' highlight text is present in AX. [Observations](../../build/update-summary-qa.noindex/interaction-evidence.md). |
| Historical release-note preservation | passed | Existing 0.8.0 and older entries are byte-for-byte unchanged after the new introductory comment. No version/build change. |
| User visual acceptance | passed | The user accepted the installed Debug help entry points and the separate simulated update-summary presentation on 2026-10-20. This does not imply a live newer-release install. |
| Installed upgrades / older macOS / full VoiceOver session | not-run | Outside this presentation change's acceptance; fixture rendering and AX inspection do not establish these outcomes. |

## Handoff

- Remaining first-phase work: none.
- Delivery scope: all first-phase source, tests, QA scripts, contracts and
  acceptance records in the primary checkout. The user authorized ordinary
  commit/push to `FileMintApp/FileMint` on `main`; ignored build, backup and
  installation artifacts are excluded. No release or website deployment is
  part of this delivery.
- The format gate applies to future releases after 0.8.0; existing public
  Release bodies are unchanged. The new app gracefully handles old-format notes.
- First-phase QA was closed normally after interactive checks. A newly built
  separate preview was subsequently opened and accepted. No production preferences,
  feature gates or folder authorization were changed by these checks.
- First-run checklists, offline manuals, contextual tours and post-upgrade
  announcements remain out of scope.

## Requested Debug installation — 2026-10-20

The user requested a local Debug build/install for visual review and explicitly
excluded publication. Debug 0.8.0 (29) was built with `ENABLE_DEBUG_DYLIB=NO`, signed
with the existing Developer ID team `8S66M2ZLD5`, and passed `verify_bundle.sh`.
After the user handled and closed their active batch-rename preview, the original
FileMint process quit normally. The signed Debug bundle was staged, verified and
atomically exchanged into `/Applications/FileMint.app`. The original bundle is
retained at `.local/update-summary-debug-install-20261020.v_8e87ve/installed-before`.
All 167 bundle entries match the signed Debug source. `verify_bundle.sh` passed
for the installed app, including sandbox, Sparkle and Finder checks. The shared
preference fingerprint was unchanged across replacement and relaunch.

Fresh main/extension processes run from `/Applications` and PluginKit lists one
enabled extension at the installed path. The installed About page shows 0.8.0 (29)
and the new online guide; the native Help menu also contains User Guide. No
permission switches or menu-bar preferences were changed. These observations
establish this local manual installation and the tested help entry points, not
an end-to-end Sparkle update or broader Finder callback acceptance.

- [Installation receipt](../../.local/update-summary-debug-install-20261020.v_8e87ve/installation.json)
- [Launch and preferences verification](../../.local/update-summary-debug-install-20261020.v_8e87ve/launch-verification.json)
- [Debug build log](../../.local/update-summary-debug-install-20261020.v_8e87ve/build-debug.log)
- [Installed bundle checks](../../.local/update-summary-debug-install-20261020.v_8e87ve/verify-installed.log)
- [Final process paths](../../.local/update-summary-debug-install-20261020.v_8e87ve/final-processes.json)

The public latest version is also 0.8.0, so a newer-version summary will not appear
naturally in the installed Debug app. A fresh, separate design-QA app has been
launched with `--updates --minimum` for the user's visual review.
Its fixture run is `run.odvV80`; its version 0.6.1 and offered 9.9.9 are test data.
It uses the production summary views with isolated preferences. Production
version comparison, update endpoints and installed app metadata remain unchanged.
The user subsequently accepted the installed help and simulated-summary visuals;
that acceptance does not establish a real online update or installation of 9.9.9.
