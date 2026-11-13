# Task: Debug installation and cross-feature acceptance

Status: in-progress
Next action: Diagnose the reproducible file-information accessibility crash, then
investigate the installed Finder hidden-files command and repeat their affected
checks. The full installed-flow acceptance remains incomplete.

## Objective and scope

Build and install the current Debug app and exercise the existing automated
and native user flows. Use disposable files and preserve the owner's app data,
saved permissions and existing Finder display state. No publication was requested.

## Selected context

- [SPEC router](../../specs/SPEC.md), [Harness](../../specs/HARNESS.md),
  [native QA](../../specs/verification/native-qa.md), and
  [Finder QA](../FINDER_QA.md).
- Observed behavior belongs to [creation](../../specs/domains/creation.md),
  [Finder and permissions](../../specs/domains/finder-permissions.md),
  [file tools](../../specs/domains/file-tools.md),
  [resource tools](../../specs/domains/resource-tools.md),
  [startup](../../specs/domains/startup.md),
  [updates](../../specs/domains/updates.md), and
  [distribution](../../specs/domains/distribution.md).

## Decisions and progress

- Built clean commit `d8e20c7b6b967d400284eca706950e9b56767347` as Debug
  with `ENABLE_DEBUG_DYLIB=NO`; `DEBUG` and `-Onone` were confirmed in the
  Debug build settings. The first sandboxed Xcode attempt could not write its
  Swift caches; the same build succeeded with the scoped execution permission.
- Signed with the existing Developer ID team `8S66M2ZLD5` and retained the
  production sandbox. Backed up and CRC-checked the old 0.8.2 (31) installation,
  atomically replaced the bundle, and verified the installed signatures,
  entitlements, arm64 binaries and matching source/installed executable hashes.
  The obsolete 0.8.1 extension registration was removed; one enabled extension
  remains under `/Applications/FileMint.app`. The app and extension were seen
  running from that path, and the `filemint` URL handler resolves there.
- The full automated native run initially rejected the certificate fingerprint
  because its identity selector requires a Developer ID name. No suite ran in
  that attempt. The subsequent run used the configured name and passed all 15
  suites; both reports are retained.
- The live session used the owned `live-fixtures` directory in the installation
  record. All seven original fixture hashes matched after the checks. The
  temporary rename receipt was absent before and after rename/undo; the moved
  fixture's destination bytes matched. Finder's original hidden-file display
  state was restored.
- The user subsequently reported that manually clicking Calculate and using the
  shortcut both work. These are user-reported observations; they do not erase
  the separate Computer Use accessibility crashes or establish their cause.

## Evidence

Tested commit/worktree: `d8e20c7b6b967d400284eca706950e9b56767347`, clean
before these acceptance-document edits. Environment: Apple silicon, macOS
27.2.1 (26B131), Xcode 27.2 (27B52), signed installed Debug 0.8.2 (31).
Paths under `build/` below are local, ignored evidence and are not in Git.

| Check | Status | Observed result / evidence |
| --- | --- | --- |
| `make verify` | passed | 425 Swift tests, five JSON Harness cases, CLI and other offline regressions passed. |
| Debug build, signing and `scripts/verify_bundle.sh` | passed | Source, staged and installed bundles verified. Local installation record and previous app backup: `build/local-debug-install.noindex/run.NDGMO3t1/`. |
| `python3 scripts/native_checks.py run --all` | passed | All 15 signed isolated suites passed, including templates, creation, rename, file information, all seven image actions, settings, updates, Open With, favorites, hotkeys, search and hidden-files dispatch. Local reports: `build/native-checks.noindex/run.1hk98dv_/report.json` and initial blocked setup `build/native-checks.noindex/run.a4uj56oj/report.json`. These fixtures do not prove installed Finder callbacks or physical keyboard delivery. |
| Installed Finder creation | passed | Three consecutive quick actions created `Untitled.txt`, `Untitled 2.txt` and `Untitled.md`; a repeated panel request preserved a draft and its Unicode/whitespace/literal token bytes matched on disk. Return on the existing-file confirmation cancelled replacement and preserved bytes. A Finder request cold-launched the installed process and displayed the target-directory panel. |
| Installed file and image actions | passed | Finder delivered image conversion to the app; it produced a 32×24 JPEG and preserved the PNG. Three selected synthetic files were renamed, read back, undone and verified against their original hashes. A file moved into the selected test destination with matching bytes. Finder's Open With action opened the selected test file in VS Code. |
| Settings and local integration routes | passed | Opened settings pages, searched for and navigated to File Access, edited and cancelled a new-template draft, opened and cancelled the Shortcuts local test draft, and previewed/cancelled the launcher draft. These do not prove real Shortcuts or Raycast execution. |
| File information accessibility | failed under Computer Use | Twice, after opening File Info for `sample.txt` from Finder and selecting Calculate, the installed app exited while Computer Use queried its accessibility hierarchy. Both macOS reports show `EXC_BAD_ACCESS`/`SIGSEGV` and thousands of recursive AppKit/SwiftUI accessibility-label frames, with `_AXXMIGCopyHierarchy` on the crashing main thread. The user subsequently reported that manually clicking Calculate works; the isolated file-info suite also passed. Local crash reports: `build/local-debug-install.noindex/run.NDGMO3t1/FileMint-2026-11-13-113201.ips` and `FileMint-2026-11-13-113909.ips` in the same directory. |
| Finder hidden-files command | failed | Three Computer Use menu selections, including after a cold restart, did not visibly toggle the dot-prefixed test file. Finder's own Command-Shift-Period did toggle it; the original hidden state was restored with that shortcut. Menu-action delivery and the cause were not independently established. The isolated dispatch/Quartz-sequence suite passed. |
| Cross-app global shortcut | passed, user-reported | The user subsequently reported that the shortcut works. During Computer Use, synthetic Control-Option-K did not visibly open search; the settings button and search/filter/navigation worked. |
| Live update check | blocked | About displayed GitHub rate limiting. A successful live discovery and any installed update/relaunch were not verified. |
| Other system boundaries | not-run | First-time directory/keystroke authorization and persisted grants in a separate unapproved scope, actual Shortcuts/Raycast, login-item lifecycle, system default-app changes, clipboard image/text in the installed app, permanent deletion/AirDrop, cloud/cross-volume behavior, VoiceOver, fullscreen/IME and macOS 13/14 were not exercised end to end. Existing owner grants and settings were not reset to manufacture a first run. |

## Handoff

- Investigate the two crashes with the retained reports and reproduce against an
  isolated signed fixture before changing accessibility presentation. Preserve
  the failure evidence even if a focused fix passes.
- Diagnose actual Finder hidden-files delivery and permission behavior without
  changing the user's grant or leaving Finder's display state altered.
- Repeat only affected automated/native checks after any fix. Complete the
  outstanding installed/system scenarios in suitable environments before
  describing full-flow acceptance as passed.
