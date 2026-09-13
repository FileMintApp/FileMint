FileMint 0.3 — 关于、在线更新与更专注的创建体验 / About, verified updates and focused creation

- 新增“关于”页：显示版本、版权 `XiaoDaiGua-Ray`，以及开发者
  `XiaoDaiGua-Ray · GPT-Astra`，并提供项目、许可和隐私链接。
- 可从“关于”、应用菜单或菜单栏手动检查 GitHub 正式版本；不会自动检查或下载。
- 下载更新前展示版本、大小和发布说明；安装包下载后校验大小、SHA-256 和 GitHub
  release asset digest，再保留 macOS 隔离标记并打开 DMG。
- 下载可取消、重试；校验失败时不会打开安装包。安装仍由用户完成：退出 FileMint，
  将新 app 拖入“应用程序”，再重新打开。
- Finder 的“新建文件…”现在只打开或聚焦创建面板，不再连带打开设置页；冷启动和
  设置页关闭后的创建路径也适用。
- 完全磁盘访问说明现在明确区分系统权限和已保存的文件夹授权。

English: a bilingual About page with credits, explicit GitHub Release update
checks, verified/cancellable DMG downloads, and Finder creation that opens only
the creation panel. macOS 13+, Apple silicon and Intel.

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
shasum -a 256 -c FileMint-0.3.0.dmg.sha256
gh attestation verify FileMint-0.3.0.dmg --repo FileMintApp/FileMint
```
