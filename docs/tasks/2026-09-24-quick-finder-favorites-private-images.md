# Task: Finder hidden items, favorite locations, and private image copies

Status: source implementation complete; installed Finder and Accessibility acceptance remains unrun. Source changes are uncommitted.
Next action: If an installed candidate is requested, test Finder callbacks and the first-use Accessibility grant with the affected native checklist before publication.

## Objective and scope

- Give users a quick, intentional way to toggle Finder's hidden-item display.
- Add an independent **常用文件（夹） / Favorite Locations** module for quickly locating many saved files and folders.
- Add **移除隐私元数据 / Remove Private Metadata** to Resource Tools as an immediate, copy-producing action.
- Preserve the current sandbox, Finder folder scope, original files, and user-controlled system permissions. This is a design task; none of these features is currently available.

## Selected context

- Contracts read: [Finder and permissions](../../specs/domains/finder-permissions.md), [file tools](../../specs/domains/file-tools.md), [resource tools](../../specs/domains/resource-tools.md), [startup and preferences](../../specs/domains/startup.md), [presentation](../../specs/domains/presentation.md).
- Current entry points: `App/FileMint/FileMintApp.swift`, `ContentView.swift`, `PreferencesModel.swift`, `ResourceToolsView.swift`, `ResourceToolsController.swift`; `FinderSyncExtension/FileMintFinderSync/FinderSync.swift`; `CorePackage/Sources/FileMintCore/ResourceTools.swift`; `CorePackage/Sources/FileMintImages/`.
- Verification contract: [HARNESS](../../specs/HARNESS.md). This design edit needs document/link inspection only. Implementation will need Core tests, an unsigned app build, affected Finder/native acceptance, and installed-app permission checks.
- Before implementation: add a dedicated Favorite Locations domain and router row; update Finder/startup/presentation/resource domain rules for the intentional behavior changes. Edit `project.yml` and run `make project` if new sources are registered there.

## 1. Quickly toggle Finder hidden items

### User flow

1. **菜单栏 FileMint → 切换 Finder 隐藏项目** is the primary one-click action. It remains available when the settings window is closed. A separate action and explanation live in **Finder 与文件夹 → Finder 显示**.
2. On the first click, check Accessibility trust and, if absent, request the macOS authorization alert using the system prompt option. The user must explicitly enable FileMint in **System Settings → Privacy & Security → Accessibility**; the alert itself does not grant access. Do not request this permission on launch. After returning from System Settings, refresh the displayed authorization status. The user then clicks the command again to perform the first toggle, avoiding a delayed surprise toggle after leaving the permission flow.
3. The app confirms that Finder is the intended target, brings Finder forward if needed, and sends the equivalent of `⌘⇧.` once. If permission is absent, Finder is unavailable, or focus changed, report failure and do not send a key to another app.
4. Label the command **切换**, not **显示** or **隐藏**. Do not display a current on/off state: the existing sandbox cannot reliably read Finder's live preference, and the user can independently use Finder's shortcut.

### Placement and boundaries

- Keep this Finder-wide action outside the selection-only File & Folder Tools group. An optional Finder context-menu entry can be considered only after the menu-bar path works in an installed build; it would appear only in FileMint's configured Finder scope.
- The menu-bar command is visible when FileMint's existing menu-bar option is on; it has no separate enable switch. Only the user's click starts the permission request. Recheck actual system trust on every click and when the app becomes active. A grant normally remains available across launches, but revocation, a system reset, or a changed installation identity can make it unavailable again; never rely on a saved `authorized` flag. If permission is declined, show the Finder shortcut `⌘⇧.` as a usable fallback. Do not silently change system permissions, watch global keys, write Finder preferences, or restart Finder.
- This path is a feasibility gate, not a proven implementation technique. Apple's Finder Sync controller exposes menus/selections/badges but no hidden-file switch. Apple's documented `AppleShowAllFiles` setting belongs to Finder, while Apple's `UserDefaults` documentation says a sandboxed app cannot modify another app's settings. A user-triggered Accessibility event needs a signed, installed test before the product promises one-click operation.

## 2. Independent Favorite Locations module

### Information architecture

- Add **常用文件（夹） / Favorite Locations** as its own sidebar page under **扩展功能**, and as its own Finder menu root, sibling to New File, File & Folder Tools, Resource Tools, and Open with App. It does not share the File & Folder Tools master switch.
- The library is usable from the settings page and menu bar regardless of Finder menus. When the Finder extension is enabled, a selected eligible file or folder in an already-configured folder gets a **main-level `加入常用文件（夹）`** action by default. A separate **在 Finder 中显示常用列表** switch (on by default) controls only the short list; turning it off does not hide the add action. The add action has its own hide switch for people who do not want that Finder entry. Neither switch changes observed Finder folders.
- Menu bar and Finder show a short list: at most **6 pinned** plus **4 recently located** items (deduplicated), then **搜索全部…**. Finder shows the short list under its own **常用文件（夹）** root when entries exist. The short menu never expands to hundreds of items. Finder exposure remains restricted to configured folders; the menu bar and app remain the path from anywhere.

### Quick add from Finder

1. Select one or several files and/or folders in Finder, right-click, and choose **加入常用文件（夹）** directly. The action is available without first opening the FileMint settings page, but only where the existing Finder extension already has configured scope. For any other location, use the app's picker or drag the item into its page; adding a favorite never silently expands the extension scope.
2. Capture the full Finder selection as an immutable snapshot, transfer it through a single-use ticket to the main app, and validate every target and required authorization. A normal add saves immediately to **未分组** without a modal form. If any selected target is invalid, report it and do not silently add a subset. Existing entries are skipped with an explicit count.
3. Show a small completion message, for example **已加入 5 项 · 2 项已存在**, with an optional **移至分组…** action for the newly added items. Grouping and renaming can also happen later in the independent settings page.

### Fast locator

`搜索全部…` opens a compact, non-restorable quick window with search focused. Search covers the saved display name, group name, and stored path text only; it never searches disk contents. Exact/prefix name matches rank before path matches. Results show native icon, name, parent path, and group, with a distinct warning for unavailable items. Arrow keys move selection, Return locates, Escape closes. Search is incremental and supports Chinese and English text.

- For a folder, **定位** opens that folder in Finder. For a file, **定位** opens its parent and selects the file. **打开文件** is an explicit secondary action; activating a favorite never runs a selected executable by default.
- Pinned items keep manual order; recent items use only successful explicit locate actions. A result appearing in both sections appears once. The library stores only a local last-used timestamp for these saved items, with a **清除最近使用记录** action.
- If a favorite is missing, on an unmounted volume, inaccessible, or replaced, the app keeps the entry and offers **重新定位…** or **移除**. It never guesses a replacement by filename or automatically mounts a volume. A saved hidden target can still be searched; if Finder cannot reveal it while hidden items are off, explain the Finder toggle rather than claiming it was shown.

### Management page for large libraries

```
常用文件（夹）                                      [添加文件或文件夹…]
[搜索名称、路径、分组…                             ] [分组 ▾] [类型 ▾]
固定  12              最近使用  8              全部  428
┌───────────────────────────────────────────────────────────────┐
│ ★ 设计稿.sketch                  工作     ~/Projects/A/…   ⋯ │
│ ☆ 资料库                         资料     ~/Documents/…    ⋯ │
│ ! 旧项目                         工作     位置不可用       ⋯ │
└───────────────────────────────────────────────────────────────┘
选中多项： [移到分组] [固定/取消固定] [移除]
```

- Support multi-selection in the native file/folder picker, drag-and-drop into this page, and adding the complete Finder selection. Duplicate targets are merged into one entry rather than producing identical shortcuts. Allow a user label and one flat group; group deletion moves members to **未分组**. Preserve recognizable file/folder icons and show the parent path to disambiguate repeated names.
- The page uses a virtualized list, not a card per item. Filters are **全部 / 文件 / 文件夹 / 不可用**, with a group picker and **固定顺序 / 最近使用 / 名称** sort. Search and filters never require directory traversal. Pinned order supports drag and keyboard move controls; batch group/pin/remove actions keep hundreds of entries manageable.
- Save targets as user-created, security-scoped bookmarks plus a stable item identity and display snapshot. Resolve and validate on activation, refresh stale bookmarks through a user picker, and refuse a same-path replacement until relinked. Do not store file contents or scan saved folders. Only the main app writes an atomic private catalog; the extension caches a lightweight, bounded menu projection and performs no file checks while constructing menus. A corrupt catalog is retained for explicit recovery; it must not change Finder scope or erase the user's main preferences.
- Design for at least 1,000 saved entries in acceptance fixtures. The Finder menu cost depends on its bounded projection, not on library length. The quick window remains keyboard usable at the 840 × 600 minimum settings size and in both languages, dark mode, VoiceOver, and Reduce Motion.

## 3. Resource Tools: Remove Private Metadata

### User flow and meaning of one click

- Add a seventh Resource Tools action, **移除隐私元数据…**, with an app card and a Finder submenu item. The card can choose multiple images from the system picker even while Finder integration is off, as existing resource actions do.
- In Finder, the menu click itself is the explicit **Run**: begin immediately, show cancellable progress and per-item results, and create sibling copies named `name-clean.ext` (then `name-clean 2.ext`, etc.). In the app, confirming the selection in the file picker begins the same job. If the sibling is not writable, ask for one output folder. Originals are never edited or overwritten.
- Copy only image data and the technical properties needed for correct display, such as orientation and color profile. Remove GPS, capture time, device/camera identifiers, MakerNote, comments, IPTC, XMP and other text metadata. Describe the action as **移除隐私元数据** because privacy data can exist outside EXIF. Filename text and private information visible in pixels remain the user's responsibility.
- The output is published only after decoding/encoding or metadata rewriting succeeds **and** a readback check finds no targeted metadata. On an unsupported format, multiple-frame image, HDR/depth/live-photo payload, changed source, or failed verification, produce no “clean” file and show the exact reason. Partial batches keep verified completed copies and report counts.

### Format and fidelity decision

- First target JPEG, PNG, TIFF and ordinary single-image HEIC, within current Resource Tools input byte and 16 MP working-pixel limits. Do not claim HEIF, GIF, BMP, RAW, WebP, PDF, animations, or multi-image HEIC support merely because other resource actions recognize their filenames.
- A local Image I/O diagnostic showed that a simple source-copy rewrite retained EXIF/GPS in some formats. Rebuild each supported image from pixels into an sRGB copy, then read back the output and reject unexpected metadata. This re-encodes the image and may change file size/color. Preserve oriented dimensions, respect the 16 MP working limit, and reject a larger input rather than downscaling it silently. HEIC output remains conditional on the system encoder and verified output.
- Do not rely on the GPS-exclusion flag alone: Apple's documentation says it does not remove proprietary MakerNote location or custom XMP location data. The privacy claim is per verified supported format, not a promise to remove information in the picture itself.
- Keep existing limits, local-only processing, exact-parent authorization, single-use Finder tickets, serialized work, cancellation, collision-safe staging, and quit/restart guard. For older saved Resource Tools choices, the new child starts off; new installs retain the master-off default and can show the child in app tools immediately.

## Acceptance and sequencing

1. **Feasibility first:** On a signed sandboxed app, confirm Accessibility consent, Finder focus safety, and one toggle per click. With sample JPEG/PNG/TIFF/HEIC files, confirm Image I/O's metadata rewrite/readback behavior, including orientation and color. A failed spike changes the supported design before any user-facing promise.
2. **Favorite Locations:** Core normalization/search/order/deduplication tests; a 1,000-entry UI fixture; bookmarked item moved/renamed/replaced, unavailable volume, corrupt catalog, bilingual keyboard and VoiceOver checks; installed Finder and menu bar paths. Confirm no folder crawl or new monitored root.
3. **Private Metadata:** Fixtures with GPS, EXIF, MakerNote, IPTC, XMP, PNG text and orientation; inspect both Image I/O properties and format-level metadata; verify original byte identity, output display, same-size pixel data where lossless copying is claimed, batch partial failure, cancellation, collisions and sandbox authorization.
4. Update the owning SPECs before implementation. After code changes, use the relevant HARNESS Core tests, `make verify`, unsigned app build and affected native Finder checks. No release or publication is part of this task.

## Evidence and references

Tested worktree: current uncommitted source on 2026-09-24.
Environment: macOS 27.2 Apple silicon; Core and unsigned Xcode checks; isolated native fixture paths under `build/`. A clickable, sample-data prototype remains in the task-scoped visualization directory. No installed app, user favorite catalog, Finder display setting or system permission was changed.

| Check | Status | Result |
| --- | --- | --- |
| `make verify` | passed | 156 Core tests, 14 image tests, 5 JSON harness cases and 10 CLI tests, plus context/release script checks. Log: `/private/tmp/filemint-verify.log`. |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | App and Finder extension compiled from generated project. Log: `/private/tmp/filemint-build-final.log`. |
| Isolated Resource Tools native fixture | passed | Seven actions completed in Chinese/light and English/dark; `removeMetadata` made two verified copies per run, originals and clipboard preserved. Native cleanup panel screenshots inspected at 820×560. Fixture: `build/resource-tools-harness.noindex/run.7KS2pf/`. |
| Isolated settings native fixture | passed | Favorite Locations page inspected at 840×600 with search, group/type filters, unavailable state and Finder switches. Quick panel arrow keys, unavailable Return, and Escape were observed. Fixture: `build/design-ui-harness.noindex/run.2eZk1G/`. |
| Signed installed Finder and Accessibility | not-run | Requires installing a candidate and user-controlled system authorization. Finder context callback and real hidden-item toggle are not inferred from fixtures. |

- [Finder Sync controller API](https://developer.apple.com/documentation/findersync/fifindersynccontroller) does not expose a hidden-file display switch.
- [Apple's documented Finder `AppleShowAllFiles` override](https://developer.apple.com/library/archive/documentation/Porting/Conceptual/PortingUnix/additionalfeatures/additionalfeatures.html) requires Finder restart; [UserDefaults sandbox rules](https://developer.apple.com/documentation/foundation/userdefaults) prevent editing an unrelated app's preferences from the sandbox.
- [Accessibility trust check](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions) is available for an explicit user grant.
- [NSWorkspace Finder reveal](https://developer.apple.com/documentation/appkit/nsworkspace/activatefileviewerselecting%28_%3A%29) selects files in Finder; [Finder sidebar favorites](https://support.apple.com/en-ng/guide/mac-help/mchl83c9e8b8/mac) confirm that links do not move originals.
- [Apple Image I/O technical note](https://developer.apple.com/library/archive/qa/qa1895/_index.html) describes metadata rewriting without recompression on JPEG/PNG/TIFF. [GPS exclusion flag](https://developer.apple.com/documentation/imageio/kcgimagemetadatashouldexcludegps) explicitly excludes proprietary MakerNote/custom XMP coverage.

## Handoff

- Remaining work: signed installed-app Finder and Accessibility acceptance if requested; no release or publication. HEIC encoding and clean output passed on this Apple silicon host, but macOS 13 and other hardware are untested.
- Files changed by this design: this task document only.
- Known limits: sandboxed Finder toggle and HEIC metadata rewrite are proposed paths, not observed runtime behavior.
