# Task: File access authorization

Status: verified for local replacement and Sparkle bookmark restoration
Next action: Verify both post-Sparkle actions through the visible Finder menu.

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
