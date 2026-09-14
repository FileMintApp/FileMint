FileMint 0.5.3 — 桌面右键与签名公证 / Desktop menus and notarized distribution

- 修复桌面和文稿目录不显示“新建文件”的问题：补齐 Finder 对受保护目录的
  观察注册，同时保留已配置文件夹的菜单范围。未配置的目录不会出现 FileMint 菜单。
- 默认支持系统动态识别的用户主目录及子目录，旧版默认目录配置会自动补齐。
  不按用户名或 Finder 显示名称匹配，保留自定义范围及后续移除操作。
- 新建操作使用菜单打开时的确切目录，缺失目标时不会猜测桌面；目录元数据
  不可读时，不会把空白处右键的新文件误放到上一级。
- “关于”与中英文 README 新增特别感谢：
  [阿逼（@bibinocode）](https://github.com/bibinocode)，感谢为 FileMint 的
  Developer ID 签名与 Apple 公证提供帮助。
- 首次采用本地 Developer ID 签名与 Apple 公证分发。主应用、Finder 扩展和
  DMG 均有签名；安装包附带 Apple 公证票据和 SHA-256 校验文件。

Desktop and Documents menus now receive Finder callbacks through an observation
ancestor while menu and creation scope remains limited to configured folders.
The default scope also includes the OS-resolved user home, with migration of
old default-folder settings and preservation of saved removals. Missing targets
are never guessed, and background menus retain their exact
container even when directory metadata is unavailable. About and both READMEs
thank [阿逼 (@bibinocode)](https://github.com/bibinocode) for signing and notarization help.

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
shasum -a 256 -c FileMint-0.5.3.dmg.sha256
```
