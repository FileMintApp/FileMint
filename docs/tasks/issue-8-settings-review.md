# Issue #8：设置与 Finder 菜单改进

Status: T1–T5 已实施，并有部分已安装 Debug 验收；原 T6 迁移方案暂缓。
Next action: 按需补未覆盖的原生场景。当前访问设置查独立任务与 SPEC。

## 范围与归属

来自 [Issue #8](https://github.com/FileMintApp/FileMint/issues/8)。T1–T2
统一 Finder 菜单设置，支持新建动作和模板分别选位置。当前规则见
[模板](../../specs/domains/templates.md#finder-placement-and-editing)与
[Finder](../../specs/domains/finder-permissions.md)契约。T3–T5 采用分体
新建按钮、收拢重复页脚和调整关于页，见[呈现契约](../../specs/domains/presentation.md#settings-information-and-shortcuts)。

T6 的非沙箱主程序迁移与全位置模式未授权实施；保留
[独立签名实验](access-migration-prototype.md)及[原方案的迁移门槛](https://github.com/FileMintApp/FileMint/blob/46882c07d1eee100cb6c200a89e72201c78a36c8/docs/tasks/issue-8-settings-review.md#已有证据与发布门槛)。
后来从 Finder 菜单范围中分离目录读写授权的工作见
[文件访问任务](2026-11-09-file-access-authorization.md)，并未改变该实验与生产版本的边界。

## Evidence

| 检查 | 状态 | 说明 |
| --- | --- | --- |
| 六项详细方案 | completed | 本文 T1–T6，与原反馈一一对应 |
| 四项审核意见补齐 | completed | 2026-10-10，仅更新 task：补齐授权入口及 file-tools 契约、新旧书签生命周期、按阶段划分发布门槛、访问检查执行与失败规则；产品实现及新增原生验收仍未执行。 |
| 本次文档检查 | passed | 基于 `f292ef8` 的当前工作区：`make verify-context` 通过；单独检查本文相对链接、六个子任务结构和空白，T1–T5 正文与补齐前一致。仅为文档证据。 |
| 交互原型 | passed | 混合位置、全部隐藏、模板启用独立性、App 新建仍可用、资源工具独立入口、两种侧栏操作区、更新交互、四种权限场景已检查。 |
| 模板编辑补充 | passed | 移除跨页入口；三个示例模板双击进入正确草稿，保存名称/内容后可重新打开，Escape 取消不修改；停用模板仍可编辑，图标控件双击不误开编辑，单击不编辑、Return 保存通过。 |
| 文档链接与上下文 | passed | `make verify-context` 对应脚本通过；本文相对 Markdown 链接逐一检查；`git diff --check` 通过。 |
| 原型布局与脚本 | passed | 九个页面检查：1040 宽中文、960 宽英文深色、320 窄屏；无横向溢出或设置行文本/控件重叠，浏览器无脚本错误。窄屏是审核载体适配，不是新增移动产品。 |
| T1–T5 产品实现 | completed | 页首 Finder 分组、独立菜单位置与迁移、模板双击/草稿编辑、分体新建、页脚精简和关于布局已实现；列表图标编辑入口按反馈移除，编辑面板保留。T6 未实施。 |
| 首轮离线验证 | passed | `make verify`：230 项 Core 测试、5/5 JSON Harness 与 CLI/发布脚本/签名配置/原生 QA 基础设施离线检查通过。菜单测试覆盖 27 种固定操作组合及模板位置、迁移、无效邻项、复制导入、原子保存冲突和默认标记。 |
| 本批 App / Finder 构建 | passed | `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build`，macOS 27.2 arm64，主程序和扩展未签名 Release 构建通过。未修改生产沙箱或权限配置。 |
| 本批隔离原生模型与布局 | passed | 现有 design-ui QA 身份；`--check-settings --templates --long-templates` 使用独立数据验证文本/Office 编辑、停用状态、复制/恢复/删除、忙时保护与保存失败回滚；9 页 × 中英文两组尺寸/外观共 18 张原生视图捕获。 |
| 模板滚动与交互复查 | passed | 本机 QA 的 178 项列表可连续滚至末段，双击第 158 个附加模板打开对应草稿，编辑面板保留图标配置；保存隐藏位置后列表同步且启用不变。另观察到双击进入、Escape 取消不提交及分体菜单的两个剪贴板入口。未量化帧率或完成 VoiceOver 全流程验收。 |
| 安装版 Finder / 支持系统 | partial | 2026-10-12 本机 Debug 安装版的混合菜单、连续新建与取消已补充真实证据，最终扩展经系统管理界面刷新后恢复；macOS 13/14 与剩余原生场景仍未验证。见下方本机安装版验收。 |

原型可编辑源位于本对话的可视化目录：
`/Users/daigua/.codex/visualizations/2026/10/10/01a124af-2a1b-7c83-80bd-57a43ed50b59/filemint-settings-review.html`。
本地浏览器预览位于 `build/issue-8-review.noindex/preview.html`；测试摘要为该目录的 `review-evidence.json`。
原型演示的是示例模板；正式实现按稳定模板 ID 覆盖全部内置与自定义/导入模板。

### 本批实现证据（2026-10-10）

- 基于 `f292ef8` 的主检出工作区，未提交、推送或发布；实现限定 T1–T5，T6 源码与权限架构未变。
- 日志：`build/issue-8-implementation.noindex/verify.log`、`build.log`、`native.log`；摘要：`evidence.json`。
- 原生视图捕获：`build/design-ui-harness.noindex/run.nuMrGm/settings-review/`。稳定 QA 应用：`build/native-qa.noindex/design-ui/FileMintDesignQA.app`；测试数据与生产偏好分离。
- 模板列表保留懒加载与拖拽/键盘重排，悬停状态移至单行；默认标记从逐行排序改为每份列表快照统一计算。滚动复查是本机功能观察，不等同于 FPS 基准。

### T2 审查修复（2026-10-10）

- 创建菜单改为在 Core 中一次注册一级/二级的完整动作批次，返回与各入口绑定的标签；Finder 只渲染已注册入口。分隔线不占标签，注册及标签分配在同一把锁内完成，保留单次消费和按批次淘汰规则。
- 迁移补入的内置模板明确保存二级位置，避免旧一级设置在后续编码或底层 `store.update` 后重新覆盖默认值；不依赖 App 保存前归一化。旧模板位置、禁用状态和已删除内置模板记录保持原规则。
- 回归覆盖超过 32 个动作的混合层级菜单、容量 1/32、后续工具注册、完整旧批次淘汰、捕获目标和单次消费、空菜单不占容量，以及新增预设的重复编码、损坏邻项、旧 JSON 原地迁移与旧 plist 解码导入后的底层原子保存。
- 本轮验证：`make verify` passed，235 项 Core 测试、22 项图片测试、5/5 JSON Harness 及适用 CLI/脚本检查通过；`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` passed，主程序和 Finder 扩展实际编译通过。新增菜单回归分别在容量 1 与 32 下确认 80 个动作全部可消费且不能重放。
- 环境与证据：`f292ef8` 基础上的当前主检出工作区，macOS 27.2 arm64；`build/issue-8-fixes.noindex/verify.log`、`build.log`、`evidence.json`。这是 Core 注册/存储回归与构建证据，没有重新宣称安装版 Finder 回调或旧系统原生验收通过。
- T6、签名配置与权限处理未修改；未提交、推送或发布。

## Handoff

### 本机安装版验收（2026-10-12）

- 用户授权本地 Debug 构建、安装、真实 App 验收及修复实际问题；基于 `14c825f`，同 Developer ID 的正式包标识安装到 `/Applications/FileMint.app`，保留生产沙箱，旧包以 ZIP 备份。
- 真实 Finder 独立动作/模板的混合层级和隐藏配置、连续三次一键新建递增、原文落盘、模板双击与取消、资源 Finder 开关关闭时的 App 入口及压缩/转换/缩放通过。模板与授权等原有用户设置已恢复。
- 临时启动事件诊断确认：读取已退出或无窗口的 App 会触发检查工具的 LaunchServices 错误或额外 reopen。已修正验收流程并移除临时诊断代码；这类工具结果不作为产品启动缺陷。完整边界和日志见 [本次验收记录](../ACCEPTANCE.md#installed-debug-and-finder-acceptance--2026-10-12)。
- macOS 13/14、桌面墙纸、全隐藏组合、完整 VoiceOver、剩余图片动作及批次取消等仍未验证；T6、更新、公证和公开发布未纳入此次验收。

- T1–T5 已获实施授权，对应领域契约随实现更新；T3 确定为分体新建按钮，T6 全部暂缓。
- 保持六个子任务；T6 的三阶段与四项审核补充仍仅为规划。实施反馈已纳入 T2：列表移除图标编辑按钮，编辑面板保留；单行悬停状态与统一默认标记计算用于减少滚动开销。
- 保留上一阶段独立签名原型及证据，不重建、不覆盖其运行数据。
- 用户已授权将 T1–T5 实现及两项 T2 回归修复提交到本地仓库；T6 继续暂缓。上方验证记录中的“未提交”描述其记录时的状态。
- GitHub 子 Issue、发送回复、推送与发布仍需按明确要求同步。
