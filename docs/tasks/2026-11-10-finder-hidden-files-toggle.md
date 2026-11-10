# Finder hidden-file display toggle

Status: the user confirmed the installed Debug toggles Finder display after a relaunch
Next action: Verify the updated prompt on the next requested Debug installation.

## Scope

- Replace per-item hidden-attribute changes with Finder's Command-Shift-Period
  command in both background and item context menus. Reuse the existing saved
  switch, menu placement and icon.
- Keep the permission check and prompt in the main app. Route a single-use
  request from the extension and target only the running system Finder's PID.
- [File-tools contract](../../specs/domains/file-tools.md#toggle-hidden-files-in-finder),
  [Finder and permissions](../../specs/domains/finder-permissions.md),
  [Startup](../../specs/domains/startup.md), and [Presentation](../../specs/domains/presentation.md)
  cover settings, scope, input permission and public copy.

## Implementation and checks

Finder Sync exposes context menus. The display change runs through Quartz
event posting, whose separate permission appears under Accessibility in macOS.
The app checks PostEvent directly and targets Finder by PID. Apple DTS confirms
PostEvent is compatible with App Sandbox. [Apple DTS](https://developer.apple.com/forums/thread/789896)

Verified on arm64 macOS 27.2 (26B123) and Xcode 27.2 (27B52) with `c7407e0`
plus the working changes.

| Check | Observed result |
| --- | --- |
| `make verify` | 399 Core and 23 image tests passed with the offline checks. Core coverage includes menu parity, legacy switch and placement, and route-bound one-use tickets. [Log](../../build/finder-hidden-files-toggle.noindex/run.5tCIeD/verify-final.log) |
| Unsigned app build | The main app and embedded Finder extension executables were produced. [Log](../../build/finder-hidden-files-toggle.noindex/run.5tCIeD/build-final.log) |
| Signed `finder-hidden-files` | The sandbox fixture verified the full six-event shortcut and the production coordinator's scope, revocation, busy, expiry and single-use behavior. [Report](../../build/native-checks.noindex/run.feezvgef/report.json) |
| Signed `file-tools-settings` | Native settings and Finder icon checks passed before the event sequence correction. Their view, icon and Core inputs are the same. [Report](../../build/native-checks.noindex/run.sc0jajce/report.json) |
| Bilingual website | All 27 site checks passed. The rendered guide and privacy pages describe the new command and permission. [Log](../../build/finder-hidden-files-toggle.noindex/run.5tCIeD/site.log) |

## Live Finder delivery

The first probe sent only the period key pair with modifier flags and left the
display as it was. The final production sender sends Command and Shift presses,
the period key pair, and the modifier releases. The diagnostic process already
had PostEvent access. It ran the production sender while Finder was in the
background. The visible count went from three to one and back to three. Both
the dot-prefixed file and the BSD-hidden file changed visibility together.
Finder's own shortcut restored the initial one-item display. Fixture identities,
flags and content hashes matched before and after. The test window and files
were removed. [Hide log](../../build/finder-hidden-files-toggle.noindex/run.5tCIeD/live-finder-hide.log)
and [show log](../../build/finder-hidden-files-toggle.noindex/run.5tCIeD/live-finder-show.log).

The [Finder checklist](../FINDER_QA.md#file-and-folder-tools) covers the remaining
installed extension callback and FileMint's first system consent. The live
diagnostic used its own existing permission and bypassed the context-menu IPC.

## Installed Debug for acceptance

FileMint 0.8.1 (30) was built from the current worktree on macOS 27.2 with
`ENABLE_DEBUG_DYLIB=NO` and signed with the installed Developer ID identity.
The app and Finder extension matched their previous designated requirements.
After the normal quit and atomic replacement, both installed code hashes
matched the signed candidate. The app and one enabled Finder extension started
with new PIDs under `/Applications/FileMint.app`.

- [Installation record](../../build/local-debug-install.noindex/run.iqn6Y3/installation.json)
- [Previous app backup](../../build/local-debug-install.noindex/run.iqn6Y3/previous-FileMint.app.zip)

## Existing keystroke grant after relaunch

On macOS 27.2.1 (26B131), Device Control and Data Access showed FileMint enabled.
The installed Debug still displayed the old permission explanation on a Finder
menu click. Its app and extension signatures both validated against the local
0.8.1 Release archive's corresponding designated requirements, and vice versa.
After a normal quit and relaunch of the same Debug, macOS logged PostEvent
allowed for both the main app's check and WindowServer's delivery check. The
automated menu click did not show a display change. The user then confirmed that
clicking the command in Finder toggled hidden files successfully.

The app prompt and bilingual guide now name the permission pane by macOS version
and tell the user to quit and reopen FileMint once the switch is on. The prompt
continues to open the system pane and requires a fresh menu click to toggle.

- [Offline verification](../../build/hidden-file-permission-probe.noindex/verify.log) passed 399 Core tests, 23 image tests and the script checks.
- [Unsigned build](../../build/hidden-file-permission-probe.noindex/build.log) produced both arm64 executables.
- [Signed Finder fixture](../../build/native-checks.noindex/run.ho2lud83/report.json) passed the two permission labels and relaunch guidance in both languages, plus the existing shortcut and dispatch checks.
- [Website build](../../build/hidden-file-permission-probe.noindex/site.log) passed all 27 checks and rendered the updated guide and privacy pages in both languages.
