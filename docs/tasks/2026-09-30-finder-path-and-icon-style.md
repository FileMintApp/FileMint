# Task: Finder background paths and global menu icon style

Status: implemented; the checks below apply to the September 30 worktree.
Next action: If these paths change, select the relevant installed Finder menu checks from [Finder QA](../FINDER_QA.md).

## Objective and scope

- Implement issue #1: Copy Paths from an in-scope Finder background, using the
  captured current directory and existing tool preferences.
- Diagnose issue #2's menu-scope and permission distinction from current code.
- Check issue #3 and add the user-requested global Colored / System Monochrome
  option, preserving existing icon customization.
- No change to menu scope or authorization, installed apps, or publication.

## Selected context

- [File tools](../../specs/domains/file-tools.md),
  [Finder permissions](../../specs/domains/finder-permissions.md),
  [Presentation](../../specs/domains/presentation.md),
  [Startup preferences](../../specs/domains/startup.md).
- Core: `FileTools`, `FileMenuAction`, `MenuIcons`, `Preferences`.
- Native: `FinderSync`, `FileToolAppearance`, settings and icon previews.
- Checks: [HARNESS](../../specs/HARNESS.md),
  [Core](../../specs/verification/core.md),
  [Finder/native](../../specs/verification/finder.md).

## Decisions and progress

- Background Copy Paths captures a directory separately from item selections,
  ignores stale selection and rechecks current switches and scope on click.
- Issue #2 reflects explicit monitored-folder scope; Full Disk Access does not
  register new Finder observation roots or replace sandbox bookmarks.
- Existing icons use palette rendering. The user chose a global style switch in
  General's Appearance group; app icons retain their original artwork.
- Monochrome uses AppKit symbol configuration and template images, including
  the existing F silhouette. No new icon assets or dependencies.
- Both implementations are complete. The global picker is under General →
  Appearance; icon previews follow it, with color controls disabled in monochrome.
- Isolated native QA verified light/dark previews, symbol editing in monochrome,
  disabled/enabled color wells and unchanged saved colors on return to Colored.

## Evidence

Tested worktree: `main` at `0409f1a` plus these uncommitted changes.
Environment: macOS 27.2, Apple silicon, Xcode, macOS 13 deployment target.
Logs/readback: `build/qa-2026-09-30-issues.DTad4B/` (ignored local evidence).

| Check / command | Status | Observed result |
| --- | --- | --- |
| Final `make verify` | passed | 178 Core tests, 14 image tests, Harness 5/5, 10 CLI regressions and remaining offline checks; `verify.log`. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | Main app and Finder extension; `build.log`. |
| `bash scripts/build_file_tools_settings_harness.sh`, fixture `--verify-icons` | passed | 22 slots and 14 templates in both styles, with custom and fallback symbols; `icon-rendering-checks.json`. |
| Isolated native settings UI | passed | CUA observed light/dark monochrome previews, disabled color wells, editable symbols, bilingual style options and restoring `folder.fill` / `#00C8B3` / `#0088FF` in Colored; `native-ui.txt`, `icon-state-colored.json`. |
| `git diff --check` | passed | No whitespace errors. |
| Installed Finder menus | not-run | Current installed app has not been replaced. |

## Handoff

- Remaining work: installed Finder acceptance only; implementation and automated
  checks are complete. No issue comment, installation or release was made.
- Native limits: installed Finder callbacks, background clipboard flow and
  actual highlighted Finder menu colors remain unverified. The
  isolated fixture's AppKit raster/flag checks and settings previews are separate
  evidence from those installed-app scenarios.
