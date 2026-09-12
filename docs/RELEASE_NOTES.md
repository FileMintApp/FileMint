FileMint 0.2 — 原生 macOS 文件创建工具 / Native macOS file creation

- 输入 `demo.js` 就保存为 `demo.js`，文件名与后缀选择器联动。
- 创建前粘贴文本，保留中文、多行、空格和原始占位符。
- 常用文件类型、自定义后缀与模板内容、开关及排序。
- 右键主入口为折页 F Logo + 本地化“新建文件 / New File”，子菜单保持纯文字。
- 默认登录时启动、显示菜单栏，两个开关可关闭并记住选择。
- 文件夹授权记忆与完全磁盘访问权限指引。
- 原子排他创建防止并发覆盖，替换确认默认取消。
- README 默认中文，顶部一键跳转 English。

English: exact custom filenames, paste-before-create, saved custom file types,
localized Finder entry, a redesigned Folded F identity, persistent startup/menu
bar switches, and safe collision handling. macOS 13+, Apple silicon and Intel.

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
shasum -a 256 -c FileMint-0.2.0.dmg.sha256
gh attestation verify FileMint-0.2.0.dmg --repo FileMintApp/FileMint
```
