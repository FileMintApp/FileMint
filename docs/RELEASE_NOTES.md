FileMint 0.5.1 — 修复更新后无法打开 / Fix downloaded updates that cannot open

从 0.3.0–0.5.0 升级的用户，本次请通过浏览器下载此页面的 DMG；旧版内置下载器
尚不包含本修复。退出旧版后替换到“应用程序”，推出安装磁盘，再重新打开。

- 修复应用内更新下载到沙盒缓存后，安装的应用被系统禁止运行的问题。下载前
  通过系统保存窗口确认位置，校验通过后才原子保存到该位置。
- 保留正常的互联网隔离检查，发现沙盒禁止执行标记时拒绝打开安装包；无需关闭
  App Sandbox 或 Gatekeeper，也不清除隔离属性。
- 取消下载保留原有目标文件，保存后每次打开安装包都会重新校验，防止文件被修改
  后仍按已验证版本打开。新增真实沙盒更新回归工具。
- 保留 Finder 连续创建、设置窗口专属 Dock 行为，以及临时打包副本自动清理。

When upgrading from 0.3.0–0.5.0, download this DMG using a browser first. The old
in-app downloader does not yet contain the fix. Quit, replace the app in
Applications, eject the installer volume, then reopen the installed app.

Updates now use the system save dialog and atomically save verified bytes to the
authorized location. Internet quarantine remains enabled; sandbox execution
blocks prevent opening. Cancellation preserves an existing destination, saved
installers are revalidated before opening, and a real sandbox regression harness
covers the download path. Finder and packaging cleanup fixes remain included.

升级仍需手动完成应用替换；下载并打开安装包不代表安装完成。
Updates still require manual app replacement; downloading and opening the DMG
does not complete installation. macOS 13+, Apple silicon and Intel.

**来源认证 / Provenance:** GitHub Actions builds the universal DMG and publishes
GitHub artifact attestations plus SHA-256 checksums. This release uses ad-hoc
bundle signatures, **no Apple Developer ID signature and no Apple notarization**.
macOS may require explicit first-launch and Finder extension approval.
[安装指引 / Installation](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md).

**许可 / License:** 个人及非商业使用免费；商业使用须获事先书面授权或单独签发的
付费商业许可。Personal and non-commercial use is free; commercial use requires
separate written authorization or a paid commercial license. Donations do not
grant commercial rights. [License](https://github.com/FileMintApp/FileMint/blob/main/LICENSE).

```sh
shasum -a 256 -c FileMint-0.5.1.dmg.sha256
gh attestation verify FileMint-0.5.1.dmg --repo FileMintApp/FileMint
```
