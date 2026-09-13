FileMint 0.5.0 — 更新安装指引与打包副本清理 / Update handoff and packaging cleanup

- 更新安装指引补齐“推出安装磁盘”步骤：安装包打开后，退出旧版，将新版拖入
  “应用程序”替换，推出“FileMint”安装磁盘，再从“应用程序”重新打开。
- 本地打包使用独立临时目录；无论成功或失败，都会清除自身的临时应用、扩展和
  注册记录，避免打包副本与已安装的 Finder 扩展冲突。
- 保留 0.4.0 的 Finder 回调崩溃修复、连续创建和设置窗口专属 Dock 行为。

English: Update instructions now include ejecting the installer volume and
reopening FileMint from Applications after replacing the old app. Packaging uses
an isolated temporary build and removes its app, extension and registrations on
success or failure, preventing leftover packaging copies from competing with an
installed Finder extension. The Finder callback and Dock fixes from 0.4.0 remain.

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
shasum -a 256 -c FileMint-0.5.0.dmg.sha256
gh attestation verify FileMint-0.5.0.dmg --repo FileMintApp/FileMint
```
