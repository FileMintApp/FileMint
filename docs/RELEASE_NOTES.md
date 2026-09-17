FileMint 0.5.4 — 自动检查更新与公开规划 / Automatic updates and public roadmap

本次发布包含自动检查更新、Finder 扩展启用指引，以及中英文主页和官网的未来 TODO。TODO 中尚未勾选的功能仍是未来计划，不属于本版已实现功能。

This release adds automatic update checks, clearer Finder extension guidance and a bilingual public roadmap. Unchecked roadmap items remain future plans and are not included features.

## 更新内容 / What's new

- “通用”新增默认开启的自动检查更新开关。应用运行时每 7 天最多检查一次；首次到期检查在启动或开启开关至少 60 秒后进行。
- 检查尝试时间持久保存，失败、重启及反复切换开关不会立即触发重复请求。关闭后仍可手动检查更新。
- 发现新版后在设置与菜单栏中提示，不弹出窗口、不自动下载；下载和安装继续由用户主动完成。
- 完善 Finder 扩展启用说明：macOS 管理扩展加载及启用状态，应用提供真实状态与系统设置入口。
- 中英文 README 与官网首页新增 15 项按场景分组的未来 TODO，并提供实施路线；官网直接复用 README 清单。

- General now offers automatic update checks, enabled by default. While the app runs, checks happen at most once every seven days, with a minimum 60-second delay after startup or enabling the switch.
- Check attempts persist across failures, relaunches and preference changes. Manual checks remain available when automatic checks are disabled.
- Available updates appear in settings and the menu bar without opening a window or starting a download. Downloading and installation remain explicit user actions.
- Finder extension guidance explains system-managed enablement and provides the actual status and the system settings entry point.
- Both READMEs and website homepages include 15 future TODOs grouped by use case, with implementation notes. The website reuses the README checklists.

## 安装包 / Installer

0.5.4（构建 12）由开发者本机为主应用、Finder 扩展及 DMG 进行 Developer ID 签名；安装包通过 Apple 公证并附加票据后发布。随包提供 SHA-256 校验文件。不宣称 GitHub Actions 构建来源认证。

Version 0.5.4 (build 12) is built locally, with Developer ID signatures for the app, Finder extension and DMG. Publication follows Apple notarization and ticket stapling. A SHA-256 checksum accompanies the download. This release does not claim GitHub Actions build provenance.

macOS 13+，Apple 芯片与 Intel 通用。退出旧版，将 FileMint 拖入“应用程序”替换，推出安装磁盘，再从“应用程序”打开。Finder 扩展仍需在系统设置中启用，文件夹访问仍需授权。从 0.3.0–0.5.0 升级时，请用浏览器下载新版 DMG，以避开旧版下载器的沙盒问题。

For macOS 13+, Apple silicon and Intel. Quit FileMint, drag the new copy into Applications, eject the installer volume, then reopen FileMint from Applications. Enable the Finder extension in System Settings and authorize working folders as needed. When upgrading from 0.3.0–0.5.0, download this DMG using a browser. Opening the installer does not complete installation.

[安装指引 / Installation](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md) · [未来规划 / Roadmap](https://github.com/FileMintApp/FileMint#未来规划) · [官网 / Website](https://filemintapp.github.io/FileMint/)

## 许可 / License

个人及非商业使用免费；商业使用须获事先书面授权或单独签发的付费商业许可。打赏不授予商业权利。

Personal and non-commercial use is free; commercial use requires separate written authorization or a paid commercial license. Donations do not grant commercial rights. [License](https://github.com/FileMintApp/FileMint/blob/main/LICENSE).

```sh
shasum -a 256 -c FileMint-0.5.4.dmg.sha256
```
