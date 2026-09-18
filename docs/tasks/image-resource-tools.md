# Task: 图片资源工具

Status: in-progress (实现及隔离验证完成；安装版集成验收待做)
Next action: 用户查看原生改版；后续在安装版补验 Finder 回调、沙盒授权及 macOS 13/Intel，不把隔离夹具等同于安装验收。

## Objective and scope

- Finder 增加独立的「资源工具」入口，首批只处理用户选中的本地静态图片。
- 六项子功能：格式转换、系统压缩、调整尺寸、生成图标、图片拼接、提取文字 OCR。
- 使用 macOS 自带 Image I/O、Core Graphics、Vision；不增加第三方依赖，不支持 WebP。
- 水印、抠图暂不实现；隐私元数据清理未确认；PDF、音视频不在本任务范围。
- 默认关闭模块，提供逐项开关；离线、用户触发、逐张处理、有限像素和批次数量，保留原图。

## Selected context

- [资源工具契约](../../specs/domains/resource-tools.md)、[Finder 与授权](../../specs/domains/finder-permissions.md)、[启动和偏好](../../specs/domains/startup.md)、[外观](../../specs/domains/presentation.md)、[分发](../../specs/domains/distribution.md)。
- 入口：FinderSync、FileOperationTicket/Coordinator、Preferences、ContentView；新增 Core 规则、独立原生图片处理 target 和主应用面板。
- 验证：[HARNESS](../../specs/HARNESS.md)、[Core](../../specs/verification/core.md)、[原生检查](../../specs/verification/finder.md)。

## Stages

### R1 — 入口与安全处理基础

- [x] Core：功能开关、菜单筛选、尺寸/数量限制、输出命名与拼接布局。
- [x] 默认关闭的设置页；Finder 快照经单次票据打开主应用参数面板。
- [x] 后台串行处理、取消与进度、精确目录授权、源身份校验、原子不覆盖输出。
- [x] 回归：偏好迁移、混合选择、旧菜单、尺寸溢出、同名和取消。

### R2 — 转换、压缩与尺寸

- [x] 系统实际可写的 JPEG、PNG、HEIC、TIFF；原文件不变。
- [x] 压缩保持源格式，JPEG/HEIC 提供质量设置，PNG/TIFF 使用系统无损编码，不承诺缩小。
- [x] 最长边缩放，保持比例、不放大；大图从解码阶段降采样。
- [x] 透明图转 JPEG 使用明确的白色背景；处理方向和色彩。
- [x] 验证真实解码输出、像素尺寸、原文件保留、错误清理。

### R3 — 图标生成

- [x] ICNS、ICO 与多尺寸 PNG，按系统实际编码支持提供选项。
- [x] 居中等比适配透明正方形，产生完整尺寸集合，批量逐张。
- [x] 验证每个输出能解码、尺寸正确、同名不覆盖。

### R4 — 拼接

- [x] 横向/纵向拼接、统一短边、可调整顺序；有界缩略图预览。
- [x] 先计算画布限制，逐张解码绘制，不同时保留整批大图。
- [x] 验证顺序、横纵尺寸、超大画布拒绝和单个原子输出。

### R5 — OCR

- [x] Vision 本机识别，准确模式，按系统支持选择中英文；不引入云服务。
- [x] 结果可预览、主动拷贝、保存 TXT；无文字给出明确结果，不自动写剪贴板。
- [x] 单任务运行、取消后丢弃未发布结果，限制识别输入像素与文本缓存。
- [x] 使用合成图片验证真实识别；不访问用户资源。

## Decisions and progress

- 2026-09-18：用户认可设计稿及文件创建 / 扩展功能 / 偏好设置分层，明确要求“开始实现”。本轮实现原生界面，保留之前已完成的图片引擎与安全边界。

- 2026-09-18 后续：R1–R5 的六项处理能力与初版入口已写入当前工作区；用户要求先重新设计整套 UI/UX，因此界面定稿前保持任务 in-progress。当时先保留工作区能力，等待设计评审；以下 checklist 现记录实现完成，安装版验收另列。
- 当前实现通过 118 个 Core tests、11 个原生图片处理 tests、5 个 Harness cases、10 个 CLI tests、3 个 appcast tests，以及无签名 arm64/x86_64 构建。无提交、安装或发布。
- 两轮隔离原生夹具跑通六项功能；额外交互检查确认了中文浅色/英文深色拼图面板、顺序调整、取消目录选择、实际 5462×1024 横向输出和超大画布拒绝。零输出失败后的“调整参数”重试在后续改版夹具中已复验。
- 后续 UI 设计稿单独探索布局与流程，不将原型呈现为已经落地的原生界面。
- 用户选择“原生 macOS：通透、克制，薄荷绿点缀”；交互与视觉提案见 [UI / UX 提案 01](../design/UI_UX_V1.md)。
- 2026-09-18：用户确认排除 WebP 和新增库；同意尺寸、图标、拼接、OCR。
- “压缩到指定字节数”、动画、RAW、SVG、HDR 保真处理不在首批；避免无界重试与隐式丢帧。
- 原生图像代码置于本仓库 `FileMintImages` target，Finder 只依赖轻量 Core 规则。
- 所有原生验收使用一次性合成夹具；不自动替换安装版、不发布。

## UI/UX implementation

- [x] 三层导航：文件创建 / 扩展功能 / 偏好设置，方向键遵循视觉顺序。
- [x] 原生薄荷绿明暗配色、统一行/分组/按钮、真实状态与固定新建入口。
- [x] 设置、类型编辑、文件夹授权、关于和新建面板的视觉改造。
- [x] 资源首页使用/菜单设置分离，显式文件选择入口不依赖 Finder 开关且不扩展范围。
- [x] 图片预览 + 参数侧栏 + 底部动作，拼图预览/排序、OCR 原图/可编辑结果分栏。
- [x] 有界512像素预览缓存（20张）、串行后台处理、纯文本编辑器、取消和重启保护。

## Evidence

Tested commit/worktree: `6bf596d` + 本任务工作区。
Environment: macOS 27.0 / Xcode；兼容目标 macOS 13。

| Check | Status | Evidence |
| --- | --- | --- |
| Core / 图片处理回归 | passed | `/private/tmp/filemint-design-verify.log`：131 Swift tests（119 Core + 12 图片），5 Harness cases、10 CLI、3 appcast；含主应用/Finder 入口隔离、512 px 预览及真实编码/OCR |
| 无签名通用构建 | passed | `/private/tmp/filemint-design-build.log`；arm64 + x86_64，生成工程来自 project.yml |
| 隔离原生面板 | passed | `/private/tmp/filemint-design-resource-final.log`：6 项 × 中英文，最小处理窗口、失败修改重试、OCR 清空/再编辑、原图保留；未写系统剪贴板 |
| 全应用原生交互 | passed | `build/design-ui-harness.noindex/run.gGddab/`：真实 Views/Models/Coordinator 配合独立 store；900×650 中文浅色，840×600 英文深色；菜单关闭时主应用仍能转换 JPEG，开关仍为 false；编辑取消、关闭总开关禁用子项、新建 Unicode/原文/⌘↩ 验证 |
| 既有移动夹具构建 | passed | `/private/tmp/filemint-design-move-build.log`；适配协调器新依赖，仅编译和临时签名，未运行移动或授权 |
| 已安装 Finder / 沙盒授权 / Intel 与 macOS 13 | not-run | 与编译及夹具证据分别记录 |

## Handoff

- Remaining work: 用户视觉复核；已安装 Finder 与沙盒授权、macOS 13/Intel 实机验收。代码未提交、未安装替换、未发布。
- Next context: 本任务和资源工具契约。
