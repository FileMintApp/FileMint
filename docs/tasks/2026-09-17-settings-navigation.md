# Task: 设置入口与页面结构重构

Status: complete
Next action: 在此设置结构上开始多模板工作流 T1；发布前补做已安装签名版本的 Finder 窗口隔离回归。

## Objective and scope

- 在多模板等需求前完成设置结构重构，参考用户图片的侧栏/内容区/就近操作交互，不复制配色或功能清单。
- 五个入口：通用、创建行为、模板与类型、Finder 与文件夹、关于。统一标题、说明、分区和间距，保持原生控件与系统明暗色。
- 只重组现有可用设置；新文件入口始终可达。不增加未实现功能、修改模板语义、偏好格式或权限边界。
- 页面拆分为独立 View，侧栏通过明确页面描述路由；后续模板与命名进入对应页面，其他 roadmap 页面按真实功能需要增加。
- 验收：所有现有操作仍可达；中英文和最小窗口不截断主要操作；键盘导航可用；About 命令继续选择同一窗口；Finder 创建不自动打开设置。

## Selected context

- [外观](../../specs/domains/presentation.md)、[启动](../../specs/domains/startup.md)、[模板](../../specs/domains/templates.md)、[创建](../../specs/domains/creation.md)、[Finder](../../specs/domains/finder-permissions.md)、[更新](../../specs/domains/updates.md)。
- 入口：`ContentView.swift`、`SettingsWindowController.swift`、`PreferencesModel.Pane`、`AboutPane.swift`、`Localization.swift`。
- [HARNESS](../../specs/HARNESS.md)：App/native 行；构建后检查侧栏、调整尺寸、列表与编辑 sheet。更新服务逻辑不变，无新增网络 smoke。

## Decisions and progress

- 2026-09-17：已核对当前 TabView、固定尺寸及分散控件；先更新外观/窗口契约。
- 复用现有偏好绑定和服务方法；常驻侧栏承载导航和新文件按钮，detail 按页面拆分。未来功能不通过占位入口提前暴露。
- 现有工作区另有 AGENTS/Playbook/HARNESS/SPEC 的验证流程修改，保留这些改动，不覆盖。
- 完成 900×650 初始窗口、840×600 最小布局，以及独立的 `TypesPane`、`FoldersPane` 和通用分区组件。创建行为独立成页，数据格式和底层服务不变。
- 根据用户的深色反馈，侧栏改为连续背景、低饱和薄荷色选中态；macOS 14+ 用细薄荷色焦点线替代粗系统焦点圈，macOS 13 保留原生焦点提示。按钮保留 selected 无障碍状态和上下方向键切换。
- 后续按用户明确请求安装本地开发版至 `/Applications/FileMint.app`：使用 arm64 Debug、调试符号及 get-task-allow，保留沙盒。临时签名与 Debug dylib 的发布用 Hardened Runtime 校验不兼容，改为仅本地开发使用的非 hardened 临时签名；发行签名流程和系统安全设置未变。

## Evidence

Tested commit/worktree: `73e02f5` + 本任务实现，尚未提交。
Environment: macOS 27.0 / Xcode，2026-09-17；本地无签名 Release 构建。

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 83 个 Swift tests、5 个 JSON cases、10 个 CLI regressions、3 个 appcast tests；日志在 `build/settings-preview/verify.log` |
| 无签名 `make build` | passed | 最终侧栏与焦点修正后构建通过；日志在 `build/settings-preview/build.log` |
| 本地真实 App 检查 | passed | 中文浅色布局、模板列表、权限指引展开/滚动；关于菜单跳转同一窗口；侧栏新建打开位置选择，取消返回设置 |
| 隔离布局预览 | passed | 编译真实 View 源码并注入内存示例 model；840×600 英文/中文深色、模板按钮、创建页、关于页、编辑 sheet/Escape、最终侧栏上下键及 selected 无障碍状态。该预览不验证真实服务或持久化 |
| 已安装签名版本 Finder / macOS 13 原生回归 | not-run | 未安装或签名新版本；本轮未重测 Finder 冷启动、Dock 生命周期或旧系统外观，不以预览替代这些验证 |
| 后续本地 Debug 安装 | passed | 已安装并打开新设置；主应用和 Finder 扩展进程均位于 `/Applications/FileMint.app`，仅一份启用的扩展注册，签名验证通过，偏好文件 SHA-256 与安装前一致。未测试实际调试器 attach 或完整 Finder 创建流程 |

## Handoff

- Remaining work: 当前设置重构完成；后续进入多模板需求，发布前完成上表未运行项。
- Files currently changed: `ContentView`、`SettingsWindowController`、`PreferencesModel.Pane`、`AboutPane`、新增三个 pane/section 文件、本地化及回归测试、对应 SPEC/任务/验收记录。
- Known limitations / native checks still needed: [验收记录](../ACCEPTANCE.md#settings-sidebar-and-native-layout--2026-09-17)。后续已安装本地 Debug 版，未发布；旧安装包备份位于 `build/local-install-backups/20260917-175149/FileMint-installed.zip`，详细安装记录在同目录 `installation.json`。
- Next action and minimum context: 阅读[多模板工作流 T1](2026-09-17-template-creation-workflow.md)及模板/创建契约，沿新 `TypesPane` 接入多模板管理。
