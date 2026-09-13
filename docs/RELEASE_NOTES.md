FileMint 0.4 — 稳定常驻的 Finder 工具 / Stable Finder workflow

- 修复创建文件后 Finder 扩展意外退出的问题：连续创建后重新右键，FileMint 菜单
  仍会保留，文件名继续自动递增。
- FileMint 默认作为后台 Finder 工具运行。显式打开设置或“关于”时，Dock 图标才会
  显示；最小化设置后仍可从 Dock 恢复，关闭设置后则隐藏。
- Finder 的快速创建和“新建文件…”不会打开设置页，也不会让 Dock 常驻；冷启动时
  仅显示所需的创建面板。

English: Finder creation no longer terminates the extension after an app launch.
The context menu remains available across repeated creations. FileMint shows a
Dock icon only while settings or About is open; Finder creation keeps the app in
its background-tool mode and opens only the creation panel. macOS 13+, Apple
silicon and Intel.

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
shasum -a 256 -c FileMint-0.4.0.dmg.sha256
gh attestation verify FileMint-0.4.0.dmg --repo FileMintApp/FileMint
```
