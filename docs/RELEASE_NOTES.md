FileMint 0.2 brings focused, native file creation to macOS 13+ (Apple silicon and Intel).

- Type `demo.js`, save `demo.js`: filenames and suffixes stay in sync.
- Create common file types directly from a text-only Finder menu.
- Save your own suffixes and starter content; enable and reorder only what you use.
- Paste text before creating, with exact Unicode and literal-content preservation.
- Compact native settings and creation panel, keyboard shortcuts and a simpler icon.
- Exclusive writes protect existing files even under concurrent creation.

**Installation notice:** This build is produced by GitHub Actions with GitHub build
provenance and SHA-256 checksums. It has ad-hoc bundle signatures, **no Apple
Developer ID signature and no Apple notarization**. macOS may block first launch
or Finder extension loading. See [installation steps](https://github.com/FileMintApp/FileMint/blob/main/docs/INSTALL.md).
The app's New File… entry works independently of Finder integration.

中文：输入 `demo.js` 就保存为 `demo.js`；支持常用类型、自定义后缀、创建前粘贴内容，
Finder 菜单纯文字。首次安装限制见上方说明。感谢使用与反馈！

Verification after downloading both assets:

```sh
shasum -a 256 -c FileMint-0.2.0.dmg.sha256
gh attestation verify FileMint-0.2.0.dmg --repo FileMintApp/FileMint
```
