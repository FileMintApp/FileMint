# Task: M-series arm64 distribution

Status: complete
Next action: review this source change; choose a new version and build when release preparation is requested.

## Objective and scope

- User-visible outcome: future FileMint releases support M-series Macs running macOS 13 or later and open the modern Full Disk Access settings link.
- In scope: arm64-only build and package, Intel update exclusion, macOS 13 deployment target, privacy-settings link, release gates and current-source copy.
- Out of scope: rewriting historical release records, replacing an installed app, notarizing or publishing a release.
- Acceptance criteria: packaged executables contain only arm64; the appcast requires arm64 and macOS 13; the button uses the macOS 13+ Settings link; copy distinguishes future releases from published 0.5.10.

## Selected context

- Domain contracts: [distribution](../../specs/domains/distribution.md), [updates](../../specs/domains/updates.md), [Finder and permissions](../../specs/domains/finder-permissions.md), [presentation](../../specs/domains/presentation.md).
- Implementation entry points: `project.yml`, `App/FileMint/PreferencesModel.swift`, `scripts/sign_app.sh`, `scripts/verify_bundle.sh`, `scripts/update_appcast.py`, README/website/install/development documentation.
- Verification: [HARNESS](../../specs/HARNESS.md) distribution, app, update and website rows; [update checks](../../specs/verification/updates.md); [distribution procedure](../DISTRIBUTION.md).
- Load additional context when: changes reach Finder extension behavior, source file authorization or the updater lifecycle.

## Decisions and progress

- The user clarified that “latest link” means the newer Full Disk Access Settings URL, documented for macOS 13 and later in Apple's EndpointSecurity SDK header. It does not imply macOS 27.
- Future releases retain macOS 13 as the minimum and compile only arm64. Previously published universal releases keep their original support and bytes.
- The pinned Sparkle parser supports an `arm64` hardware requirement. The new appcast includes it, so older Intel clients cannot install an unlaunchable package even if GitHub discovery shows a newer release.
- Xcode embeds a universal Sparkle framework. Packaging removes Intel slices from its five executables before signing; bundle verification rejects extra slices and checks the app and extension deployment target against `project.yml`.
- The new settings URL is opened by the existing user-triggered button with a general System Settings fallback. Opening Settings never counts as granted permission.
- M-series is the support policy. Arm64 alone can also launch on A-series Apple silicon; no chip-name-based runtime block was added.
- The earlier macOS 27 assumption and its test results are superseded by this correction.
- The macOS 27.2 host could not launch System Settings through Launch Services, including the older URL and the application bundle itself. This blocks a native pane-navigation claim on this host; the new URL still matches the installed Apple SDK header.

## Evidence

Tested commit/worktree: uncommitted working tree, corrected macOS 13 arm64 source
Environment: macOS 27.2, arm64, Xcode 27.0

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make project` | passed | Generated project has `ARCHS = arm64` and `MACOSX_DEPLOYMENT_TARGET = 13.0`. |
| `make verify` | passed | 148 Core tests, 5 Harness cases, 10 CLI tests, 4 appcast tests and other release/context checks; `/private/tmp/filemint-macos13-arm64-verify.log`. |
| Unsigned `make build` | passed | Main app and Finder extension are arm64; both report `LSMinimumSystemVersion = 13.0`; `/private/tmp/filemint-macos13-arm64-build.log`. |
| Ad-hoc `make package` | passed | Sparkle driver, entitlement, arm64-only and DMG integrity checks; `/private/tmp/filemint-macos13-arm64-package.log`. |
| Mounted temporary DMG and checksum | passed | The read-only mounted app passed `verify_bundle.sh`; checksum passed. The test DMG was removed after QA. |
| `SITE_BASE=/FileMint/ pnpm run site:build` | passed | Bilingual website rendered; `/private/tmp/filemint-macos13-arm64-site.log`. |
| Shell syntax and `git diff --check` | passed | Changed scripts parse and no whitespace errors. |
| Open privacy pane on current host | blocked | Both old/new URLs and a direct System Settings launch failed in host Launch Services before the pane could open. |
| CI, installed Finder and public update | not-run | Require a committed release candidate and native acceptance. |

## Handoff

- Remaining work: none for this source change; release preparation remains a separate task.
- Files currently changed: domain contracts, project configuration, App settings URL, build/signing/appcast scripts, distribution/development guidance and bilingual copy.
- Known limitations / native checks still needed: no macOS 13 runtime, installed Finder, working Settings navigation on this host, Developer ID artifact, notarization or published update in this source task.
- Next action and the minimum context required: review the corrected source and use the linked distribution procedure when release preparation is requested; do not reuse the superseded macOS 27 results.
