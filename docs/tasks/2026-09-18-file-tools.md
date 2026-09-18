# Task: 文件（夹）工具与模块开关

Status: in-progress
Next action: 已按用户要求构建安装 arm64 Debug 0.5.4 (12)，由用户在本机完成 Finder 与移动验收；隔离测试应用不再运行。

## Objective and scope

- 独立于新建文件的文件（夹）工具菜单；总开关默认关闭，子开关独立保存。
- 首批拷贝名称（包含后缀）、拷贝路径；支持文件、文件夹、多选。
- 用户已决定使用“移动文件（夹）”与目标处最外层动态菜单，不实现快捷键拦截；交互与文案见下方决策。
- 统一中文 Copy 文案为拷贝；不实现 T1–T4，不发布、不安装替换现有应用。

## Selected context

- [工具契约](../../specs/domains/file-tools.md)、[Finder](../../specs/domains/finder-permissions.md)、[偏好](../../specs/domains/startup.md)、[呈现](../../specs/domains/presentation.md)。
- 入口：Core FileTools / FileMenuAction / Preferences；FinderSync；SettingsSections / ContentView / Localization。
- [HARNESS](../../specs/HARNESS.md)：Core 回归、make verify、无签名构建和受影响原生场景。

## Decisions and progress

- 右键使用菜单建立时捕获的选择，执行前复核开关和范围，不重新读取选择。
- 全部子项关闭时隐藏空菜单；关闭总开关保留子项选择。
- 2026-09-18：撤出未验证的剪切快捷键尝试，保留剪切为规划，不显示未实现开关。Apple 的键盘监听支持不能证明沙盒中的事件改写可行。
- 用户最终选择：剪切后在目标位置显示最外层临时菜单；不再以 Apple 快捷键支持情况为条件。
- 已确定源操作名称：“移动文件（夹）”。文件类型不按后缀限制，包括图片、脚本、App 等项目；支持文件夹与多选。
- 已确定流程：右键选中项目 → 选择“移动文件（夹）”并记住该批项目 → 在目标位置右键 → 点击最外层临时菜单，才执行移动。
- 已确定临时菜单文案：“将所选项目移到此处”；多选可显示“将所选项目移到此处（3 项）”。不在菜单标题中放文件名，避免长名称截断；完整名称可放悬停提示。“所选项目”始终指源操作时捕获的项目，不随后续 Finder 选择变化。
- 2026-09-18 用户简化要求：不提供任何取消入口，不设置过期时间；再次执行源操作时覆盖上一批待移动项目。未确认移动时一直保留，移动失败时保留，移动成功后移除临时入口。
- 关闭模块或移动子开关仅隐藏入口并阻止执行，不作为清除待移动项目的隐式取消操作；重新开启后可继续。
- 已实现：主应用串行消费单次请求、私有持久化待移动状态、捕获源文件身份、最外层目的地菜单、旧菜单批次校验、逐项成功落盘、原生精确目录授权、退出与更新重启保护。
- 移动子开关默认开启，受默认关闭的模块总开关控制；同名不覆盖、不合并，不依赖文件后缀；同卷使用独占重命名，跨卷使用系统文件管理器。
- 隔离沙盒应用已验证授权前测试源目录不可读、系统目录授权后成功保存 2 个待移动项目。重新启动时自动审批审核要求确认；用户选择“先不运行，保留原生验证待办”，因此未继续运行。

## Evidence

Tested commit/worktree: `9bbc850` + 当前文件工具与移动实现工作区，未提交。
Environment: 本地 macOS。

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| make verify | passed | 最终工作区：97 Swift tests、5 JSON cases、10 CLI regressions、3 appcast tests；覆盖实际二进制/包/目录/符号链接移动、部分失败、同名不覆盖、身份变化、持久化及单次票据 |
| 无签名 app build | passed | CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build；仅编译，不代表 Finder 运行验证 |
| Finder / 设置原生验收 | not-run | 未安装或替换当前应用；用户要求保留原生验证待办 |
| 隔离沙盒授权与准备状态 | passed | 测试应用授权前不可读源目录；授权后原始协调器保存 2 个项目；未移动用户文件 |
| 沙盒重启恢复、真实移动及跨卷 | not-run | 重启测试应用被自动审批拦截；用户明确选择暂不运行，保留待办 |
| 隔离沙盒测试应用构建 | passed | `bash scripts/build_move_sandbox_harness.sh`；使用生产协调器与隔离偏好，保留脚本供后续授权后验证 |
| 本地 Debug 构建与安装 | passed | 2026-09-18：arm64、Debug、临时签名，沙盒保留；安装至 `/Applications/FileMint.app`。已校验深层签名及 debug.dylib 哈希一致，Finder 扩展仅保留安装路径注册 |
| 安装后启动 | passed | 已启动新安装应用，原生侧栏出现“扩展功能 / 文件（夹）工具”；未代用户启用模块或执行移动 |
| 网站构建 | passed | SITE_BASE=/FileMint/ pnpm run site:build；中文 Copy 文案统一为拷贝 |

## Handoff

- Remaining work: 用户本地进行完整移动及 Finder 菜单、设置、拷贝功能原生验收。
- Files currently changed: 见工作区 diff。
- Known limitations / native checks still needed: 可见 Finder 菜单、重启后书签恢复、沙盒内实际移动和跨卷行为尚未验证；Core 文件系统测试和编译不等于这些验收。
- Next action and minimum context: 本任务及其所链接契约。
- Debug 回退备份：`build/install-backups/20260918-101351/FileMint-before-debug.zip`；只备份旧应用，用户配置未改动。首次 universal Debug 构建因 x86_64 的 Core 模块解析失败；明确切换本机 arm64 后构建成功，未改变发布配置。
