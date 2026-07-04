# FileMint

**中文** | [English](#english)

FileMint 是一款原生 macOS 小工具，让你直接在 Finder 右键菜单里新建常用文件。

它补上的是一个很小但经常缺席的 Finder 能力：在桌面、文档、下载或你配置的目录里，右键选择模板，然后立即得到一个命名安全、内容可预测的新文件。

## 你可以用它做什么

- 在 Finder 右键菜单里创建 `txt`、`md`、`swift`、`json`、`html`、`css`、`sh` 等常用文件。
- 文件名冲突时自动生成 `Untitled 2.txt`、`Untitled 3.txt` 这样的安全名称。
- 在设置里管理 Finder Sync 扩展、监听目录、模板开关和创建后的显示行为。
- 所有创建逻辑都在本地完成，不上传文件名、路径或文件内容。

## 使用方式

1. 从 GitHub Release 下载 `FileMint-<version>.dmg`。
2. 打开 DMG，把 FileMint 拖入 Applications。
3. 启动 FileMint 一次。
4. 在 macOS Extension 设置里启用 FileMint Finder Sync 扩展。
5. 在 Finder 的 Desktop、Documents 或 Downloads 内右键，选择 `New File`。

## 图标

FileMint 的 Dock、Finder、应用包、Finder 扩展和顶部菜单栏入口使用同一套图标家族。

可编辑的图标源文件位于 `Resources/IconSource`，生成后的 Xcode 资源位于 `Resources/Assets.xcassets`。修改源图标后运行：

```sh
make icon
```

## 隐私

FileMint 是 local-first 工具，不包含遥测。详细说明见 `PRIVACY.md`。

## 协议

FileMint 不是 MIT 协议项目。代码仅允许为个人、教育、研究等非商业用途 fork、修改和再发布；任何商业用途、商业二开、商业再分发或作为商业服务的一部分使用，都需要事先获得单独书面许可。

完整条款见 `LICENSE`。

## 开发者入口

- `CorePackage` 包含不依赖 Finder 或 Xcode UI 的确定性核心逻辑。
- `CorePackage/Tests/FileMintCoreTests/Fixtures` 包含公开的文件创建验收用例。
- `App/FileMint` 包含 SwiftUI 设置应用。
- `FinderSyncExtension/FileMintFinderSync` 包含 Finder Sync 右键扩展。

常用命令：

```sh
make doctor
make verify
make icon
```

生成 Xcode 项目：

```sh
brew install xcodegen
make project
open FileMint.xcodeproj
```

构建发布包：

```sh
make build
make dmg
```

更多发布说明见 `docs/DISTRIBUTION.md`，Finder 手工验证见 `docs/FINDER_QA.md`。

---

## English

[中文](#filemint) | **English**

FileMint is a native macOS utility for creating common files directly from Finder's right-click menu.

It fills a small but persistent Finder gap: choose a template in a monitored folder, then get a safely named, predictable new file without opening an editor first.

## What It Does

- Creates common file types such as `txt`, `md`, `swift`, `json`, `html`, `css`, and `sh` from Finder.
- Avoids silent overwrites with predictable names such as `Untitled 2.txt` and `Untitled 3.txt`.
- Lets you manage the Finder Sync extension, monitored folders, template visibility, and reveal behavior from settings.
- Keeps file creation local. File names, paths, and contents are not uploaded.

## How To Use

1. Download `FileMint-<version>.dmg` from a GitHub Release.
2. Open the DMG and drag FileMint into Applications.
3. Launch FileMint once.
4. Enable the FileMint Finder Sync extension in macOS Extension settings.
5. Right-click inside Desktop, Documents, or Downloads in Finder and choose `New File`.

## Icons

FileMint uses one coherent icon family across Dock, Finder, app bundle, Finder extension, and top menu bar entry points.

Editable icon source files live in `Resources/IconSource`, while generated Xcode assets live in `Resources/Assets.xcassets`. After editing a source icon, rebuild the generated assets:

```sh
make icon
```

## Privacy

FileMint is local-first and does not include telemetry. See `PRIVACY.md`.

## License

FileMint is not MIT-licensed. The code may be forked, modified, and redistributed only for personal, educational, research, or other non-commercial purposes. Commercial use, commercial derivative products, commercial redistribution, or use as part of a commercial service requires separate prior written permission.

See `LICENSE` for the full terms.

## Developer Notes

- `CorePackage` contains deterministic core logic that can be tested without Finder or Xcode UI.
- `CorePackage/Tests/FileMintCoreTests/Fixtures` contains public file-creation acceptance cases.
- `App/FileMint` contains the SwiftUI settings app.
- `FinderSyncExtension/FileMintFinderSync` contains the Finder Sync right-click extension.

Common commands:

```sh
make doctor
make verify
make icon
```

Generate the Xcode project:

```sh
brew install xcodegen
make project
open FileMint.xcodeproj
```

Build release artifacts:

```sh
make build
make dmg
```

See `docs/DISTRIBUTION.md` for release setup and `docs/FINDER_QA.md` for Finder manual QA.
