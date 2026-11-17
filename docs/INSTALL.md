# 安装 / Installation

[中文官网安装步骤](https://filemintapp.github.io/FileMint/install.html) · [English installation steps](https://filemintapp.github.io/FileMint/en/install.html)

当前正式版支持 macOS 13.0 及以上的 M 系列 Mac。快捷指令与启动器单独要求 macOS 13.3 及以上。请从 [GitHub Releases](https://github.com/FileMintApp/FileMint/releases/latest) 下载 DMG，或按官网说明通过官方 Homebrew tap 全新安装。Finder 菜单的显示范围在「Finder 与文件夹」设置，保存的目录读写授权在「文件访问」管理。

Current stable installers support M-series Macs on macOS 13.0 or later. Shortcuts and launcher integration requires macOS 13.3 or later. Download the DMG from [GitHub Releases](https://github.com/FileMintApp/FileMint/releases/latest), or follow the website instructions for a fresh installation from the official Homebrew tap. Use **Finder & Folders** for menu locations and **File Access** to manage saved read and write grants.

## 验证下载来源（可选）

从同一 Release 下载 DMG 和对应的 `.sha256` 文件，在下载目录运行以下命令，把 VERSION 换成安装包版本。

Download the DMG and its `.sha256` file from the same release. Run this command in the download directory, replacing VERSION with the installer version:

```sh
shasum -a 256 -c FileMint-VERSION.dmg.sha256
```

SHA-256 检查下载完整性。Developer ID 签名、Apple 在线公证票据、安装包内嵌票据和 GitHub 构建认证各有不同用途。GitHub Actions 构建认证只适用于 0.5.1 及更早的对应资产，不适用于从 0.5.3 起在本机构建的版本。

SHA-256 checks download integrity. Developer ID signatures, online and stapled Apple notarization tickets, and GitHub build attestations serve different purposes. GitHub Actions build attestations apply only to the corresponding assets through 0.5.1, never to locally built releases from 0.5.3 onward.

## 旧版本兼容性 / Legacy compatibility

- **Intel Mac**：自 0.6.0 起不再支持 Intel。0.5.10 及更早的已发布安装包保留各自原有的兼容范围。
- **0.5.3**：DMG 使用 Developer ID 签名，发布时 Apple 仍在处理公证。Apple 后续接受了同一个 DMG 的提交；联网时 Gatekeeper 可以获取在线票据。公开文件未更换，也未附加票据，因此离线首次打开可能失败。参见[当时的公证记录](ACCEPTANCE.md#053-notarization-accepted-after-publication-2026-09-15)。
- **0.5.1 及更早**：没有 Developer ID 签名或 Apple 公证。若系统阻止启动，确认来源后可在「系统设置 → 隐私与安全性」为这个 App 选择「仍要打开」。请遵守受管理设备的策略。

- **Intel Macs:** Intel support ended in 0.6.0. Published installers through 0.5.10 keep their original compatibility.
- **0.5.3:** The DMG was Developer ID signed and published while Apple notarization was pending. Apple later accepted that exact DMG; Gatekeeper can retrieve the ticket online. The published file remains unchanged and has no stapled ticket, so a first launch offline may fail. See the [notarization record](ACCEPTANCE.md#053-notarization-accepted-after-publication-2026-09-15).
- **0.5.1 and earlier:** These installers have no Developer ID signature or Apple notarization. If macOS blocks the app, verify its source and look for **Open Anyway** for this app under **System Settings → Privacy & Security**. Follow any managed-device policy.

## 应用内更新 / Updating from FileMint

现行的检查与安装步骤见上方官网。若从以下旧版本升级：

- **0.5.7 / 0.5.8**：旧版更新器签名权限有误，须手动安装 0.5.9 或更新版本一次。
- **0.5.1–0.5.4**：旧更新器的「关于 → 检查更新 → 下载更新」会让你选择保存位置，校验后打开 DMG。取消保存不会开始下载。可从「关于」重新打开已经验证的 DMG，随后手动替换应用。
- **0.3.0–0.5.0**：用浏览器从 GitHub 下载新的 DMG。旧版应用内下载包可能带有沙盒禁止执行标记，重复拷贝同一个安装包无法修复。无需删除偏好设置。

手动替换时，先退出 FileMint，将新版拖入「应用程序」，推出安装磁盘后重新打开。更新可能需要管理员授权；macOS 也可能要求重新启用扩展或授权目录。

For current update steps, see the website above. When upgrading from an older version:

- **0.5.7 / 0.5.8:** A signing entitlement prevents those updaters from installing the fix. Manually install 0.5.9 or later once.
- **0.5.1–0.5.4:** In the legacy updater, choose **About → Check for Updates → Download Update** and confirm a save location. The app checks the DMG before opening it. Cancelling the save dialog starts no download. You can reopen a verified DMG from About and replace the app manually.
- **0.3.0–0.5.0:** Download a fresh DMG from GitHub in a browser. The old in-app downloader could mark a DMG as blocked by the sandbox. Recopying that download does not fix it. Keep your preferences.

To replace the app manually, quit FileMint, drag the new copy into Applications, eject the installer volume and reopen FileMint. macOS may ask for administrator authorization or ask you to approve the extension or folder access again.

## 旧开发版设置 / Settings from development builds

FileMint 不会自动访问早期开发版的 App Group 容器。可用「文件 → 导入设置…」从旧 JSON 或偏好 plist 恢复设置；旧目录权限可能需要重新授权。

FileMint does not automatically read the early development builds' App Group container. Use **File → Import Settings…** to restore settings from an old JSON or preferences plist. You may need to grant access to those folders again.
