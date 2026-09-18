<p align="center"><img src="Resources/IconSource/FileMint-AppIcon-1024.png" width="112" alt="FileMint"></p>
<h1 align="center">FileMint</h1>
<p align="center"><strong>把文件工具，放回 Finder。</strong><br>一个小体积的原生 macOS app：创建、处理、整理文件与图片。</p>
<p align="center"><strong>简体中文</strong> ｜ <a href="README.en.md"><strong>English →</strong></a></p>
<p align="center"><a href="https://github.com/FileMintApp/FileMint/releases/latest">下载 macOS 版</a> · <a href="website/">官网源码</a> · <a href="docs/INSTALL.md">安装帮助</a> · <a href="https://github.com/FileMintApp/FileMint/issues">反馈问题</a></p>
<p align="center"><sub>Swift + AppKit + SwiftUI · macOS 13+ · Apple 芯片与 Intel · 文件创建离线完成</sub></p>

想建一个文件，却要先打开编辑器、另存为、再找回刚才的文件夹？

FileMint 把这件事放回 Finder：**右键，选一种类型，文件就在这里。**
需要自己起名字、粘贴内容、处理图片或整理已选项目时，仍然从同一个原生工作流继续。

## 为什么是 FileMint

| 你关心的事 | FileMint 的做法 |
| --- | --- |
| 原生体验 | Swift + AppKit + SwiftUI；原生菜单、窗口和编辑器，不嵌网页运行时。 |
| 轻量与专注 | 小体积、无账号、无订阅、无后台目录扫描；打开后只做当前任务。 |
| 本地性能边界 | 文件创建、图片处理和 OCR 在 Mac 本机完成，不绕远程服务。 |
| Finder 位置感 | 在桌面或已授权文件夹中右键，目标位置由当前上下文决定。 |
| 按需扩展 | 文件工具和资源工具默认关闭，启用后也不会改变已有的新建文件菜单。 |

## 先看它怎么工作

### 1. 右键菜单保持分层

下面是当前安装版的真实 Finder 示例：选中 `longmao.navigator.png` 后，**新建文件**、**文件（夹）工具**和**资源工具**各自有清楚的入口，彩色图标帮助快速区分。

<p align="center">
  <img src="website/public/images/finder-resource-menu-zh.png" width="360" alt="FileMint 当前安装版 Finder 右键菜单，展示新建文件、文件工具和资源工具">
</p>

### 2. 创建时保留上下文

完整文件名、后缀、保存位置和初始内容在创建前一次完成。输入 `project-kickoff.md`，粘贴第一段 Markdown，然后创建；不必先生成空文件再打开其他应用。

<p align="center">
  <img src="website/public/images/create-panel-zh.png" width="760" alt="FileMint 新建文件面板，填写 project-kickoff.md 和初始内容">
</p>

创建面板支持：

- `⌘↩` 创建，`Esc` 取消；内容区回车正常换行。
- 文件名和后缀选择器保持同步；自定义后缀仍然创建 UTF-8 文本。
- 快速创建遇到同名会自动递增；自定义创建在替换前询问。
- 中文、多行、空格和字面量模板符号按原文保存。

### 3. 六个图片资源工具

选中图片后从 Finder 的“资源工具”开始，或在主应用中明确选择本地图片：

- **转换图片格式**：JPEG、PNG、HEIC、TIFF。
- **压缩图片**：使用系统编码器，原图保持不变。
- **调整图片尺寸**：保持比例，批量缩放，不放大原图。
- **生成图标**：ICNS、ICO 与多尺寸 PNG。
- **拼接图片**：横向或纵向排列，预览并调整顺序。
- **提取图片文字**：使用系统 OCR，结果可编辑、复制或保存。

<p align="center">
  <img src="website/public/images/resource-tools-zh.png" width="760" alt="FileMint 资源工具页面，显示六个图片处理工具">
</p>
<p align="center">
  <img src="website/public/images/resource-panel-longmao-zh.png" width="760" alt="FileMint 使用 longmao.navigator.png 的图片格式转换面板">
</p>
<p align="center"><sub>资源示例使用 longmao.navigator.png；预览、输出位置和“原文件始终保留”都在面板中明确显示。</sub></p>

### 4. 六个可选文件（夹）工具

模块默认关闭。打开后，每项操作都能选择显示在 Finder 一级菜单或“文件（夹）工具”子菜单：

- **拷贝文件（夹）名称 / 路径**：多选时每项一行；只有明确点按时才写入剪贴板。
- **移动文件（夹）**：先捕获源项目，再到目标文件夹空白处选择“将所选项目移到此处”。两步操作不会悄悄移动。
- **彻底删除**：默认二次确认并绕过废纸篓；符号链接只删除链接本身。
- **隔空投送**：打开 macOS 原生接收设备选择界面，不自动发送。
- **发送替身到桌面**：创建 Finder 原生替身，保留源项目，重名时自动编号。

<p align="center">
  <img src="website/public/images/file-tools-zh.png" width="760" alt="FileMint 文件与文件夹工具设置页面，显示菜单位置和独立开关">
</p>

## 设置按工作流分层

固定侧栏把设置分成三组：

- **文件创建**：模板与类型、创建行为。
- **扩展功能**：文件（夹）工具、资源工具。
- **偏好设置**：通用、Finder 与文件夹、关于。

每个页面有明确的职责，扩展模块可以单独关闭，方向键可在页面间移动。中文、英文、浅色和深色外观保持原生控件的可读性。

## 怎么用

**快速创建：** Finder 桌面背景或文件夹空白处右键 → **新建文件** → 选择类型。

**自定义创建：** **新建文件…** → 输入完整文件名 → 选择后缀 → 按需粘贴内容 → **创建**。

**资源工具：** 设置 → 扩展功能 → 资源工具；开启后，在主应用选择图片，或在 Finder 选中图片后右键。

**文件工具：** 设置 → 扩展功能 → 文件（夹）工具；先打开总开关，再按需启用动作和菜单位置。

也可以从 FileMint 应用或菜单栏选择“新建文件…”，无需先启用 Finder 扩展。

## 隐私与权限边界

- 文件名、路径、内容、图片和 OCR 结果不会上传。
- 不扫描目录、不枚举文件、不监控剪贴板，也不保留图片处理历史。
- Finder 扩展只处理当前明确选中的、位于已授权范围内的项目。
- 文件创建和图片处理离线完成；主应用只在你检查或下载更新时访问 GitHub，Finder 扩展不需要网络。
- Finder 扩展启用、文件夹授权和完全磁盘访问权限是不同的 macOS 能力；FileMint 会引导你操作，但不会静默修改系统权限。

完整说明见 [隐私政策](PRIVACY.md)。

## 下载与安装

支持 **macOS 13 及以上**，同一个安装包兼容 Apple 芯片与 Intel Mac。

**0.5.7 安装包使用 Developer ID 签名，通过 Apple 公证并附加公证票据。** 首次使用仍需按系统提示启用 Finder 扩展和文件夹授权。

1. [下载最新 DMG](https://github.com/FileMintApp/FileMint/releases/latest)，把 FileMint 拖入“应用程序”。
2. 启动 FileMint，按应用内提示启用 Finder 扩展并授权常用文件夹。
3. 回到 Finder，开始创建或处理图片。

0.5.5 起包含新更新器的版本可选择 **关于 → 检查更新 → 更新并重启**，下载校验后自动替换和重启。请先完成创建或编辑操作；macOS 可能要求管理员授权。

使用旧更新器的版本（包括 0.5.4）仍需手动安装一次 0.5.7：退出 FileMint，将新版拖入“应用程序”替换，推出安装磁盘后重新打开。

完整的安装限制、更新说明和发布来源记录，请阅读[安装指引](docs/INSTALL.md)。

## 未来规划

把日常创建文件的小事继续做好。下面只列尚未完成的方向，清单会随着实际使用和反馈更新。

<!-- #region roadmap -->
<div class="roadmap-group">

### 模板与命名

- [ ] **同格式多模板** — 为 Markdown 等同一种格式保存会议记录、项目说明等不同模板。
- [ ] **模板拷贝与预览** — 从已有模板开始修改，创建前查看文件名和初始内容。
- [ ] **文件名规则** — 用日期、项目名称等生成文件名，并预览最终结果。
- [ ] **模板导入导出** — 备份、迁移和分享自己的模板，导入时选择如何处理同名项。
- [ ] **真实文档模板** — 从自己的 Word、Excel 等文档创建副本，保留原有格式和内容。

</div>
<div class="roadmap-group">

### 创建与后续操作

- [ ] **从剪贴板新建** — 将拷贝的文本带入创建面板，命名后保存为文件。
- [ ] **图片粘贴为文件** — 把拷贝的截图或图片直接保存到当前文件夹。
- [ ] **创建后打开** — 创建完成后，用默认应用或选择的编辑器继续工作。

</div>
<div class="roadmap-group">

### 目录与工具联动

- [ ] **项目目录模板** — 一次创建常用的文件夹结构和起始文件。
- [ ] **在当前目录打开工具** — 从当前位置进入常用终端或编辑器。
- [ ] **快捷指令与启动器联动** — 从快捷指令、Raycast 或 Alfred 打开预填的创建面板。

</div>
<div class="roadmap-group">

### 查找与日常体验

- [ ] **模板分组与常用项** — 为场景模板分组、固定常用项，并通过搜索快速找到它们。
- [ ] **首次创建引导** — 从启用扩展、授权文件夹到创建第一个文件，都有清楚的下一步。
- [ ] **故障指引与兼容性说明** — 菜单未出现或无法创建时给出具体建议，持续补充云盘和外置磁盘的验证结果。

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
