# 安装 / Installation

已发布的 0.5.10 安装包支持 macOS 13+、Apple 芯片与 Intel。后续正式版仅支持
macOS 13+ 的 M 系列 Mac；旧版安装包的兼容范围不变。请从
[FileMintApp/FileMint Releases](https://github.com/FileMintApp/FileMint/releases/latest)
下载 DMG，而不是第三方重新打包的文件。

## 首次启动

1. 打开 DMG，把 FileMint 拖入“应用程序”，推出“FileMint”安装磁盘，再从“应用程序”打开。
2. 0.5.9 及后续正式版使用 Developer ID 签名，已通过 Apple 公证并附加（stapled）票据。
   如果下载的是旧版 0.5.3：它在 Apple 公证仍在处理时提前发布，因此公开 DMG 没有内嵌票据。
   Apple 后续已接受这份原始 DMG 的公证提交；联网时 Gatekeeper 可获取 Apple 在线发布的票据，离线首次打开仍可能受阻。
   SHA-256 只校验下载字节，不代表安装包内嵌票据。0.5.3 之后的正式版须先完成并附加公证票据再发布。
   0.5.1 及更早版本没有 Apple Developer ID 签名和 Apple 公证。如果旧版被系统阻止启动，
   确认来源后，在“系统设置 → 隐私与安全性”中找到 FileMint 的阻止记录，
   选择“仍要打开”，再确认。不要全局关闭 Gatekeeper。
3. 应用中的“新建文件…”可以独立使用。选择一个文件夹，输入名称和后缀，
   按需粘贴内容，再创建。

系统策略或组织管理的 Mac 仍可能不允许打开从 GitHub 下载的应用。首次打开 0.5.3 时请保持联网，
以便 Gatekeeper 获取在线票据；如果设备策略仍然阻止，请遵守设备策略。后续版本的 Apple 公证
不代替 Finder 扩展启用和文件夹访问授权。

## 启用 Finder 右键入口

- 在 FileMint 中点击“打开扩展设置”。
- macOS 15 及更新版本：通用 → 登录项与扩展 → Finder，打开 FileMint。
- 较旧版本：隐私与安全性 → 扩展 → Finder 扩展。
- 在 FileMint 的“Finder 与文件夹”中选择常用位置并允许访问。默认菜单范围包含系统识别的当前用户主目录及其子目录；
  桌面、文稿和下载也保留为单独的授权条目。可以添加其他位置，文件夹访问授权会保留。
- 在桌面背景或该文件夹的空白处右键。如果启用后尚未刷新，可自行重新启动 Finder。

Finder 扩展是否被加载由 macOS 决定。若扩展没有出现，先确认应用
位于“应用程序”、已手动允许启动并在系统设置中启用扩展。应用内的新建功能仍可使用。请在反馈中
附上 macOS 版本、处理器类型、安装方式和具体错误，勿附带私人文件内容。

## 文件（夹）工具

“文件（夹）工具”默认关闭。打开“设置 → 扩展功能 → 文件（夹）工具”后，可分别开启拷贝文件（夹）名称、拷贝文件（夹）路径、移动文件（夹）、彻底删除和隔空投送。每项还可选择显示在 Finder 一级菜单，或收进“文件（夹）工具”子菜单；同一项不会重复显示。新建文件菜单不受这些选择影响。

- 只在已授权范围内选中一个或多个本地项目后，Finder 右键菜单才会显示已启用的工具；它们可按设置显示在一级或二级菜单，不会嵌入或改变新建菜单。
- 名称保留后缀，路径使用完整本地路径；多选时按 Finder 的选择顺序一项一行。只有点按拷贝菜单项才会写入剪贴板。
- “移动文件（夹）”先保存源项目，不会立即移动。到目标文件夹空白处右键，选择“将所选项目移到此处”才会执行；此操作也能独立选择菜单层级。
- 选择新的源项目会替换上一批待移动项目；成功前待移动项目会在重新启动 FileMint 后保留。同名目标、已变化的源项目、原文件夹或自身子目录都会被拒绝，不会覆盖或合并。
- “彻底删除”默认要求二次确认，确认后直接删除所选项目，不经过废纸篓。可在设置中明确改为“直接静默删除”；此选项只跳过 FileMint 的确认框，不跳过 macOS 的文件夹授权。删除符号链接时只删除链接本身，不删除目标。
- “隔空投送”默认关闭。启用后点击菜单项会打开 macOS 原生隔空投送界面，由你选择接收设备；取消、不可用或发送失败不会改为其他分享方式。

## 验证下载来源（可选）

同一 Release 中下载 DMG 和 `.sha256` 文件，在下载目录执行（将 VERSION
替换为下载的版本号）：

```sh
shasum -a 256 -c FileMint-VERSION.dmg.sha256
```

校验和用于检查下载完整性。0.5.1 及更早版本另有 GitHub Actions
构建认证；0.5.3 起本机构建的版本没有该认证。0.5.3 使用 Developer ID 签名，
发布时尚未取得公证结果，之后 Apple 已接受同一份 DMG；公开文件没有内嵌票据。
SHA-256、Developer ID 签名、在线公证票据和内嵌票据是不同的验证。

## 登录启动、菜单栏与完全磁盘访问

安装到“应用程序”并首次启动后，FileMint 会请求注册为 macOS 原生登录项。
“通用”中的“开机自动启动”和“显示在菜单栏”默认开启，关闭后会保存选择。
若 macOS 要求确认或拒绝登录项，应用会显示真实状态并提供设置入口。开发构建
和 DMG 内的副本不会自动注册为登录项。隐藏菜单栏后仍可从应用程序打开；打开
设置时会显示在 Dock，关闭设置后会回到后台工具状态。

需要确认完全磁盘访问时，在“Finder 与文件夹”页点击“在系统设置中确认…”，在
系统设置 → 隐私与安全性 → 完全磁盘访问权限中添加 `/Applications/FileMint.app`
并开启，随后退出并重新打开 FileMint。此权限由你在 macOS 中选择，应用不会代为启用。
如果 FileMint 的开关已经开启，就表示已授予权限，无需重复添加或授权。
FileMint 无法自动读取此系统开关，因此应用内的说明会保留；说明仍然显示不代表
授权失败或尚未授权，实际状态以系统设置为准。
完全磁盘访问和 App Sandbox 授权是独立机制；文件夹可能仍需首次选择授权，
FileMint 会用书签记住它，而不是每次创建都重新选择。下方“已保存此文件夹的授权”
仅说明此文件夹的授权记录已保存，不表示完全磁盘访问状态，也不保证任何位置都可写入。

## 旧开发版设置

此版本使用 FileMint 自己的配置目录，不会自动访问旧 App Group 容器。旧文件
保留不动。如需恢复，使用应用“文件 → 导入设置…”选择旧 JSON 配置或偏好 plist；
旧目录权限可能需要重新授权。

## English

Drag FileMint from the DMG into Applications, eject the FileMint installer volume,
then open FileMint from Applications. Stable releases from 0.5.9 onward are Developer ID signed,
Apple notarized and stapled. The older version 0.5.3 is Developer ID signed and
was published while Apple notarization was in progress, without a stapled ticket.
Apple later accepted that exact DMG submission and published its ticket online.
Gatekeeper can retrieve the ticket while connected, including for copies downloaded
before acceptance; a first launch offline may still be blocked. Later stable
releases require notarization and stapling before publication.
Versions through 0.5.1 use
ad-hoc signatures and are **not Apple notarized**. If one of those versions is blocked,
review System Settings → Privacy & Security → Open Anyway for this specific app.
Do not disable Gatekeeper globally. Managed devices may prohibit this build.

Enable FileMint under General → Login Items & Extensions → Finder on macOS 15+,
or Privacy & Security → Extensions on older systems. Authorize your working
folders in FileMint. Finder extension loading remains subject to macOS policy.
The app's New File… action works independently of Finder integration.

### File & Folder Tools

File & Folder Tools is disabled by default. Open Settings → Extensions → File & Folder Tools to enable Copy Names, Copy Paths, Move File / Folder, Delete Permanently and AirDrop independently. Each action can appear in Finder's main menu or in the File & Folder Tools submenu, never both. These choices do not alter New File.

- Enabled tools appear only after you select one or more local items inside an authorized scope. Their configured main-menu or submenu position never changes or nests inside the creation menu.
- Names retain suffixes, paths are complete local paths, and multi-selection is copied one Finder-order item per line. The clipboard is written only after an explicit Copy action.
- Move File / Folder captures source items without moving them. Right-click the target folder background, then choose Move Selected Items Here to complete the operation; that target action has its own placement choice.
- A new source selection replaces the previous batch; unfinished items survive a FileMint relaunch. Existing names, changed sources, the current folder and a folder's own descendant are all rejected without overwrite or merge.
- Delete Permanently asks for confirmation by default, then bypasses Trash. You can explicitly choose Delete silently; this skips only FileMint's dialog, never folder authorization. A symbolic link is removed without touching its target.
- AirDrop starts disabled. When enabled, it opens macOS's native AirDrop UI so you choose a recipient. Cancelling, an unavailable service or a sending failure never falls back to another sharing service.

In Finder & Folders, use “Check in System Settings…” to confirm Full Disk Access. An
enabled FileMint switch means permission is granted; quit and reopen after
enabling it, without adding the app again. FileMint cannot automatically read
this switch, so the guide remaining visible does not mean access is denied.
The folder list describes saved folder access separately from Full Disk Access.

Use the checksum command above to verify the download. GitHub build attestations
apply to published versions through 0.5.1, not to locally built releases from 0.5.3.
## 应用内更新 / Updating from FileMint

0.5.9 修复了更新器的签名权限。已确认 0.5.7/0.5.8 的“更新并重启”会受此问题影响，
旧版本请手动安装一次 0.5.9：退出 FileMint，将新版拖入“应用程序”替换，推出磁盘后重新打开。
安装修复版后，可用“更新并重启”获取后续版本。请先完成创建或编辑；macOS 可能要求管理员授权。

Version 0.5.9 fixes the updater's signed permissions. Versions 0.5.7/0.5.8 are confirmed
affected. Manually install 0.5.9 once: quit FileMint, replace it in Applications,
eject the installer and reopen it. Use Update and Restart for later releases.
Finish creation/editing first; macOS may request administrator authorization.

从 0.3.0–0.5.0 升级时，本次请用浏览器从 GitHub Release 下载新版 DMG。旧版
内置下载器可能让安装包带上沙盒禁止执行标记，出现“应用程序无法打开”；仅重复
拷贝同一个旧下载包无法修复该标记。重新下载并替换即可，无需删除偏好设置。

使用旧更新器的版本（0.5.1–0.5.4），打开 **关于 → 检查更新 → 下载更新**，在系统保存窗口中确认安装包
位置。取消保存窗口不会开始下载。安装包校验并打开后，退出 FileMint，
将新版拖入“应用程序”替换旧版，推出“FileMint”安装磁盘，再从“应用程序”重新打开。
可随时取消下载并重试；
下载和安装需要主动操作。macOS 可能需要再次确认应用或启用 Finder 扩展。

“通用 → 自动检查更新”默认开启。应用运行时每 7 天最多检查一次，首次到期检查
在启动或开启开关至少一分钟后进行；检查失败也会保留间隔，重启不会立即重试。
发现新版本后可在设置顶部或菜单栏菜单查看。关闭后仍可手动检查，不会自动下载。

For this upgrade from versions 0.3.0–0.5.0, download the new DMG using a browser.
Their old in-app downloader can add a sandbox execution block; recopying that
same download does not repair it. Download afresh and replace the app without
deleting your preferences.

For legacy updater builds (0.5.1–0.5.4), open **About / 关于 → Check for Updates / 检查更新**. A new stable version offers
**Download Update / 下载更新** and its release notes. Confirm the destination in
the system save dialog. FileMint checks the installer
size and SHA-256 before opening it. After it opens, quit FileMint, drag the new app
into Applications to replace the existing app, eject the FileMint installer
volume, then reopen FileMint from Applications. macOS may
ask you to approve the app or Finder extension again. Existing installation
requirements in this guide still apply.

General → Automatically check for updates defaults on. While the app runs, it
checks at most once every seven days, with at least a one-minute delay after
startup or enabling the switch. Attempt times persist even on failure. New
versions appear in settings and the menu bar menu without opening a window.
Manual checks work with the switch off; downloads require an explicit user action.
A failed check is shown in About as an error;
it does not mean your version is current. Check or download again, or use the
release-page link if GitHub is unavailable. Legacy clients can reopen their verified DMG from About; opening that DMG alone does not install it.
