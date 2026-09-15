FileMint 0.5.3 — 桌面右键与 Developer ID 签名 / Desktop menus and Developer ID signing

**公证状态 / Notarization:** Apple 已接受这份 Developer ID 签名 DMG 的
`notarytool` 提交，当前状态为 `Accepted`。本版发布时仍为 `In Progress`，
因此公开 DMG 没有内嵌（stapled）票据；Apple 已在线发布票据，联网时
Gatekeeper 可获取它，包括此前已经下载的副本。离线首次打开仍可能受阻。
公开安装包及其 SHA-256 校验值保持不变，校验文件只证明下载字节完整。
Apple has accepted the `notarytool` submission for this Developer ID-signed DMG.
The status is now `Accepted`, although it was still `In Progress` when released.
The unchanged public DMG therefore has no embedded (stapled) ticket, but Apple
publishes the ticket online for Gatekeeper, including copies downloaded before
acceptance. A first launch offline may still be blocked. The public asset and
its SHA-256 checksum remain unchanged; the checksum verifies byte integrity only.

- 修复桌面和文稿目录不显示“新建文件”的问题：补齐 Finder 对受保护目录的
  观察注册，同时保留已配置文件夹的菜单范围。未配置的目录不会出现 FileMint 菜单。
- 默认支持系统动态识别的用户主目录及子目录，旧版默认目录配置会自动补齐。
  不按用户名或 Finder 显示名称匹配，保留自定义范围及后续移除操作。
- 新建操作使用菜单打开时的确切目录，缺失目标时不会猜测桌面；目录元数据
  不可读时，不会把空白处右键的新文件误放到上一级。
- “关于”与中英文 README 新增特别感谢：
  [阿逼（@bibinocode）](https://github.com/bibinocode)，感谢为 FileMint 的
  Developer ID 签名与 Apple 公证提供帮助。
- 首次采用本地 Developer ID 为主应用、Finder 扩展和 DMG 签名；附带 SHA-256
  校验文件。Apple 后续已接受同一份 DMG 的公证提交；公开文件仍无内嵌票据，
  资产与校验值不作替换。

Desktop and Documents menus now receive Finder callbacks through an observation
ancestor while menu and creation scope remains limited to configured folders.
The default scope also includes the OS-resolved user home, with migration of
old default-folder settings and preservation of saved removals. Missing targets
are never guessed, and background menus retain their exact
container even when directory metadata is unavailable. About and both READMEs
thank [阿逼 (@bibinocode)](https://github.com/bibinocode) for signing and notarization help.

This is the first release built locally with Developer ID signatures for the
app, Finder extension and DMG. Apple later accepted this exact DMG and made its
ticket available online; the public asset has no stapled ticket because it was
released before acceptance. The download includes a portable SHA-256 checksum.
It does not claim GitHub Actions build provenance; versions through 0.5.1 retain
their historical ad-hoc signatures.

**安装 / Installation:** macOS 13+，Apple 芯片与 Intel 通用。退出旧版，把 FileMint
拖入“应用程序”替换，推出安装磁盘，再从“应用程序”打开。Apple 已接受这份 DMG，
但文件未内嵌票据；首次打开时请保持联网，以便 Gatekeeper 获取在线票据。
Finder 扩展需要在系统设置中启用，文件夹访问仍需首次授权。
从 0.3.0–0.5.0 升级时，请用浏览器下载 DMG，以避开旧版下载器的沙盒问题。

Quit FileMint, drag the new copy into Applications, eject the installer volume,
then reopen it from Applications. Enable the Finder extension in System Settings
and authorize working folders as needed. Apple accepted this exact DMG, but the
file has no stapled ticket; keep the Mac online for the first launch so Gatekeeper
can retrieve the online ticket. When upgrading from 0.3.0–0.5.0, use a browser
to download this DMG. Opening the installer does not complete installation.
[安装指引 / Installation](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md).

**许可 / License:** 个人及非商业使用免费；商业使用须获事先书面授权或单独签发的
付费商业许可。Personal and non-commercial use is free; commercial use requires
separate written authorization or a paid commercial license. Donations do not
grant commercial rights. [License](https://github.com/FileMintApp/FileMint/blob/main/LICENSE).

```sh
shasum -a 256 -c FileMint-0.5.3.dmg.sha256
```
