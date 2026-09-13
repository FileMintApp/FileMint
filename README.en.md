<p align="center"><img src="Resources/IconSource/FileMint-AppIcon-1024.png" width="112" alt="FileMint"></p>
<h1 align="center">FileMint</h1>
<p align="center"><strong>A new file. Right here.</strong><br>A small, native macOS file creation utility.</p>
<p align="center"><a href="README.md"><strong>← 简体中文</strong></a> ｜ <strong>English</strong></p>
<p align="center"><a href="https://github.com/FileMintApp/FileMint/releases/latest">Download for macOS</a> · <a href="docs/INSTALL.md">Installation help</a> · <a href="https://github.com/FileMintApp/FileMint/issues">Report an issue</a></p>

Creating a file should not require opening an editor, choosing Save As, and finding your folder again.
**Right-click in Finder, choose a type, and your file is there.** Use a compact panel when you want to name it or paste content first.

## Small by design

- **Your filename, exactly.** Enter `demo.js` and save `demo.js`. The filename and extension selector stay in sync.
- **One-click presets.** Text, Markdown, JSON, Swift, HTML, CSS and Shell; enable CSV, YAML, XML, JavaScript, TypeScript, Python and SQL when needed.
- **Your own types.** Save suffixes such as `.toml`, `.vue` and `.log`, optional starter content, and your preferred menu order.
- **Paste before creating.** Notes, code and configuration go straight into the creation panel. Edited content, including Unicode, line breaks and literal template tokens, is saved verbatim.
- **Ready when you log in.** Launch at login and the menu bar item are enabled by default after installation and first launch. Both can be disabled in General.
- **Your language.** Follow the system language or choose English / Chinese. The Finder entry combines the FileMint logo with the localized New File label; type rows remain text only.
- **Native and focused.** Swift, AppKit and SwiftUI. Offline file creation, text-only menus, native editing, no web runtime, account or background scanning.
- **Updates on your terms.** Check from About or the menus, download a verified installer, then finish installing yourself. No automatic checks or downloads.
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

For later updates, choose **About → Check for Updates → Download Update**. After
the verified installer opens, quit FileMint, drag the new app into Applications
to replace the old copy, then reopen it. The app and menu bar menus also offer
Check for Updates.

**Distribution and provenance:** GitHub Releases is FileMint’s default distribution channel. GitHub Actions builds the DMG and publishes verifiable build provenance plus a SHA-256 checksum. This version has ad-hoc bundle signatures, **no Apple Developer ID signature and no Apple notarization**. macOS may block the first launch or require additional Finder extension approval. GitHub provenance does not replace Apple's trust checks. Read [installation and limitations](docs/INSTALL.md) first.

## Private by design

No telemetry or uploads of filenames, paths or content. Clipboard access happens only when you paste. GitHub connections happen only when you check for updates or download them. No account or subscription. [Privacy policy](PRIVACY.md).

## Buy me a coffee

If FileMint saves you a few interruptions, optional donations are welcome. Non-commercial use is free and all features remain available regardless of donations. A donation does not purchase commercial rights. Thank you!

<p align="center">
  <img src="ReceivePayment/wx.JPG" width="220" alt="WeChat Pay donation QR code">&nbsp;&nbsp;
  <img src="ReceivePayment/ali.JPG" width="220" alt="Alipay donation QR code">
</p>

## Source and license

Copyright: **XiaoDaiGua-Ray**. Developers: **XiaoDaiGua-Ray and GPT-Astra**.

**Personal and non-commercial use is free. Commercial use requires prior written authorization or a separately issued paid commercial license.**

| Use | Permission |
| --- | --- |
| Personal, educational and research use without commercial purpose | Free |
| Non-commercial forks, modifications and redistribution | Free; retain license and copyright notices |
| Business workflows, client work and paid services | Separate written authorization or paid commercial license |
| Commercial derivatives, paid distribution or product integration | Separate written authorization or paid commercial license |

FileMint uses its own [Non-Commercial Source License](LICENSE), **not MIT**. Source availability does not grant unrestricted commercial rights. See [commercial licensing](docs/COMMERCIAL_LICENSE.md).
Contributors can start with [development](docs/DEVELOPMENT.md), the [SPEC](specs/SPEC.md) and [acceptance evidence](docs/ACCEPTANCE.md).
