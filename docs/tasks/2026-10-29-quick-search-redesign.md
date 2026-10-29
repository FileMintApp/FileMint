# Task: 快捷搜索面板重新设计

Status: complete
Next action: 用户继续体验更新后的隔离预览；本次提交并推送已获授权，安装和发布另行授权。

## Objective and scope

- 用户期望好看、好用、高级；已选择把 Spotlight / Raycast 式克制布局与 FileMint 薄荷绿品牌感结合。
- 范围：快捷搜索窗口、搜索输入的局部外观、结果层级、分类切换、空态、操作反馈。
- 保持已有执行入口、权限、持久化边界和即时输入防误触保护；不新增全局快捷键功能阶段。
- 验收：中英/深浅色/最小尺寸可读，键盘和鼠标路径一致，旧异步操作不会影响新搜索窗口。

## Selected context

- [Startup](../../specs/domains/startup.md)、[Presentation](../../specs/domains/presentation.md)
- 后续退出/恢复涉及 [Favorite Locations](../../specs/domains/favorite-locations.md) 的重新定位选择器边界，以及 [Creation](../../specs/domains/creation.md) 的已有交接流程。
- `App/FileMint/QuickSearchPanelController.swift`、`QuickSearchText.swift`、共享 `QuickSearchInputField`
- `CorePackage/Sources/FileMintCore/QuickSearch.swift` 与对应测试
- [HARNESS](../../specs/HARNESS.md)、[Native QA](../../specs/verification/native-qa.md)

## Decisions and progress

- 后续确认：继续保留 ⌘1–⌘5 分类切换，不实现左右方向键切分类。
- 后续授权：外部点击/切应用或 Space/Esc/关闭收起；再次全局快捷键在聚焦时收起。未完成查询、分类和稳定选中项仅内存保留，恢复时全选查询；成功交接或收藏成功后清空。菜单、输入法和搜索发起的重新关联流程需保护。
- 验收补充：结果列表与底部分割线之间保留固定 12 pt 留白，放在滚动区域之外，避免滚动到中间时结果贴线。
- 只在 Quick Search 启用大号无边框输入样式，旧常用位置窗口保留原输入样式。
- 分类只过滤/浏览已有快照；不读取目录、不索引文件、不保存搜索历史。
- 保留 All 空查询的三个动作和有界常用位置；分类空查询可发现模板与设置。
- Hover 只改变视觉，Return 始终对应明确选中项。
- 已完成 680 × 500 命令面板、分类浏览、图标/选中层级、用途说明、可恢复空态和固定动作底栏。
- 用户实际反馈暴露三个问题：分类快捷键只在 tooltip、初开可能没有键盘焦点、末尾省略号造成动作文案不完整的观感。分类改为直接显示 ⌘1–⌘5，底栏使用完整动作文字并优先分配空间。
- 焦点修复：明确允许原生面板成为 key；由 nonactivating panel 直接取得键盘焦点，输入框实际挂载后才通知当前窗口，旧窗口回调不能覆盖新窗口。分类点击后的聚焦同样核对窗口身份。
- 回归移除了 `searchField(in:)` 中的 `makeFirstResponder` 补救，直接检查自然焦点；这暴露了真实失败，修复后通过。测试夹具补齐原生 Edit 菜单，避免 Command-A 依赖缺失菜单。
- 独立审阅发现的最小尺寸空态高度和分组标题滚动问题已修正：空态可滚动，查询/分类变化滚到分组标题。

## Evidence

Tested worktree: primary checkout，开始时干净；最终为 `1f9a031bf04c9206b30903efb3c92db31b6f0254` 加本次未提交改动。期间另一任务提交的输入委托 MainActor 修复保留。
Environment: arm64 macOS 27.2，Xcode 27.1，Swift 6.4。

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| `make verify` | passed | 最终退出 0，370 Core + 23 Images；`build/quick-search-redesign-2026-10-29/verify-final.log` |
| unsigned `make build` | passed | 独立 DerivedData 的最终 BUILD SUCCEEDED；App/Finder 可执行文件存在；`build/quick-search-redesign-2026-10-29/build-final.log` |
| `make native-qa-plan` / `NATIVE_QA_SUITES=quick-search make verify-native-affected` | passed | 最终 `build/native-checks.noindex/run.qm9zn8nu/report.json`。含自然焦点、同面板重新呼出、即时 scope/clear/Return、带硬件标志的方向键、Esc、IME/stale ID/草稿/异步收藏保护 |
| 实际面板视觉与键盘 | passed | CUA 实际窗口：中文浅色、英文深色、模板列表、空态；最后修复版确认可见 ⌘数字、完整“创建文件”、初开直接 Down、鼠标切换分类后 Down、Command-5、Up/Down、Esc |
| 最小尺寸实机外观 | not-run | CUA 边缘拖动未成功改变窗口尺寸；已静态核对布局并提供空态滚动和底栏提示收缩，不能代替 520 × 360 实际渲染验收 |

首次默认 DerivedData 构建遇到其它构建占用数据库，改用独立目录后通过；一次中间 native run 因旧夹具仍运行及 HEAD 并发变化作废，最终报告已绑定当前代码。早期强制聚焦测试的通过不作为最终焦点证据。

首轮视觉改造按共享文件保守推荐的 design-ui/favorite-model 未重跑：旧常用位置输入外观和模型行为未变，新外观/挂载回调仅 paletteStyle 启用；quick-search 同时覆盖默认输入委托及新版面板。后续修改了重新定位选择器回调，已补跑 favorite-model，见下表。

## 退出、恢复与底部留白验收

- 使用窗口失去 key、应用切换和 Space 通知收起，不监听全局键盘或拦截鼠标事件。过滤打开时已排队的原应用激活通知；保存状态本身不触发收起。
- 关闭后只在内存保存关键词、分类和稳定选中 ID；恢复时刷新目录快照并全选关键词。成功交接到原有创建/设置流程或收藏成功后清空，原创建流程的取消/错误仍由原窗口处理。
- 每次显式唤起（包括复用同一窗口）建立新的操作归属；在按钮/Return 同步回调中捕获，旧异步成功/错误不能关闭、清空或覆盖新搜索。隐藏中的原操作成功可清空其保留状态，失败不弹回。
- 菜单跟踪、marked text 和搜索拥有的选择器都有收起保护。真实 CUA 曾发现取消 NSOpenPanel 会先把 key 交回设置窗口：现于 runModal 返回时恢复原搜索并释放保护，后续异步 I/O 完成不抢焦点。
- Modal 自动回归使用 `.modalPanel` RunLoop Timer 取消，不依赖嵌套主队列；中间未完成的驱动运行不作为通过证据。
- 固定 12 pt 留白位于结果滚动视口之外；实际模板列表画面已确认分割线上方有独立留白。

| Check / command | Status | Observed result / evidence |
| --- | --- | --- |
| `make verify` | passed | 最终退出 0，370 Core + 23 Images；`build/quick-search-dismissal-2026-10-29/verify-final.log` |
| unsigned `make build` | passed | BUILD SUCCEEDED；App/Finder 可执行文件存在；`build/quick-search-dismissal-2026-10-29/build-final.log` |
| reviewed native plan / `NATIVE_QA_SUITES=quick-search,favorite-model make verify-native-affected` | passed | `build/native-checks.noindex/run.xxu5mbhq/report.json`：两个 suite 均通过 |
| 搜索原生回归 | passed | 自然焦点、恢复 query/scope/selection、全选替换、成功清空、生产热键回调 toggle、外部窗口/一次点击投递、modal 取消、同 App 不抢焦点、菜单通知、模拟 marked text、隐藏和新/复用会话异步保护 |
| CUA 最终实际窗口 | passed | 真实右键菜单，Esc 只退出菜单；真实重新定位选择器取消后回到原搜索，保留 Favorite 查询和常用位置分类；最终模板列表固定底部留白 |
| 未覆盖边界 | not-run | 真实输入法候选窗、实际 Space/全屏/多屏切换、最小尺寸渲染、旧 macOS；不将模拟通知或 marked text 当作这些场景的实机证据 |

## Handoff

- Remaining work: 无待实现项；本轮 Git 交付已获授权，安装和发布不在本轮范围。
- Files currently changed: 搜索面板/文案/共享输入的局部模式、热键入口、收藏重新定位回调、Core 分类及测试、原生测试、两个 domain SPEC、任务记录和验收记录。
- Known limitations: 最小尺寸实机、旧 macOS、多显示器、真实输入法候选窗和非美式键盘仍需要对应环境；本次未替换正式 App 或改动正式用户偏好。
