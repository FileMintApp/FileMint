# Batch rename P0.5: local-storage classification feasibility

Date: 2026-10-14. Parent: [batch rename task](../2026-10-14-batch-rename.md).

Status: historical evidence; classification prerequisite withdrawn by the user's
2026-10-14 scope decision. The current task supports ordinary local files and
folders without proof of unmanaged storage. This report is not an implementation
gate; its observations, probe source and raw JSON are retained unchanged.

## Historical conclusion

**At the time of this investigation: P0.5 = incomplete / gate not passed.**

已完成公开 API / 本机 SDK 核对，以及隔离普通本地文件、目录的原生元数据探针。当时候选接口未建立旧契约要求的“跨 provider 正向非受管”判据；本地 APFS 能力可读，不等于完成整个批量重命名的安全验收。

这不能证明 macOS 上不存在可行方案，也不能把受管样本缺失记为通过。实验没有访问、创建或下载云盘测试项，没有采用路径黑名单、空结果或错误码证明非受管。随后用户取消了分类前置要求；旧 gate 不再阻塞普通本地文件和文件夹的实现规划，实际身份、授权、不覆盖和恢复要求保留。

## Environment and scope

| Item | Observed / boundary |
| --- | --- |
| Checkout | Primary checkout; baseline `46da9813aa9878104f9d8a946400e35dbad95e19`; pre-existing P0 documents remain uncommitted |
| Runtime | macOS 27.2, build `26B5101f`, arm64 |
| SDK / compiler | CLT SDK 27.0; Apple clang 21.0.0 (`clang-2100.3.34.2`) |
| Probe | One-shot Objective-C CLI; Foundation / FileProvider plus public Darwin metadata calls; no product code or project registration |
| Execution | First in Codex command sandbox, then the same binary/fixtures in command-scoped approved host execution to distinguish service-access errors |
| App Sandbox | CLI has no App Sandbox entitlement; `codesign -d --entitlements :-` emitted no entitlement payload. Neither run proves signed FileMint sandbox behavior |
| Fixtures | Newly created 0700 `/private/tmp/filemint-p05-vac0phgo`; empty 0600 `ordinary-file`, empty 0700 `ordinary-directory`, own `symlink-control`, absent `missing-control` |
| Source / outputs | [Exact probe source](2026-10-14-batch-rename-p05-probe.md); [both raw observations](2026-10-14-batch-rename-p05-observations.json) |

本地构建 / 原始输出保存在 ignored `.local/batch-rename-p0.5/20261014-1m82zchp/`。探针只查上述固定 fixture；源码没有文件内容读取、目录枚举、改名、删除或用户配置写入。未注册 GUI QA app，未修改生产 entitlement、观察范围或隐私授权。编译使用 `-mmacosx-version-min=13.0` 仅证明当前 SDK 可构建该部署目标，不证明 macOS 13 运行行为。

## Public API assessment

The SDK root is `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/`.
Framework header paths below are under its `System/Library/Frameworks/` directory;
`usr/` paths are relative to the SDK root.

| Candidate | Public evidence / availability | Classification limit |
| --- | --- | --- |
| `NSURLIsUbiquitousItemKey` | [Apple property documentation](https://developer.apple.com/documentation/foundation/urlresourcekey/isubiquitousitemkey); current DocC description concerns iCloud. `Foundation.framework/Headers/NSURL.h:661–662` uses broader cloud wording; macOS 10.7+ | No established equivalence across arbitrary providers / supported OS versions. A missing value is not false; false is not sufficient proof of an unmanaged location |
| `NSURLUbiquitousItemIsExcludedFromSyncKey` | [Apple documentation](https://developer.apple.com/documentation/foundation/urlresourcekey/ubiquitousitemisexcludedfromsynckey); `NSURL.h:690–691`, macOS 11.3+ | Excluded local items cease being ubiquitous; synchronization status and location management cannot be assumed equivalent |
| `getFileProviderServicesForItem` | [Apple documentation](https://developer.apple.com/documentation/foundation/filemanager/getfileproviderservicesforitem%28at%3Acompletionhandler%3A%29); `NSFileManager.h:980–987`, macOS 10.13+ | Queries custom services. A successful dictionary may contain zero services; neither an empty dictionary nor an error is an unmanaged predicate |
| `getIdentifierForUserVisibleFile` | [Apple documentation](https://developer.apple.com/documentation/fileprovider/nsfileprovidermanager/getidentifierforuservisiblefile%28at%3Acompletionhandler%3A%29); `FileProvider.framework/Headers/NSFileProviderManager.h:131–138`, macOS 11+ | Limited to caller's own provider/domain. No-such-file also covers outside-own-provider / identifier not assigned. FileMint has no such provider identity |
| `SF_DATALESS` | [Apple XNU public header](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/stat.h); local `usr/include/sys/stat.h:359` | Tests dataless state, not whether a downloaded item remains managed. First OS availability was not established here |
| `ATTR_CMNEXT_EXT_FLAGS` / `EF_IS_SYNC_ROOT` | Same public header; `stat.h:366–374`, `attr.h:566`; local `getattrlist.2:1317–1319` | Sync-root flag is documented for iCloud roots and is never set on regular files. A zero bit on an item/parent is not a cross-provider negative guarantee; returned-attribute support must also be checked |
| Local/APFS, case sensitivity, persistent IDs, exclusive rename | `NSURL.h:555–556,569–570,595–598,619–620`; `statfs` | Describe filesystem capability, not provider ownership. Probe uses `statfs` for APFS; `NSURLVolumeTypeNameKey` is only macOS 13.3+ |
| `NSURLFileProviderDomainIdentifierKey` or equivalent generic URL key | Checked current public Foundation/CoreFoundation headers, Swift interfaces and [Apple key index](https://developer.apple.com/documentation/foundation/urlresourcekey) | No supported generic URL-to-any-provider membership declaration found in this review. Do not invent a key from a string or claim universal API impossibility |

Product entitlement inspection: [app](../../../Config/FileMint.entitlements), [Finder](../../../Config/FileMintFinderSync.entitlements). Existing grants cover sandbox, app-scope bookmarks, user-selected access and the private FileMint directory; they do not give FileMint an arbitrary-provider identity. This was static inspection, not a signed-app authorization test.

## Probe safety and raw results

[Apple TN3150](https://developer.apple.com/documentation/technotes/tn3150-getting-ready-for-data-less-files) explains that metadata calls can materialize intermediate dataless directories. Before creating any probe URL or metadata query, the CLI set process-scoped `IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES` to `OFF`; a failure would skip all sample probes. Both runs observed `set_rc=0`, policy `1` (OFF), then `policy_restore_rc=0` restoring original policy `2`. This establishes policy setup in this process, not a real placeholder no-download test or a system-wide trace. Future dataless tests must treat refusal / `EDEADLK` as unknown, never retry by enabling materialization.

The two valid local samples gave the same values except for own-provider lookup:

| Observation | Ordinary file / directory |
| --- | --- |
| `statfs` | `apfs`, local=1, readonly=0 |
| Foundation volume keys | local=true, readOnly=false, caseSensitive=false, exclusiveRenaming=true, persistentIDs=true |
| `lstat` | Correct file/directory kinds, flags=0, dataless=0 |
| Extended flags | `getattrlist` success, requested returned bit present, flags=0, syncRoot=0 |
| Ubiquitous / downloading / excluded-from-sync values | Getter success with **null**, no NSError; these are unavailable values, not false or unmanaged |
| Custom services, both runs | No dictionary; `NSFileProviderInternalErrorDomain`, code `0`. This is a query error, **not a successful empty service list** |
| Own-provider lookup, command sandbox | No item/domain; `NSCocoaErrorDomain`, code `4099` |
| Own-provider lookup, host run | No item/domain; `NSCocoaErrorDomain`, code `4` (no such file). Known fixture still exists; this result cannot be used as filesystem absence or unmanaged proof |
| Before/after comparison | Device/inode/size/flags unchanged for both valid samples; no content hash or complete-directory comparison was performed |

`missing-control` returned `ENOENT` from `lstat`; `symlink-control` returned symlink kind. Both stopped before Foundation/provider queries. This is diagnostic control flow, not product validation coverage. Both run stderr files were empty. Source labels `metadata_only`, `app_sandbox_entitlement` and `unmanaged_classification` are not dynamically measured facts; in particular, `unknown` is an explicit evidence label, not an implemented classifier under test.

## Evidence matrix and missing coverage

| Scenario | Status | Meaning |
| --- | --- | --- |
| Ordinary local APFS file + directory, current OS | observed | Raw metadata / errors collected; sufficient positive unmanaged predicate **not established** |
| Missing input + symlink controls | observed | Rejected by the diagnostic probe before provider lookup |
| Process-level no-materialization policy | observed | OFF setup/readback/restoration succeeded; no actual placeholder fixture was tested |
| iCloud downloaded file / directory and placeholder | not-run | User deferred dedicated cloud fixtures; Finder sidebar entry is not an input sample |
| Third-party provider downloaded file / directory, empty services, placeholder | not-run | No explicit fixtures supplied; no provider/domain discovery performed |
| Managed Desktop/Documents and external APFS provider domain | not-run | No fixtures supplied; known roots alone are not a proof |
| NAS / non-APFS volume | not-run | User deferred; outside initial support, no conclusion from local APFS |
| macOS 13 and API-version boundaries | not-run | Only current runtime available; deployment target is not runtime coverage |
| Signed FileMint sandbox with exact-parent grant | not-run | No GUI/signed-app fixture created; host CLI results do not validate this boundary |
| Batch rename / exclusive syscall / recovery / UI | not-run | Outside P0.5; capability keys do not prove the later execution machinery |

The former gate was incomplete because both the classification predicate and its
native contrast matrix were missing. These observations do not prove unmanaged
storage. The user subsequently withdrew that requirement; the current task does
not depend on filling this matrix. The missing runtime observations remain missing,
and ordinary local operations still require their own implementation verification.

## Finder Sync distinction

用户提出 NAS / iCloud 可能受 Finder Sync 规范限制。本次核对 [Apple Finder Sync guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html) 和 [Apple DTS 的目录限制说明](https://developer.apple.com/forums/thread/756711)：官方确认目录控制竞争、嵌套及部分目录的限制；本次未找到 NAS / iCloud 的统一禁止契约。同帖 iCloud 的具体失败报告来自普通开发者，不能升级为所有系统版本的保证。

Finder 菜单入口 / 回调可用性与主 App 的授权、必要操作检查是不同证据。未出现菜单或看到了 iCloud 侧栏入口，都不能作为 unmanaged 分类依据。该实验没有运行 Finder 回调验收；普通本地入口仍需随实现验证，其他环境不构成额外前置要求。

## Reproducibility and integrity

The raw JSON contains fixture labels and metadata/error codes, no user content or user paths. The exact source and observations are preserved alongside this report; the executable and original outputs remain local ignored artifacts. Re-running requires fresh owned fixtures and does not authorize cloud access.

| Local artifact | SHA-256 |
| --- | --- |
| `probe.m` | `8747fa4021a439acf18ecb78fefbd5dcc1a4a09c07cc0d44d6cbcce30d10d414` |
| `probe` | `418c51c8c182dbe4fa8d2d2941aee0909479468cade9e05dfb861dbfb976f6e4` |
| `probe-sandbox.json` | `57098096fb5f8e43ff5b97301675d952254f8cf01201dfae3392ddd2f3e84ed5` |
| `probe-host.json` | `ed099d3d4700be255d277a7b90667044fe84436229365f25e58766e55965985c` |

Observed checks: CLI compilation passed; both diagnostic runs completed; no product build, Swift/Harness suite, installation, publication, or P1–P5 implementation was run.
