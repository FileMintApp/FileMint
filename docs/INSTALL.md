# 安装 / Installation

FileMint 0.4 支持 macOS 13+，兼容 Apple 芯片与 Intel。请从
[FileMintApp/FileMint Releases](https://github.com/FileMintApp/FileMint/releases/latest)
下载 DMG，而不是第三方重新打包的文件。

## 首次启动

1. 打开 DMG，把 FileMint 拖入“应用程序”，再从“应用程序”打开。
2. 当前版本没有 Apple Developer ID 签名和 Apple 公证。如果系统阻止启动，
   确认来源后，在“系统设置 → 隐私与安全性”中找到 FileMint 的阻止记录，
   选择“仍要打开”，再确认。不要全局关闭 Gatekeeper。
3. 应用中的“新建文件…”可以独立使用。选择一个文件夹，输入名称和后缀，
   按需粘贴内容，再创建。

系统策略或组织管理的 Mac 可能不允许打开未公证应用。如果没有“仍要打开”
选项，请遵守设备策略。此版本不能承诺在所有设备上免拦截启动。

## 启用 Finder 右键入口

- 在 FileMint 中点击“打开扩展设置”。
- macOS 15 及更新版本：通用 → 登录项与扩展 → Finder，打开 FileMint。
- 较旧版本：隐私与安全性 → 扩展 → Finder 扩展。
- 在 FileMint 的“文件夹”中选择常用位置并允许访问。默认菜单范围为桌面、
  文稿和下载；也可以添加项目文件夹。文件夹访问授权会保留。
- 在该文件夹的空白处右键。如果启用后尚未刷新，可自行重新启动 Finder。

未公证的 Finder 扩展是否被加载由 macOS 决定。若扩展没有出现，先确认应用
位于“应用程序”、已手动允许启动。应用内的新建功能仍可使用。请在反馈中
附上 macOS 版本、处理器类型、安装方式和具体错误，勿附带私人文件内容。

## 验证下载来源（可选）

同一 Release 中下载 DMG 和 `.sha256` 文件，在下载目录执行：

```sh
shasum -a 256 -c FileMint-0.4.0.dmg.sha256
gh attestation verify FileMint-0.4.0.dmg --repo FileMintApp/FileMint
```

校验和证明文件完整性；GitHub attestation 证明构建来自该仓库的 Actions。
二者都不等同于 Apple 开发者身份认证或恶意软件审查。

## 登录启动、菜单栏与完全磁盘访问

安装到“应用程序”并首次启动后，FileMint 会请求注册为 macOS 原生登录项。
“通用”中的“开机自动启动”和“显示在菜单栏”默认开启，关闭后会保存选择。
若 macOS 要求确认或拒绝登录项，应用会显示真实状态并提供设置入口。开发构建
和 DMG 内的副本不会自动注册为登录项。隐藏菜单栏后仍可从应用程序打开；打开
设置时会显示在 Dock，关闭设置后会回到后台工具状态。

需要确认完全磁盘访问时，在“文件夹”页点击“在系统设置中确认…”，在
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

Drag FileMint from the DMG into Applications. This release uses ad-hoc bundle
signatures and GitHub build provenance; it is **not Apple notarized**. If blocked,
review System Settings → Privacy & Security → Open Anyway for this specific app.
Do not disable Gatekeeper globally. Managed devices may prohibit this build.

Enable FileMint under General → Login Items & Extensions → Finder on macOS 15+,
or Privacy & Security → Extensions on older systems. Authorize your working
folders in FileMint. Finder extension loading remains subject to macOS policy.
The app's New File… action works independently of Finder integration.

In Folders, use “Check in System Settings…” to confirm Full Disk Access. An
enabled FileMint switch means permission is granted; quit and reopen after
enabling it, without adding the app again. FileMint cannot automatically read
this switch, so the guide remaining visible does not mean access is denied.
The folder list describes saved folder access separately from Full Disk Access.

Use the checksum and `gh attestation verify` commands above to verify the download.
## 应用内更新 / Updating from FileMint

打开 **关于 → 检查更新 → 下载更新**。安装包校验并打开后，退出 FileMint，
将新版拖入“应用程序”替换旧版，再重新打开。可随时取消下载并重试；
检查和下载都需要主动操作。macOS 可能需要再次确认应用或启用 Finder 扩展。

Open **About / 关于 → Check for Updates / 检查更新**. A new stable version offers
**Download Update / 下载更新** and its release notes. FileMint checks the installer
size and SHA-256 before opening it. After it opens, quit FileMint, drag the new app
into Applications to replace the existing app, then reopen FileMint. macOS may
ask you to approve the app or Finder extension again. Existing installation
requirements in this guide still apply.

Update checks and downloads are manual. A failed check is shown as an error;
it does not mean your version is current. Check or download again, or use the
release-page link if GitHub is unavailable. A verified installer can be reopened
from About during the same session. Opening it does not replace the running app.
