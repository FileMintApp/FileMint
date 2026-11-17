<p align="center"><img src="Resources/IconSource/FileMint-AppIcon-1024.png" width="112" alt="FileMint"></p>
<h1 align="center">FileMint</h1>
<p align="center"><strong>在 Finder 当前文件夹右键新建文件。</strong><br>Markdown 笔记、Word 文档和 Excel 工作簿，都能在手边的文件夹里创建。</p>
<p align="center"><a href="README.md"><strong>← English</strong></a> ｜ <strong>简体中文</strong></p>
<p align="center"><a href="https://github.com/FileMintApp/FileMint/releases/latest"><strong>下载 DMG</strong></a> · <a href="docs/INSTALL.md">安装帮助</a> · <a href="https://filemintapp.github.io/FileMint/">官网</a> · <a href="website/">官网源码</a> · <a href="https://github.com/FileMintApp/FileMint/issues">反馈问题</a></p>
<p align="center"><sub>M 系列 Mac · macOS 13 或更新版本 · DMG 已通过 Apple 公证</sub></p>

在 FileMint 中配置好文件夹后，在 Finder 的文件夹空白处右键，选择 **新建文件 → Markdown (.md)**，文件就会出现在当前目录。想先填写文件名和内容，可以选择 **新建文件…**。

<p align="center">
  <img src="website/public/images/finder-create-menu-zh.jpg" width="700" alt="Finder 右键菜单中的 FileMint 新建文件子菜单，显示文本和 Markdown 模板">
</p>
<p align="center"><sub>Finder 菜单示例；可用模板和可选工具取决于你的设置。</sub></p>

FileMint 是原生 **macOS Finder 扩展**，支持复用模板，还可按需开启批量重命名、SHA-256 文件校验、图片压缩和 OCR 文字识别。文件创建与处理都在本机完成。

[查看最新正式版的更新说明](https://github.com/FileMintApp/FileMint/releases/latest)

## 功能

- **快捷搜索**：集中查找新建操作、启用的模板、常用文件和设置，可在通用页按需开启全局快捷键。
- **快捷指令与 Raycast**：打开预填草稿或快捷搜索。需要 macOS 13.3 或更新版本，见[接入指南](docs/SHORTCUTS_AND_LAUNCHERS.zh-CN.md)。
- **拷贝文件内容**：从 Finder 拷贝受支持文本文件的完整内容，保留空白和换行；在文件（夹）工具中启用。
- **批量重命名**：在本地可写 APFS 上预览并重命名同一目录的 2–1,000 个项目，支持撤销和中断恢复，不覆盖已有项目。
- **文件信息与校验值**：查看单个普通文件的信息，按需计算四种校验值，拷贝或粘贴比对。
- **模板拷贝与预览**：从已有模板创建副本，按需查看文本输出或系统支持的 Office 预览。
- **模板导入导出**：用 `.filemint-templates` 备份、迁移或分享模板，导入前核对冲突处理。
- **创建后打开**：按模板或本次选择继续在应用中工作；打开失败保留已保存文件。
- **从剪贴板新建**：主动读取单项纯文本，在创建前核对名称、目录和内容。
- **使用 App 打开**：把常用应用加入 Finder 菜单，打开所选项目或当前文件夹。
- **图片粘贴为文件**：预览并命名拷贝的截图或图片，再保存为 PNG。
- **同格式多模板**：为同一种格式保存不同内容和默认文件名，并指定默认模板。
- **Word / Excel 模板**：内置空白 `.docx`、`.xlsx`，也可导入自己的文档，创建保留原格式和内容的独立副本。
- **切换隐藏文件显示**：通过 Finder 右键切换显示状态，不改变文件属性。

## 为什么是 FileMint

| 你关心的事 | FileMint 的做法 |
| --- | --- |
| 原生体验 | Swift + AppKit + SwiftUI；原生菜单、窗口和编辑器，不嵌网页运行时。 |
| 轻量与专注 | 小体积、无账号、无订阅、无后台目录扫描；打开后只做当前任务。 |
| 本地性能边界 | 文件创建、图片处理和 OCR 在 Mac 本机完成，不绕远程服务。 |
| Finder 位置感 | 在桌面或已授权文件夹中右键，目标位置由当前上下文决定。 |
| 按需扩展 | 文件工具和资源工具默认关闭，启用后也不会改变已有的新建文件菜单。 |

## 先看它怎么工作

### 1. 从 Finder 文件夹新建

上方是安装版在已配置文件夹中的真实菜单示例。选择已启用的模板即可快速创建；也可以打开 **新建文件…**，先核对文件名和内容。

### 2. 创建时保留上下文

完整文件名、后缀、保存位置和初始内容在创建前一次完成。输入 `project-kickoff.md`，粘贴第一段 Markdown，然后创建；不必先生成空文件再打开其他应用。

<p align="center">
  <img src="website/public/images/create-panel-zh.png" width="600" alt="FileMint 新建文件面板，填写 project-kickoff.md 和初始内容">
</p>

创建面板支持：

- `⌘↩` 创建，`Esc` 取消；内容区回车正常换行。
- 文件名和后缀选择器保持同步；自定义后缀仍然创建 UTF-8 文本。
- 快速创建遇到同名会自动递增；自定义创建在替换前询问。
- 中文、多行、空格和字面量模板符号按原文保存。

### 3. 七个图片资源工具

选中图片后从 Finder 的“资源工具”开始，或在主应用中明确选择本地图片：

- **转换图片格式**：JPEG、PNG、HEIC、TIFF。
- **压缩图片**：JPEG 使用 MozJPEG，PNG / TIFF 无损编码，HEIC 使用系统编码器；原图和尺寸保持不变，成功结果会保存并显示实际大小。
- **调整图片尺寸**：保持比例，批量缩放，不放大原图。
- **生成图标**：ICNS、ICO 与多尺寸 PNG。
- **拼接图片**：横向或纵向排列，预览并调整顺序。
- **提取图片文字**：使用系统 OCR，结果可编辑、复制或保存。
- **移除隐私元数据**：清理 GPS、拍摄时间与设备等元数据，校验后另存副本，保留原图。

<p align="center">
  <img src="website/public/images/resource-panel-longmao-zh.png" width="760" alt="FileMint 使用 longmao.navigator.png 的图片格式转换面板">
</p>
<p align="center"><sub>资源示例使用 longmao.navigator.png；预览、输出位置和“原文件始终保留”都在面板中明确显示。</sub></p>

### 4. 文件（夹）工具

模块默认关闭。可按需启用动作，再选择它在 Finder 的菜单位置。拷贝名称和路径、移动、彻底删除、隔空投送及创建 Finder 替身的操作见[使用指南](https://filemintapp.github.io/FileMint/guide.html#按需开启文件-夹-工具)。

<p align="center">
  <img src="website/public/images/file-tools-zh.png" width="760" alt="FileMint 文件与文件夹工具设置页面，显示菜单位置和独立开关">
</p>

无需 Finder 扩展，也可以从 FileMint 应用或菜单栏选择「新建文件…」。设置、快捷键和故障处理见[使用指南](https://filemintapp.github.io/FileMint/guide.html)。

## 隐私与权限边界

- 文件名、路径、内容、图片和 OCR 结果不会上传。
- 不在后台扫描目录、不监控剪贴板，也不保留图片处理历史。
- Finder 扩展只处理当前明确选中的、位于已授权范围内的项目。
- 文件创建和图片处理离线完成；主应用只在检查或下载更新时访问 GitHub，Finder 扩展不需要网络。
- 在 macOS 系统设置中启用 Finder 扩展，在 FileMint 的「文件访问」中管理已保存的目录授权。

完整说明见 [隐私政策](PRIVACY.md)。

## 下载与安装

当前正式安装包支持 **运行 macOS 13.0 及以上的 M 系列 Mac**，使用 Developer ID 签名，通过 Apple 公证并附加公证票据。

1. [下载最新 DMG](https://github.com/FileMintApp/FileMint/releases/latest)，把 FileMint 拖入“应用程序”。
2. 启动 FileMint，按应用内提示启用 Finder 扩展并授权常用文件夹。
3. 回到 Finder，开始创建或处理图片。详细操作见[首次设置指南](https://filemintapp.github.io/FileMint/guide.html#先完成首次设置)。

全新安装也可使用 [FileMint 官方 Homebrew tap](https://github.com/FileMintApp/homebrew-tap)：
`brew install --cask filemintapp/tap/filemint`。

旧版升级、Intel 兼容性及下载校验见[安装说明](docs/INSTALL.md)。Apple 在 0.5.3 发布后接受了该 DMG 的公证；公开下载包没有附加票据，Gatekeeper 需要联网获取。

## 未来规划

把日常创建文件的小事继续做好。下面只列尚未完成的方向，清单会随着实际使用和反馈更新。

<!-- #region roadmap -->
<div class="roadmap-group">

### 模板与命名

- [ ] **文件名规则** — 用日期、项目名称等生成文件名，并预览最终结果。

</div>
<div class="roadmap-group">

### 目录与工具联动

- [ ] **项目目录模板** — 一次创建常用的文件夹结构和起始文件。
- [ ] **快捷指令与 Raycast 接入验收** — 验证首次使用者可以配置并重复使用 0.8.2 起提供的草稿工作流。

</div>
<div class="roadmap-group">

### 查找与日常体验

- [ ] **模板分组与常用项** — 为场景模板分组、固定常用项，并通过搜索快速找到它们。
- [ ] **首次创建引导** — 从启用扩展、授权文件夹到创建第一个文件，都有清楚的下一步。
- [ ] **故障指引与兼容性说明** — 菜单未出现或无法创建时给出具体建议，持续补充外置磁盘的验证结果。

</div>
<div class="roadmap-group">

### 安装与分发

- [ ] **Homebrew 升级与迁移** — 在隔离 Mac 上验证升级、从手动安装迁移及卸载。

</div>
<!-- #endregion roadmap -->

每项的实现思路和完成条件记录在[实施路线](docs/ROADMAP.md)。欢迎通过 [Issues](https://github.com/FileMintApp/FileMint/issues) 分享场景，也欢迎贡献模板、翻译和复现步骤。

## 特别感谢

感谢 [阿逼（@bibinocode）](https://github.com/bibinocode) 为 FileMint 的 Developer ID 签名与 Apple 公证提交提供帮助。

## 请我喝杯咖啡

如果 FileMint 少打断了你几次，欢迎随缘打赏。非商业使用无需付费，功能不因打赏与否而区别对待。打赏不等于购买商业授权。

<p align="center">
  <img src="ReceivePayment/wx.JPG" width="220" alt="微信收款码">&nbsp;&nbsp;
  <img src="ReceivePayment/ali.JPG" width="220" alt="支付宝收款码">
</p>

## 源码与许可

版权：**XiaoDaiGua-Ray**。开发者：**XiaoDaiGua-Ray、GPT-Astra**。

**个人及非商业使用免费；商业使用须获得授权或单独购买商业许可。**

| 使用方式 | 授权要求 |
| --- | --- |
| 个人、学习、教育、研究等非商业使用 | 免费使用 |
| 非商业 fork、修改与再分发 | 免费，须保留许可和版权声明 |
| 企业商业流程、客户项目、收费服务 | 事先取得书面商业授权或付费商业许可 |
| 商业二次开发、收费分发或集成销售 | 事先取得书面商业授权或付费商业许可 |

本项目使用自定义[非商业源码许可](LICENSE)，**不采用 MIT**。源码公开不代表允许无授权商用。详见[商业授权说明](docs/COMMERCIAL_LICENSE.md)。

想参与改进？从[开发说明](docs/DEVELOPMENT.md)、[产品规范](specs/SPEC.md)和[验收记录](docs/ACCEPTANCE.md)开始。
