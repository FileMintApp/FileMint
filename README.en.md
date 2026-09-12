<p align="center"><img src="Resources/IconSource/FileMint-AppIcon-1024.png" width="112" alt="FileMint"></p>
<h1 align="center">FileMint</h1>
<p align="center"><strong>A new file. Right here.</strong><br>A small, native macOS file creation utility.</p>
<p align="center"><a href="README.md">中文</a> · <strong>English</strong></p>
<p align="center"><a href="https://github.com/FileMintApp/FileMint/releases/latest">Download for macOS</a> · <a href="docs/INSTALL.md">Installation help</a> · <a href="https://github.com/FileMintApp/FileMint/issues">Report an issue</a></p>

Creating a file should not require opening an editor, choosing Save As, and finding your folder again.
**Right-click in Finder, choose a type, and your file is there.** Use a compact panel when you want to name it or paste content first.

## Small by design

- **Your filename, exactly.** Enter `demo.js` and save `demo.js`. The filename and extension selector stay in sync.
- **One-click presets.** Text, Markdown, JSON, Swift, HTML, CSS and Shell; enable CSV, YAML, XML, JavaScript, TypeScript, Python and SQL when needed.
- **Your own types.** Save suffixes such as `.toml`, `.vue` and `.log`, optional starter content, and your preferred menu order.
- **Paste before creating.** Notes, code and configuration go straight into the creation panel. Edited content, including Unicode, line breaks and literal template tokens, is saved verbatim.
- **Native and focused.** Swift, AppKit and SwiftUI. Text-only menus, native editing, no web runtime, account, network client or background scanning.
- **Safe collisions.** Quick creation increments names; custom creation asks before replacement. Concurrent requests never silently overwrite one another.

## Use it

Finder → right-click a folder background → **New File** → choose a type.

For a custom file: **New File…** → type `demo.js` → paste optional content → **Create**.

`Tab` moves focus, `⌘V` pastes, `⌘↩` creates and `Esc` cancels. Return inserts a newline in the content editor. The app and menu bar also offer creation through a folder picker, without Finder integration.

Custom suffixes produce **UTF-8 text**. Renaming a suffix does not create a valid PDF, image or Office document.

## Install

**macOS 13+**, Apple silicon and Intel in one universal DMG.

1. [Download the latest DMG](https://github.com/FileMintApp/FileMint/releases/latest) and drag FileMint into Applications.
2. Launch it, enable the Finder extension and authorize your working folders.
3. Create from Finder.

**Distribution and provenance:** GitHub Releases is FileMint’s default distribution channel. GitHub Actions builds the DMG and publishes verifiable build provenance plus a SHA-256 checksum. This version has ad-hoc bundle signatures, **no Apple Developer ID signature and no Apple notarization**. macOS may block the first launch or require additional Finder extension approval. GitHub provenance does not replace Apple's trust checks. Read [installation and limitations](docs/INSTALL.md) first.

## Private by design

No telemetry or uploads of filenames, paths or content. Clipboard access happens only when you paste. No account or subscription. [Privacy policy](PRIVACY.md).

## Buy me a coffee

If FileMint saves you a few interruptions, optional donations are welcome. All features remain available regardless of donations. Thank you!

<p align="center">
  <img src="ReceivePayment/wx.JPG" width="220" alt="WeChat Pay donation QR code">&nbsp;&nbsp;
  <img src="ReceivePayment/ali.JPG" width="220" alt="Alipay donation QR code">
</p>

## Source and license

Source is available under a [non-commercial license](LICENSE). Commercial use requires separate permission.
Contributors can start with [development](docs/DEVELOPMENT.md), the [SPEC](specs/SPEC.md) and [acceptance evidence](docs/ACCEPTANCE.md).
