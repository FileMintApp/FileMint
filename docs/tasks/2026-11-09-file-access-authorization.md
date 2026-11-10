# Task: File access authorization

Status: directory authorization matrix and guidance removal verified
Next action: User acceptance of File Access and Finder menus on the [installed Debug build](2026-11-10-finder-hidden-files-toggle.md#installed-debug-for-acceptance).

## Objective and scope

- Reuse applicable folder grants across existing file-operation entry points.
- Use the shared native authorization panel for permission fallback and explicit
  folder authorization. Preserve the separate selection and import workflows.
- Preserve scoped identities, per-feature grant stores, and mutation/rollback rules.

## Selected context

- [Authorization contract](../../specs/domains/finder-permissions.md#authorization-for-file-operations)
- [File tools](../../specs/domains/file-tools.md), [Creation](../../specs/domains/creation.md),
  [Open with App](../../specs/domains/open-with.md), and [Resource tools](../../specs/domains/resource-tools.md)
- [Verification matrix](../../specs/HARNESS.md) and [Finder checks](../../specs/verification/finder.md)

## Decisions and evidence

- Directory write authorization for the real home or user-selected locations
  belongs to File Access. Finder settings change menu locations independently.
  The existing write store and legacy Finder bookmark records are managed
  without copying them into a new store. Saved scopes are opened for operations.
- Recheck current authorization at pending move execution and keep rename
  recovery authority separate. Signed matrix probes use only isolated state and
  synthetic files. Record the macOS switch state separately from I/O results.

- Restore configured ancestor grants for the life of the operation. Reads use
  the actual result. Multi-item writes and external dispatch use a native check
  of the required access before mutation or dispatch.
- Use one native authorization panel with the target name and Authorize / 授权.
  Identity-bound renewal and recovery keep their documented checks and consent.

Tested on arm64 macOS 27.2 (26B123), Xcode 27.2 (27B52), at `5c334ee` plus the
working fix.

| Check | Status | Observed result |
| --- | --- | --- |
| `make verify` | passed | 407 Core and 23 image tests, restricted file-only reads, and offline checks. [Log](../../build/file-access-authorization.noindex/run.my9fGZ/verify.log) |
| Unsigned `make build` | passed | Final main app and Finder extension executables produced. [Log](../../build/file-access-authorization.noindex/run.my9fGZ/build-final.log) |
| Signed `file-info`, `creation-opening`, `file-visibility` | passed | Panel prompts, missing-target handling, nested copy, creation and visibility. Retained for the final build after comparing the unchanged authorization UI, reader and tested creation and visibility routes. [Initial report](../../build/native-checks.noindex/run.g1__2296/report.json) |
| Signed `open-with` | passed | Final native selection and directory delivery, private tickets and guards. [Focused report](../../build/native-checks.noindex/run.uzrhtafm/report.json) |
| Signed `batch-rename` and `resource-tools` | failed | Rename authority and recovery checks and metadata-removal output completed. Both runs stopped at window-focus assertions. [Focused report](../../build/native-checks.noindex/run.uzrhtafm/report.json) |
| External-folder grant and relaunch | blocked | The isolated app's first launch returned a LaunchServices error. Direct launch did not expose a window to Computer Use. The owned fixture stopped before granting access. |
| Local Debug installation | passed | Developer ID signed 0.8.1 (30) started from `/Applications/FileMint.app`. [Backup](../../build/file-access-authorization.noindex/run.my9fGZ/previous-FileMint.app.zip) |
| Installed Finder copy after relaunch | passed | A real Finder menu copied the exact synthetic text from a Downloads descendant using the saved ancestor grant. An in-scope Documents file with no applicable grant opened a picker naming the file with an 授权 button. Cancelling preserved the clipboard count. [Runtime record](../../build/finder-authorization.noindex/run.4b2q3N/result.json) |

## Parent choice and app-wide reuse

- The installed Finder picker named the file and its direct parent. The parent
  row could be selected with 授权 enabled. Cancelling closed the picker before a
  test grant was written. [Picker record](../../build/remembered-read-access.noindex/run.GVaQyd/live-picker.json)
- Copy and File Info remember explicit file or parent read authorization. General
  file actions consult the same read store and a separate write store. Writes use
  write grants and their own permission checks. Explicit authorizations save
  under stable app storage and remain scoped to the selected item or directory.

| Entry point | Authorization review |
| --- | --- |
| Configured folders and Finder file tools | Restored exact and ancestor grants before access. General file-tool authorization persists independently of a move, delete, hide, share or favorite request. |
| File contents, checksums and Open with App | Shared reads restore scoped file and parent grants. Open with App retains its existing app and folder records. A valid separate parent can cover a rejected narrower bookmark. |
| Batch rename and Desktop alias | Valid saved parent grants participate. Rename recovery and desktop destination records retain their operation-specific identities and scope. |
| Resource output and creation | Reuse directory write grants before requesting access. Explicit external draft authorization can be remembered; an Intent's borrowed scope remains session-owned. |
| Favorites, launcher scripts and saved application selections | Exact stored objects retain their existing bookmark and identity checks. Relinking, replacing a target and choosing a new input keep their explicit selection workflows. |
| Updating FileMint | The updater retains storage paths and existing record formats. Matching signed application identity and sandbox entitlements allow the relaunched app to resolve eligible old bookmarks. |

## Installed replacement evidence

Tested on arm64 macOS 27.2 (26B123), Xcode 27.2 (27B52), at `5c334ee` plus the
working changes. Offline verification and unsigned app/extension compilation
passed. Signed `batch-rename`, `creation-opening`, `open-with`, `file-info`,
`resource-tools` and `file-visibility` passed on the final source, including
cross-tool access and read/write separation. The earlier focus failures remain
in their original runs.

The signed local Debug app and embedded extension retained their designated
requirements and actual sandbox entitlements. After normal quit, replacement
and relaunch, the configured bookmark and five existing private store digests
matched before and after. The real Finder menu copied exact fixture text from a
Downloads descendant under its preexisting grant without a picker. The fixture
was removed. These are local replacement results. Sparkle's installed update
path requires its own runtime evidence.

- [Offline verification](../../build/authorization-continuity.noindex/run.wFPjw2/verify.log)
- [Signed fixture report](../../build/native-checks.noindex/run.xcm46k5f/report.json)
- [Installed replacement and Finder record](../../build/authorization-continuity.noindex/run.wFPjw2/result.json)

## Sparkle authorization verification

On the same arm64 macOS 27.2 host, the sandboxed UpgradeQA fixture used an
isolated state directory, Developer ID signed builds 1 and 2, and a signed ZIP
served over loopback. Its copy path compiled the production ticket, controller,
authorization picker and bookmark store. The fixture used its own Sparkle driver
and Finder extension identity. The first fixture run used inconsistent `/tmp`
spellings and stopped before granting access or updating.

| Check | Status | Observed result |
| --- | --- | --- |
| Native authorization before upgrade | passed | Confirmed the exact file in one picker and the direct parent in another. Two corresponding read-only bookmark entries were saved and both original reads copied the expected text. |
| Sparkle replacement and relaunch | passed | Sparkle downloaded the signed archive, extracted it and replaced build 1 with build 2. The same install path relaunched as PID 56320 after PID 55132 exited. The bookmark bytes matched across the update. |
| Read reuse in the upgraded process | passed | Ambient access was denied before the production reader restored its grants. Direct QA tickets copied the exact file and a nested child of the granted parent. Both clipboard results matched and the bookmark bytes stayed unchanged. |
| Post-upgrade Finder menus | blocked | The real QA Finder extension loaded build 2. Automated context-menu interactions repeatedly returned the desktop surface. No post-upgrade Finder copy command was observed. |

The QA app quit normally, the QA extension returned to disabled, and the
loopback server stopped. The synthetic files and private QA state remain for
resuming the Finder check. The installed FileMint and its extension were not
used as the fixture.

- [Runtime events with request origins](../../build/sparkle-installation-harness.noindex/run.ND1bRW/runtime-events.jsonl)
- [Verified Sparkle and direct copy results](../../build/sparkle-installation-harness.noindex/run.ND1bRW/probe-result.json)

## Directory access management and signed matrix

On arm64 macOS 27.2 (26B123), at `c7407e0` plus the local changes, the
Developer ID signed [directory fixture](../../specs/verification/native-qa.md#directory-access-matrix)
used the production picker, bookmark store/resolver and file creation service.
The System Settings row was absent before the off runs. The user enabled the
QA-only row for the on runs, and its enabled switch was observed in Settings.
All rows used a new process and synthetic files in a normal home subfolder and
in Documents. Each successful write was verified by reading its exact bytes.

| Full Disk Access | Saved home grant | Ordinary folder | Documents | Evidence |
| --- | --- | --- | --- | --- |
| Off | Absent | Read and write denied | Read and write denied | [Baseline](../../build/folder-access-harness.noindex/run.BYE3kWE7/off-none.json) |
| Off | Present | Read and write passed | Read and write passed | [Relaunch](../../build/folder-access-harness.noindex/run.BYE3kWE7/off-home-relaunch.json) |
| On | Absent | Read and write denied | Read and write denied | [Relaunch after revoke](../../build/folder-access-harness.noindex/run.BYE3kWE7/on-none.json) |
| On | Present | Read and write passed | Read and write passed | [Both enabled](../../build/folder-access-harness.noindex/run.BYE3kWE7/on-home.json) |

The saved custom parent restored access to its included child after relaunch.
The Finder policy rejected its excluded sibling. Removing the custom grant
denied reads and writes immediately and after a fresh launch with FDA off.
Removing the home grant denied reads and writes with FDA still on. After the
QA system entry was removed in Settings, a fresh process continued to deny
access. All cases retained identical Finder preference bytes. The first picker
attempt returned the wrong directory and saved no grant. The successful run
opened each picker at its intended target.
The QA-only system entry and both runs' synthetic targets were removed after
verifying the QA grant stores were empty.

- [Custom folder relaunch](../../build/folder-access-harness.noindex/run.BYE3kWE7/off-custom-relaunch.json)
- [Custom folder revoked](../../build/folder-access-harness.noindex/run.BYE3kWE7/off-custom-revoked-relaunch.json)
- [Final denial after removing QA system access](../../build/folder-access-harness.noindex/run.BYE3kWE7/off-home-revoked-final.json)
- [Offline verification](../../build/folder-access-implementation.noindex/verify.log)
- [Unsigned app and Finder extension build](../../build/folder-access-implementation.noindex/build.log)

`make verify` passed 407 Core tests, 23 image tests and the offline restricted
subprocess checks. The unsigned build produced the app and its embedded Finder
extension. The local bilingual guide build passed all 27 site checks and rendered
the new steps at the repository base path.

Signed batch rename, Open with App, file information, resource tools and file
visibility passed in the [affected run](../../build/native-checks.noindex/run.z6hq7qrt/report.json).
The settings check in that run identified a path-spelling change when making
menu locations plain URLs. The [focused rerun](../../build/native-checks.noindex/run.epd84vjj/report.json)
passed after preserving the menu path and making the authorized draft path a
plain URL. It covered creation, authorization add/remove, settings rollback,
and the bilingual search result for File Access. The final integration copy
and link were compiled with the same settings destination. The signed matrix
uses the unchanged picker, store, scope resolver and creation service.

The full Quick Search native check stopped at global registration of the
default shortcut. Carbon returned `eventHotKeyExistsErr` (`-9878`).
[Quick Search runtime log](../../build/native-checks.noindex/run.z6hq7qrt/quick-search.log)

## Installed Debug for user acceptance

The user requested a local Debug installation from the current worktree.
FileMint 0.8.1 (30) was built for arm64 with `ENABLE_DEBUG_DYLIB=NO`, signed
with the installed Developer ID team, and installed at `/Applications/FileMint.app`.
The app and Finder extension retained their designated requirements. The old
app quit normally and was archived before the atomic replacement. The first
install command stopped before replacement because a zsh variable masked the
command path. The retry used the prepared staging copy. LaunchServices briefly
discovered the swapped-out app, so its exact staging registration and bundle
were removed. One enabled Finder extension remained and its new process ran
from the installed path. The installed app opened File Access for the user.
The user will exercise the authorization controls and Finder menu actions.

- [Installation record](../../build/local-debug-install.noindex/run.G6aaiQAT/installation.json)
- [Previous app backup](../../build/local-debug-install.noindex/run.G6aaiQAT/previous-FileMint.app.zip)

## Full Disk Access guidance removal

The signed directory matrix above supports using the native folder picker as
the file access setup flow. Removed the Full Disk Access cards from General and
File Access, their System Settings shortcut, and the corresponding public
guidance. File Access is searchable by folder authorization terms in both
languages.

Tested `c7407e0` plus the working changes on arm64 macOS 27.2 (26B123) with
Xcode 27.2 (27B52).

- `make verify` passed 407 Core and 23 image tests and the offline subprocess
  checks. [Log](../../build/file-access-guide-removal.noindex/run.odiO9T/verify.log)
- The unsigned build produced the main app and embedded Finder extension
  executables. The initial run stopped at denied SwiftPM cache writes; the
  command-scoped retry passed. [Log](../../build/file-access-guide-removal.noindex/run.odiO9T/build-unsandboxed.log)
- Signed `design-ui` passed settings search, grant management and rendering.
  General showed the Finder setup card and File Access showed the directory
  list and controls in Chinese/light and English/dark. [Report](../../build/native-checks.noindex/run.rkdbqsjv/report.json)
- All 27 site checks passed. The rendered bilingual guides contained the updated
  instructions and valid install links. [Log](../../build/file-access-guide-removal.noindex/run.odiO9T/site-final.log)

The [November 10 Debug installation](2026-11-10-finder-hidden-files-toggle.md#installed-debug-for-acceptance)
includes this cleanup.
