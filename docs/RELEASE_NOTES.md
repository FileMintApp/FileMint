FileMint 0.5.2 — 桌面右键与签名公证 / Desktop menus and notarized distribution

- 修复桌面背景右键没有“新建文件”的目标解析问题：空白处菜单保留 Finder
  提供的目录；未提供目标时，仅在桌面仍位于配置范围内才回退到真实桌面。
  普通文件夹、文件、侧边栏与工具栏不会因该回退误用桌面。
- “关于”与中英文 README 新增特别感谢：
  [阿逼（@bibinocode）](https://github.com/bibinocode)，感谢为 FileMint 的
  Developer ID 签名与 Apple 公证提供帮助。
- 首次采用本地 Developer ID 签名与 Apple 公证分发。主应用、Finder 扩展和
  DMG 均有签名；安装包附带 Apple 公证票据和 SHA-256 校验文件。

Desktop background menus now preserve Finder's container destination and use the
real Desktop for a missing background target only while Desktop is configured.
Known folder targets stay unchanged; targetless item, sidebar and toolbar menus
do not fall back to Desktop. About and both READMEs thank
[阿逼 (@bibinocode)](https://github.com/bibinocode) for signing and notarization help.

This is the first release built locally with Developer ID signatures for the
app, Finder extension and DMG, and a stapled Apple notarization ticket. The
download includes a portable SHA-256 checksum. It does not claim GitHub Actions
build provenance; versions through 0.5.1 retain their historical ad-hoc signatures.

**安装 / Installation:** macOS 13+，Apple 芯片与 Intel 通用。退出旧版，把 FileMint
拖入“应用程序”替换，推出安装磁盘，再从“应用程序”打开。首次启动仍可能出现
正常的来源确认；Finder 扩展需要在系统设置中启用，文件夹访问仍需首次授权。
从 0.3.0–0.5.0 升级时，请用浏览器下载 DMG，以避开旧版下载器的沙盒问题。

Quit FileMint, drag the new copy into Applications, eject the installer volume,
then reopen it from Applications. Enable the Finder extension in System Settings
and authorize working folders as needed. When upgrading from 0.3.0–0.5.0, use a
browser to download this DMG. Opening the installer does not complete installation.
[安装指引 / Installation](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md).

**许可 / License:** 个人及非商业使用免费；商业使用须获事先书面授权或单独签发的
付费商业许可。Personal and non-commercial use is free; commercial use requires
separate written authorization or a paid commercial license. Donations do not
grant commercial rights. [License](https://github.com/FileMintApp/FileMint/blob/main/LICENSE).

```sh
shasum -a 256 -c FileMint-0.5.2.dmg.sha256
```
