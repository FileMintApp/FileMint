# Task: 从剪贴板新建与在当前目录打开工具

Status: 0.6.2 已发布；以下为该轮实现和隔离夹具证据。
Next action: 复验终端或剪贴板时先核对当前契约，再按受影响范围补真机证据。

当前行为见[剪贴板文本草稿](../../specs/domains/creation.md#clipboard-text-draft)和
[使用 App 打开](../../specs/domains/open-with.md#finder-and-opening)。
旧设置方案、四款终端的接口调研及原始验收计划见[历史方案](https://github.com/FileMintApp/FileMint/blob/46882c07d1eee100cb6c200a89e72201c78a36c8/docs/tasks/2026-09-28-clipboard-text-and-directory-tools.md#官方接口证据)；
其中的终端名单只是 0.6.2 实现时的范围。

## Decisions and progress

- 已完成：当前源码和 domain 对照、需求边界、目录语义、草稿冲突规则、复用点、工具适配器方案、迁移和验收设计。
- 按后续讨论改为一份应用身份、一项菜单入口，自动区分 selection / directory；移除前稿中独立目录工具组、双开关与双位置。
- 新增四终端白名单、三种打开方式、内联行设计和更大的设置窗口；本机只读核实 Terminal / Warp 元数据，官方源码核实 iTerm2 / Ghostty 服务声明。
- 已实现文本快照、旧凭据兼容、Finder/App/菜单栏入口、原文草稿；目录目标策略、终端偏好和 Services/Warp launcher；同级下拉框、菜单预览、设置窗口尺寸与屏幕夹取。
- 已更新 owning SPEC；代码构建和自动检查通过。签名沙盒夹具确认普通文件/目录交付及独立剪贴板。Terminal 与 Warp 的 New Tab / New Window 请求返回成功，且只读进程检查确认各请求的实际 cwd，包括特殊字符与换行；窗口/标签数量仍无观察证据。
- 用户纠正了视觉交互：打开方式与菜单位置同级使用下拉框；产品代码与交互草案已调整。
- QA 发现设置窗口在语言切换后从 960×680 被 SwiftUI 撑至 960×1253；在产品 `NSHostingView` 禁用隐式尺寸建议，隔离夹具的自动回归确认语言和外观切换后尺寸保持 960×680。
- 已准备本地 Developer ID 签名 QA DMG；用户选择暂不替换 `/Applications/FileMint.app`，并表示将提供其余终端/macOS 13 环境、配合观察窗口/标签数量。本轮不安装、不改系统扩展或偏好。

## Evidence

Tested base commit/worktree: `c23ffc6` + 本任务未提交改动；原工作区仅有此任务文档。
Environment: macOS 27.2 / Apple silicon；2026-09-28。最终日志保存在 `build/qa-2026-09-28/`（本地忽略文件）。

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| SPEC、入口源码与官方接口文档检查 | passed | 复用点与接口证据见上文；静态设计证据 |
| `make verify-context` | passed | 21 documents / 113 local links；入口 6992/7000 UTF-8 bytes；这是文档检查 |
| 任务文档本地链接 | passed | 本次更新后检查 27 个本地链接，全部存在 |
| 设置页交互草案静态检查 | passed | 26 KB HTML fragment；`node --check` 通过；包含内联/列表详情两种布局、模式/位置/菜单预览/示例添加/排序交互；不算原生产品验收 |
| 草案浏览器视觉与交互验收 | blocked | 本地预览服务器受 sandbox 限制；浏览器 URL 策略拒绝 `file://`。未绕过策略，未取得截图或实际交互通过证据 |
| `make verify` | passed | Swift 168 tests / 20 suites、图像 14 tests、JSON Harness 5/5、CLI 10 项和其余离线检查，见 `build/qa-2026-09-28/filemint-qa-verify-final-20260928.log` |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | passed | 最终 Release app + Finder 扩展 unsigned build 通过，见 `build/qa-2026-09-28/filemint-qa-build-final-20260928.log`；不是签名运行证据 |
| `git diff --check` | passed | 当前未提交工作区无空白错误 |
| `APPLE_TEAM_ID=8S66M2ZLD5 ... make package` | passed | 本地 Developer ID 签名 QA DMG 的嵌套签名、entitlements、arm64 bundle、checksum 与 `hdiutil verify` 通过；`build/qa-2026-09-28/FileMint-0.6.1.dmg` 的 SHA-256 为 `e1bb5d6a9895b5566bafde35621eb58ff663338939e2c38b248d38bc8409259a`。未公证、安装或发布 |
| 签名 sandbox open-with / clipboard smoke | passed | 生产 coordinator 向接收 App 交付 selection 和目录；命名 pasteboard 原文/文件引用规则、Warp 特殊字符 URL、单次凭据、文件和通用剪贴板保持通过，见 `build/qa-2026-09-28/filemint-qa-open-with-final-20260928.log` |
| 剪贴板原生创建面板 | passed | 隔离 UI 夹具用命名 pasteboard 预填后改变剪贴板，面板仍显示原文；创建文件与预期 29 个 UTF-8 字节完全一致，第二次取消无输出；未读取用户通用剪贴板 |
| Terminal / Warp cwd | passed | 两款已安装终端的 New Tab / New Window 请求均返回成功，`lsof` 只读核实各自 shell cwd；另核实引号、中文、emoji、标点和换行均原样到达。日志见 `build/qa-2026-09-28/filemint-qa-{terminal,warp}-*.log`；**不证明窗口/标签数量** |
| VS Code 实际工作区 | passed | 生产 coordinator 打开临时目录，VS Code 原生资源管理器显示同一个目录为根；见 `build/qa-2026-09-28/filemint-qa-code-20260928.log` 和本轮原生 UI 观察 |
| 设置页和尺寸回归 | passed | 原生夹具观察同级终端模式/菜单位置、预览更新、普通 App 无终端控件；修复语言切换后窗口异常增高，`--check-window-size` 自动断言 960×680 在英语与深色切换后保持，见 `build/qa-2026-09-28/filemint-qa-window-size-20260928.log` |
| 当前源码的已安装 Finder 回调、四终端窗口/标签数量、iTerm2/Ghostty、macOS 13 | not-run | `/Applications/FileMint.app` 与工作区构建的可执行文件 SHA-256 不同；终端类 App 的电脑操作被安全限制拒绝；iTerm2/Ghostty 与 macOS 13 环境不可用。未替换安装版或修改系统扩展权限 |
| QA 后扩展注册检查 | passed | `pluginkit -m -A -D -v -i io.github.daigua.filemint.findersync` 只显示 `/Applications/FileMint.app/Contents/PlugIns/FileMintFinderSync.appex` 一项；安装版可执行文件 SHA-256 保持 `f64225d284ad30a6664677862d362305b4b599296989432dec5dc9f93f48b860` |

## Handoff

- 本轮已观察到 Terminal 和 Warp 的实际工作目录，未观察新窗口或新标签的数量。
  iTerm2/Ghostty、安装版 Finder 回调、旧系统及多屏/VoiceOver 未在本轮验证。
- 下一次涉及终端适配时以当前 SPEC 为准。Otty 的独立证据及限制见
  [2026-11-16 验收](../ACCEPTANCE.md#2026-11-16--otty-terminal-adapter)。
