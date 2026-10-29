# Task: 快捷键与搜索实现方案探索

Status: complete
Next action: P1 及 2026-10-29 两项 P2 级评审修复已完成本地验证；按用户下一步要求提交或进入独立构建发布流程，保留未覆盖环境。

## Objective and scope

- 初始交付是实现方案探索；2026-10-28 已完成用户授权的 P0。用户随后要求通用页提供启用开关及用户自选组合，并明确选择一并实现动作、模板、常用位置和设置的统一搜索；P2–P3 仍为后续范围。
- 将「搜索」定义为查找 FileMint 的动作、已启用模板、已保存常用位置及设置入口。全盘文件检索、文件内容索引、Spotlight 接入不属于建议首期范围。
- 建议结果：一个可配置的全局呼出键，一处快速搜索面板，按结果类型进入已有原生流程。
- 首期验收目标：应用驻留时可从其他应用呼出；搜索不访问用户目录或剪贴板；模板选择保持准确 ID；常用位置沿用书签校验；关闭设置或隐藏菜单栏不影响快捷键。
- Finder 当前目录和选中项属于单独的上下文能力，不能由「成功注册热键」推导为已具备。

## Selected context

- 当前契约：[启动与设置](../../specs/domains/startup.md)、[常用位置](../../specs/domains/favorite-locations.md)、[Finder 与权限](../../specs/domains/finder-permissions.md)、[创建](../../specs/domains/creation.md)、[模板](../../specs/domains/templates.md)。
- 第二期若接入批量重命名等动作，先完整加载 [文件工具](../../specs/domains/file-tools.md) 的对应条款；本次仅核实了批量重命名的现有入口限制。
- 流程与验证：[AI Playbook](../AI_PLAYBOOK.md)、[HARNESS](../../specs/HARNESS.md)。本次按分析与文档阶段执行。
- 如果新增依赖或权限，实施前另加载 [分发契约](../../specs/domains/distribution.md)；如果调整原生视觉，加载 [呈现契约](../../specs/domains/presentation.md)。

## Decisions and progress

### 探索时的实现基础（95c8153）

| 能力 | 已核实的代码 | 对方案的影响 |
| --- | --- | --- |
| 应用内快捷键 | [FileMintApp.swift](../../App/FileMint/FileMintApp.swift) 的 Commands 提供 ⌘N 和 ⌘K；⌘K 打开常用位置搜索 | 这些声明不是全局热键注册；建议保留现有含义 |
| 常用位置面板 | [FavoriteQuickPanelController.swift](../../App/FileMint/FavoriteQuickPanelController.swift) 使用 NSPanel、NSSearchField、懒加载结果、方向键/回车/Escape | 可复用窗口与键盘交互模式，不需要另做通用启动器框架 |
| 常用位置搜索 | [FavoriteLocations.swift](../../CorePackage/Sources/FileMintCore/FavoriteLocations.swift) 按名称精确、前缀、包含、分组、路径依次匹配；同分保留目录顺序 | 沿用已有行为；路径只是保存的文本，不查磁盘 |
| 模板搜索 | [CustomFileDraft.swift](../../CorePackage/Sources/FileMintCore/CustomFileDraft.swift) 的 FileFormatCatalog 已按后缀和别名搜索启用模板 | 同后缀模板必须按 ID 区分；不能合并成一个文件格式结果 |
| 指定模板创建 | [CustomFileSavePanelController.swift](../../SharedUI/CustomFileSavePanelController.swift) 的 present 已接受 templateID | 可直接预选模板并保留 Create 确认；无需复制写文件逻辑 |
| 应用侧创建 | [PreferencesModel.swift](../../App/FileMint/PreferencesModel.swift) 的 newFile 先选目录；剪贴板文本有独立入口 | 新入口可复用已有准备、草稿保护和授权流程 |
| Finder 上下文 | [FinderSync.swift](../../FinderSyncExtension/FileMintFinderSync/FinderSync.swift) 在 menu 回调取得目标及选择，绑定菜单动作 | 正确来源是本次菜单捕获，不是最近浏览目录或上次菜单缓存 |
| 跨进程传递 | [FileOperationTicket.swift](../../CorePackage/Sources/FileMintCore/FileOperationTicket.swift) / [QuickCreationTicket.swift](../../CorePackage/Sources/FileMintCore/QuickCreationTicket.swift) 使用私有、一次性、60 秒票据 | 第二期扩展传输时保留消费、体积、时效和主应用复核规则 |
| 生命周期 | [AppDelegate.swift](../../App/FileMint/AppDelegate.swift) 与 [FileOperationCoordinator.swift](../../App/FileMint/FileOperationCoordinator.swift) 已处理操作互斥、退出与更新等待 | 搜索入口不能旁路这些守卫 |

探索时主应用和扩展均开启 App Sandbox，最低部署目标为 macOS 13，尚无全局热键服务或快捷键偏好字段。P1 进展见下方记录。

一个需要明确的既有细节：newFile 和剪贴板文本的目录选择会调用 rememberMonitoredFolders，图片粘贴则以首个配置目录或 Home 初始化可修改的草稿。本期应沿用并明确当前行为，不把它宣传成「自动识别 Finder 目录」；若要让一次创建授权不再添加 Finder 范围，应作为独立行为决策更新契约。

### 建议首期交互

1. 菜单栏增加「快捷搜索…」，应用内建议使用 ⌘⇧K；⌘K 继续打开常用位置模式。两种模式可以共用面板实现，保留常用位置原有搜索与定位含义。
2. 按用户补充，控制入口放在「通用」的快捷搜索分组，不另建设置页。启用开关默认关闭；首次显式开启且无保存组合时自动填入 ⌃⌥K，已有自定义组合不覆盖。关掉开关保留组合，录制/恢复默认不自动开启；默认组合冲突则保持关闭并提示修改。
3. 面板打开即聚焦输入框，按动作、模板、常用位置、设置显示分组结果。上下键移动，回车执行所选结果，Escape 关闭；中文输入法组合期间由文本输入系统处理候选确认与取消。
4. 空查询显示固定常用动作及已有固定/最近常用位置；不新增模板使用频率追踪或自动重排。结果变化后按稳定 ID 保持或重置选择，避免异步刷新使回车落到另一项。
5. 输入只匹配内存快照；剪贴板只在明确执行「从剪贴板新建」或「粘贴图片」后读取。模板内容、目录内容、书签解析和可用性探测不放进逐次搜索。
6. 首期动作限制为已有应用侧创建入口和设置跳转。资源工具的显式文件选择可随后复用现有 chooseImages 入口；不把 Finder 模块开关机械套用到其已有主应用选图能力。

| 搜索示例 | 结果 | 回车后的行为 |
| --- | --- | --- |
| `md` / `Markdown` / 模板名 | 已启用的模板 | 选择目标目录，打开预选该模板的创建面板；点击 Create 才写入 |
| 常用位置名称 / 分组 / 路径 | 保存的常用位置 | 文件夹在 Finder 打开；文件在父目录选中，直接打开文件仍是明确的次级动作 |
| `剪贴板` | 从剪贴板新建 | 执行既有内容捕获和草稿流程；已有草稿则保持内容并聚焦 |
| `外观` / `授权目录` | 相应设置页 | 打开同一个设置窗口并导航；不直接修改开关 |

模板的 Finder「隐藏」位置不等于禁用，仍可作为主应用搜索结果；禁用或删除的模板不可执行。常用位置失效时保留条目与提示，沿用重连/移除，不猜测同路径替代品。执行前重新检查当前快照及所需条件，不能只信搜索时的结果。

### 全局热键选型

**建议首期采用原生 RegisterEventHotKey 的小型应用侧服务。** 首期只有一个注册项，直接返回注册错误并控制保存回滚，比为单个动作引入一套默认存储更贴合现有架构。录制和键位显示仍需认真处理，不按「几行代码」估计整个功能。

| 方案 | 适配情况 | 建议 |
| --- | --- | --- |
| SwiftUI keyboardShortcut | 适合应用命令及面板内部操作 | 保留使用；不能承担其他应用前台时的全局呼出 |
| Carbon RegisterEventHotKey | 注册指定组合；本机 SDK 仍公开声明；可直接取得 OSStatus、使用独占注册 | 首期优先，App 内封装；Core 不依赖 Carbon |
| KeyboardShortcuts | 提供 SwiftUI/AppKit 录制控件、系统/本应用菜单冲突检查和自定义存储绑定 | 后续多动作录制的备选；不是直接替换现有偏好存储 |
| NSEvent 全局监听 / CGEvent tap | 全局监听范围和权限成本更大，NSEvent 只观察且不能吞掉原事件 | 不作为首期热键后端 |

来源与限度：

- Apple 对 [NSEvent 全局监听](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents%28matching%3Ahandler%3A%29) 明确说明只观察、不能修改事件，键盘监听需要辅助功能信任。
- [KeyboardShortcuts 上游说明](https://github.com/sindresorhus/KeyboardShortcuts/blob/main/readme.md) 声明支持沙盒且不会弹出权限请求；它提供了独立于 UserDefaults 的 Binding 录制方式。这支持方案可行性，不能代替 FileMint 的签名运行验收。
- 已读 [3.1.0 Package.swift](https://github.com/sindresorhus/KeyboardShortcuts/blob/3.1.0/Package.swift)：最低系统 10.15，Swift tools 6.2。若采用，必须核实实际构建工具链，不能由项目 SWIFT_VERSION=6.0 推断可用或不可用。
- 已读上游 main 的 [HotKey.swift](https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/HotKey.swift) 与 [KeyboardShortcuts.swift](https://github.com/sindresorhus/KeyboardShortcuts/blob/main/Sources/KeyboardShortcuts/KeyboardShortcuts.swift)：注册使用 options=0，底层失败返回 nil，高层 events API 不返回注册错误。不能直接据此实现「其他应用独占冲突可见、失败保留旧绑定」的全部承诺。以上为本次 main 快照观察，选定发布版本时需重新核实。
- 本机 `Carbon.framework/Frameworks/HIToolbox.framework/Headers/CarbonEvents.h` 的 RegisterEventHotKey 注释区说明非独占热键可以有多个注册者、kEventHotKeyExclusive 的冲突语义，以及 CopySymbolicHotKeys 不含自定义应用命令。API 存在和注册成功都不等于用户实际按键验收成功。
- Apple 工程师在 [macOS 15 热键讨论](https://developer.apple.com/forums/thread/763878) 中记录了早期版本对 Option/Shift 组合的限制及 15.2 Beta 2 的调整。建议首期要求含 Command 或 Control，避免只用 Option/Shift，也不接媒体键、纯修饰键、连续多段键。

注册和持久化规则建议：

- AppDelegate 在偏好加载完成后启动服务，主线程串行注册/注销；服务独立于设置窗口及菜单栏可见状态。应用退出后快捷键不可用，首期不增加独立守护进程或热键冷启动机制。
- Core 中保存 keyCode 和规范化修饰键组合，键位显示由 App 按当前键盘布局产生。首期明确采用物理键码语义；切换输入源刷新显示，验证非美式键盘及中文输入。
- 先检查本应用绑定、系统保留键及已知菜单冲突，再尝试独占注册。只描述能检测到的冲突，不承诺枚举所有第三方快捷键。
- 新组合验证/注册成功后原子保存偏好，再释放旧注册；失败则撤销新注册、保留原保存值和旧绑定。同组合视为无变化。保存期间暂不派发候选键动作。
- 启动时无法恢复注册，保留用户配置但显示「未生效」及原因，保留菜单入口与显式重试；不能把已保存的值当作已注册成功。
- 录制时暂停触发，不因按键自动打开面板；修改/清除/导入后统一同步注册状态。导入导致冲突时提示失败状态，不静默替用户改键。
- 仅注册所配置的热键，不记录其他按键、路径或搜索文本。按键释放后触发一次，避免长按连续切换窗口。

### Finder 上下文的边界与第二期方案

Apple 的 [selectedItemURLs 文档](https://developer.apple.com/documentation/findersync/fifindersynccontroller/selecteditemurls%28%29?language=objc) 和 [Finder Sync 指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html) 规定，targetedURL/selectedItemURLs 只在菜单构造或其动作中有效，范围外可能返回 nil。因此，普通全局热键触发时不能在主应用调用这组 API，或把最近一次右键目标冒充成当前选择。

建议第二期增加 Finder 菜单/工具栏里的「搜索可用操作…」：

```text
Finder 本次菜单目标与选择
  → 用户点击搜索操作
  → 有界上下文票据（点击时按动作需要捕获身份）
  → 主应用立即消费并建立临时搜索会话
  → 搜索结果按上下文、当前开关和各工具规则过滤
  → 明确执行时重新验证并进入已有操作协调器
```

- 全局入口始终创建无 Finder 上下文的会话，清除旧会话的目标；不能继承上次打开面板的选择。
- 新传输应区分容器菜单、项目菜单和工具栏来源，保留完整选择及确切目标，不以选中目录的父目录或后来前台 Finder 窗口代替。
- 票据被主应用接收后立即消费，不留到用户搜索完成。搜索会话另设有界有效期，建议初始同为 60 秒；到期要求从 Finder 重新打开。执行前继续校验身份/范围/授权，不能靠时效代替安全校验。
- 只搜索时不把所有工具提前授权或读取文件内容；执行某个工具时复用其精确目录/资源授权和忙碌、取消、退出规则。
- 当前批量重命名 SPEC 明确只允许项目菜单，且排除全局热键、主应用选项和工具栏入口。第二期若纳入，必须先修改它的入口契约；不能仅给通用动作枚举加一个 case。
- 绑定「直接执行某动作」应在统一分发与上下文规则稳定后评估。删除等破坏性操作保留原确认要求；搜索回车不是新的确认豁免。

如果产品目标明确要求「Finder 前台时按全局键，直接对当前选择执行」，需要另行评估 Apple Events/ScriptingBridge：在激活 FileMint 之前捕获 Finder 状态、处理 Automation 拒绝/撤销、特殊视图及窗口切换，并保留沙盒文件授权校验。当前 entitlements 没有跨应用脚本授权；[Apple 沙盒说明](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html) 要求相应 scripting-targets 或 Apple Events exception。它是新增权限和运行验证范围，首期不隐式加入；不以关闭沙盒或缓存旧目录作为替代。

### 最小代码落点

名称是建议，不要求机械拆成每项一个文件：

- `CorePackage`：少量有类型的命令 ID（固定动作 / templateID / favorite UUID / 设置目的地）、搜索匹配与可用性规则、快捷键值和独立解码迁移。复用现有模板/常用位置匹配器，保持各自排序语义；先分组展示，不强做跨类统一相关性分数。
- `App/FileMint`：HotKeyService、搜索面板及一个显式 switch 分发。复用 FavoriteQuickPanel 的窗口/列表模式和现有业务入口，不建立插件注册系统，不把文件操作下沉给面板。
- `PreferencesModel` / `Preferences.swift`：首期单一呼出键；缺失/畸形字段独立降级为未绑定，不丢邻接偏好。保存成功后发布注册与搜索快照。
- `SharedUI`：继续使用现有创建面板。为模板动作增加受控的应用侧入口，选目录后传 templateID；已有草稿优先聚焦且保持原内容。
- `FinderSyncExtension`：首期无需新增读选择通道；第二期才增加菜单上下文捕获与票据类型。
- 若确需依赖或项目配置变更，先在 SPEC 记录理由，编辑 project.yml 后 make project，不手改生成的 Xcode 项目。

### 分阶段交付与验证计划

| 阶段 | 产出 | 完成证据 |
| --- | --- | --- |
| P0：热键可行性验证 | 隔离的签名沙盒原型，单热键呼出原生面板 | 真实按键、注册冲突、录制暂停、关闭/隐藏菜单、输入法、全屏/多显示器、已有模态窗；记录系统版本和签名身份 |
| P1：首期功能 | 单一全局键、动作/模板/常用位置/设置搜索、偏好保存 | Core 回归、应用编译和上述受影响原生场景；不接 Finder 任意选择 |
| P2：Finder 操作搜索 | 本次选择的临时上下文、各工具的按需分发 | 真实 Finder 回调；票据重放/过期、范围缩小、目标替换、选择变化、忙碌和取消验证 |
| P3：按需要扩展 | 独立动作快捷键；若确有需求，再评估自动化取得前台 Finder 状态 | 新入口与权限各自有 SPEC 和签名运行证据 |

实施后的自动化应覆盖：中英文/同后缀模板匹配，稳定排序，结果在执行前删除/禁用，导入与坏字段迁移，注册失败/保存失败回滚，已有草稿不被覆盖，重入不重复执行，未执行动作不读剪贴板。新 Finder 通道还需真实隔离文件夹的身份替换/无写入失败检查。

按 HARNESS，实施后运行 make verify；App/Finder 变更另做 unsigned make build，使用 make native-qa-plan 和 make verify-native-affected 选取对应自动场景。新热键或输入法边界没有现成覆盖时补最小原生场景，不能用编译或注入事件代替真实跨应用按键。最低支持 macOS 13 的运行证据与 macOS 15/26 CI 编译分开记录。

生命周期验收包括：已有授权对话框优先聚焦；搜索窗口不抢走它；重复呼出聚焦同一个窗口；仅呼出搜索不新增 Dock/设置窗口，明确执行设置跳转则遵循现有设置窗口规则；关闭搜索不丢已有草稿；执行后由原有协调器持有退出/更新守卫。全屏跨 Space 的展示策略以 P0 原生结果决定，不能仅靠 NSPanel 属性承诺覆盖所有场景。

## Evidence

Inspected revision: `95c8153376dbade23a4e358c40cbf5d8b1941d54`；开始探索时工作区干净。
Environment（探索阶段）: 本地主检出；读取 Swift 源码、SPEC、已安装 macOS SDK 头文件、Apple 文档及上游库源码。以下探索阶段检查不代表 P0 原型运行证据。

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| 当前入口、持久化与上下文静态追踪 | passed | 见上方代码链接；当前没有全局热键注册 |
| Apple 平台约束与库接口核实 | passed | 见各选型来源；可行性与运行结果明确区分 |
| 任务文档与本地链接检查 | passed | 21 个本地链接有效，任务模板章节齐全；文本空白检查通过 |
| Swift 测试、应用构建、原生按键/Finder 验收 | not-run | 本次只有探索和文档，未进入实现 |

### P0 实现与当前证据（2026-10-28）

用户已授权先做签名沙盒原型。原型位于 [scripts/hotkey_sandbox](../../scripts/hotkey_sandbox)，
构建入口为 [build_hotkey_sandbox_harness.sh](../../scripts/build_hotkey_sandbox_harness.sh)。
只有 QA 注册表、检查路由、对应回归和验证文档发生配套变化；没有改 App、CorePackage、Finder、正式配置或生产偏好。

- 固定主应用：`build/native-qa.noindex/hotkey-sandbox/FileMintHotKeyQA.app`，ID `io.github.daigua.filemint.hotkey-qa`。
- 嵌套配套应用：`Contents/Resources/FileMintHotKeyPeer.app`，ID `io.github.daigua.filemint.hotkey-peer`。交互模式提供独立前台文本窗口，自动模式只争用测试热键。
- 两者均为 arm64、Developer ID 签名、Hardened Runtime；仅声明 `com.apple.security.app-sandbox=true`。无文件选择、网络、Automation、Accessibility 或 Input Monitoring 权限请求。
- 原型默认不注册组合键；在控制台显式启用 ⌃⌥K。录制只处理当前应用收到的事件，测试偏好按 build run ID 和 invocation UUID 存在独立沙盒容器内。
- 物理键码及修饰键按原值保存；K 的界面显示仅覆盖本次固定测试键。非美式布局显示、完整系统/应用菜单冲突提示与产品级录制控件仍属于 P1。
- 本机实际环境：macOS 27.2 / arm64，Xcode 27.1（27A9275），Swift 6.4。构建目标是 macOS 13，但没有 macOS 13/14/15/26 的运行证据。检测到两个屏幕不等于已验收跨屏行为。

| 检查 | 当前结果 | 证据及限度 |
| --- | --- | --- |
| 独立进程热键冲突 | passed | 独占注册冲突返回 OSStatus -9878，旧绑定和持久化字节保留 |
| 保存失败与注册回滚 | passed | 新注册被释放，另一进程可以取得该组合；旧注册继续生效 |
| 暂停、恢复、清除、重新加载 | passed | 暂停时保留设置；恢复冲突显示未注册；对方退出后可重试；清除后对方可注册 |
| 签名及隔离 | passed | stable publisher 严格验证签名及 designated requirement；独立证书元数据检查确认沙盒 entitlement。受限 shell 的 codesign 曾不能解析元数据，最终采用与签名相同执行权限的只读核验 |
| 原生自动检查 | passed | `NATIVE_QA_SUITES=hotkey-sandbox make verify-native-affected`；最终报告 `build/native-checks.noindex/run.cm7xel7k/report.json`，fixture `run.Z23Axy`。5 个原型源码/构建文件 SHA-256 与报告记录一致 |
| 现有 QA 身份兼容 | passed | 代表性的 file-tools-settings 重新构建并运行通过；报告 `build/native-checks.noindex/run._ze174eh/report.json` 的该项独立为 passed，整体报告因当时热键启动超时为 failed，不能把整体报告称为通过 |
| 离线回归 | passed | 最终 `make verify` 退出 0；日志 `build/hotkey-sandbox-harness.noindex/verify-complete.log`，覆盖新增 QA 类型和路由的回归 |
| 原生文本/搜索交互 | passed（Computer Use 输入） | 方向键有效；已提交文本的 Return/Enter 执行一次；Escape 关闭。使用本机拼音输入 `ni`、空格选择“你”未执行搜索；组合中的 Escape 先取消输入，下一次 Escape 才关闭面板 |
| 录制暂停与恢复 | passed（Computer Use 输入） | 在录制中输入 ⌃⌥K 后恢复绑定，释放回调计数不增加 |
| 实体按键与重复打开 | passed（用户按键 + 原型日志） | 累计 9 次 release：7 次搜索呼出、2 次模态聚焦；搜索始终使用同一 windowNumber=3985，未新建第二个搜索窗口 |
| 其他应用前台 / 控制台关闭 / 隐藏图标 | passed（用户按键 + 原型日志） | 15:47:55、15:48:03、15:48:11、15:48:16 回调时均为 wasActive=false、controlVisible=false、statusVisible=false；展示时 dockRegular=false |
| Chrome 普通窗口与全屏 | passed（用户确认 + 原型日志） | 用户先反馈“出现了，Chrome 是全屏”，随后明确补充普通窗口与全屏两种方式都已实验并能出现。与上述后台日志相符；没有把最初 FileMint 前台试按当作后台证据 |
| 约 1 秒长按 | passed（用户按请求试验） | 用户按“按住约 1 秒后松开”的测试请求反馈呼出成功；代码仅在 release 执行，日志没有同一时刻连续展示。该证据不覆盖任意长时间或所有键盘设备 |
| 模态优先 | passed（用户确认 + 原型日志） | 用户确认切到 Chrome 按键后回到测试对话框；15:52:20、15:52:23 两次后台 release 后均记录 modal-priority，没有 panel-presented |
| 跨物理显示器、非美式键盘及旧系统 | not-run | 两个 NSScreen 不代表跨屏通过；当前系统之外的运行环境未验证 |

P0 结论：本机已证明原生 RegisterEventHotKey 可在现有沙盒边界内承担全局呼出；
后台、控制台关闭、隐藏状态项、Chrome 普通/全屏、重复调用、约 1 秒长按、
中文输入组合和模态优先已有对应证据。可以据此进入 P1 的产品实现，不能据此宣称
所有受支持 macOS 版本、键盘设备、显示器或 Space 布局均已验收。
Chrome 全屏场景的用户观察证明能呼出；没有单独测量是否切换 Space 的全部情况。

验证结束后通过 UI 清除原型绑定、结束测试对话框并正常退出主/配套应用；
临时 ⌃⌥K 不继续占用，保留签名原型和本地证据供复查。

自动检查的失败历史保留：`run._ze174eh`、`run.am50gdtb` 在配套应用首次沙盒初始化时超时；
采样停在 `_libsecinit_appsandbox`，没有据此判定 Carbon 不可用或关闭沙盒。
通过正常应用启动完成首次初始化后，后续独立进程检查连续通过。
首次直接子进程尝试已改为外部 QA 驱动分别启动两个独立沙盒；冷启动超时仍应在其它系统复核，不能把已暖启动的通过当成所有机器首启已验证。

交互日志：`build/hotkey-sandbox-harness.noindex/interactive-final.log`。
Computer Use 的定向组合键曾只到达前台文本框，未产生 Carbon 回调，因此没有把它算为全局键盘投递证据。
读取/重开被测应用窗口可能把它带回前台；后台检查应以回调时记录的 wasActive/controlVisible 状态和用户观察共同判定。
面板显式配置 NSSearchField 的提交 action，同时让组合输入系统优先处理 Return/Escape；不能把提交拼音的首次回车当成搜索动作。

### P1 实现与验证（2026-10-28）

用户确认了三个决定：控件放在通用、提供独立启用开关及用户自选组合、同时完成四类统一搜索；随后补充开启时应提供默认组合。P1 已按上述范围实现，P2 的 Finder 上下文和 P3 的独立动作键未扩展。

- [GlobalShortcut.swift](../../CorePackage/Sources/FileMintCore/GlobalShortcut.swift) 保存组合和独立开关，缺失/畸形字段独立恢复；默认建议是物理 K 键的 Control-Option 组合。
- [GlobalShortcutService.swift](../../App/FileMint/GlobalShortcutService.swift) 与 [GlobalShortcutController.swift](../../App/FileMint/GlobalShortcutController.swift) 负责实际注册、按释放触发、录制暂停、保存事务、加载失败和显式重试。签名原型现在编译这份正式后端，不维护第二套注册逻辑。
- [GlobalShortcutSettingsView.swift](../../App/FileMint/GlobalShortcutSettingsView.swift) 在通用提供开关、组合录制、恢复默认、真实生效状态和搜索入口。首次开启无组合时填默认；录制、关闭和恢复默认各自保持明确的开关语义。已占用组合/本应用菜单冲突提示保留原设置。
- [QuickSearch.swift](../../CorePackage/Sources/FileMintCore/QuickSearch.swift) 以稳定 ID 分组搜索创建动作、启用模板、已存常用项及设置。复用模板和收藏匹配器，保留同后缀模板，不扫描磁盘。选中结果被数据更新移除后清空选择，不能自动执行替代行。
- [QuickSearchPanelController.swift](../../App/FileMint/QuickSearchPanelController.swift) 调用原有创建、定位和设置入口；菜单栏与应用 File 菜单提供独立入口及 ⌘⇧K，原有 ⌘K 常用位置搜索不变。通用开关只控制全局注册。
- [PreferencesModel.swift](../../App/FileMint/PreferencesModel.swift) 统一处理保存/导入/外部加载与热键状态；模板结果通过现有目录选择及单一草稿预选准确 ID，已有草稿保持原样。
- [FavoriteQuickPanelController.swift](../../App/FileMint/FavoriteQuickPanelController.swift) 中的搜索输入控件供两种面板复用。按原生输入法顺序处理候选；清除按钮不能调用结果执行。没有保留自定义 keyDown 抢先处理 Return 的方案。

| 检查 | 状态 | 证据与范围 |
| --- | --- | --- |
| Core 迁移、保存、四类匹配和稳定选择 | passed | 纳入 `make verify` 的 5 个新增测试，含 1,000 条仅内存收藏与同后缀模板 |
| 六组原生检查 | passed | `build/native-checks.noindex/run.r3zm2azw/report.json`：template-workflow、creation-opening、update-scheduling、design-ui、hotkey-sandbox、quick-search；真实独立进程验证默认键冲突不启用、旧组合保留、已加载失效组合释放旧注册 |
| 最后输入控件修复 | passed | `build/native-checks.noindex/run.q187jb4e/report.json`：quick-search、design-ui；覆盖清除不执行、输入法委托、原生窗口及实际正式代码编译。其它未变后端沿用上一项证据 |
| 通用设置交互 | passed（Computer Use） | 首次开启显示 ⌃⌥K 且已生效；关闭后录制 ⌃⌥⇧K 不自动启用；再次开启保留自定义组合；Escape 取消录制；录制 ⌘Q 提示菜单冲突且原键有效；恢复默认/关闭保留 ⌃⌥K |
| 搜索交互 | passed（Computer Use） | 拼音 `m'd` 的 Return 仅提交 `md` 并显示 Markdown/会议纪要两个模板；清除恢复空查询且面板保持打开；拼音选择“外观”后找到通用，下一次 Return 导航同一设置窗口 |
| 完整离线回归 / 正式 unsigned 构建 | passed | 最终 `make verify` 退出 0，含 368 个 Core 测试；`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` 为 BUILD SUCCEEDED。日志分别为 `build/hotkey-sandbox-harness.noindex/p1-verify-complete.log` 和 `p1-build-complete.log` |
| 安装、发布、旧系统、非美式键盘、跨物理显示器 | not-run | 当前仅本地开发和隔离验收，P0 的平台边界继续保留；没有安装或覆盖用户正式应用 |

交互复查发现并修复了两个真实问题：NSSearchField 的通用 action 也会在清除时发送；自定义 keyDown 会抢先消费输入法确认。最终使用原生 NSSearchField，在输入法处理后仅响应明确 Return 事件；清除、候选确认与已提交文本的执行分别验证。复查中打开的目录选择均取消，没有创建用户文件。

当前源码修改未提交、未推送、未安装到正式应用、未发布。验收应用已正常退出，运行时只使用隔离目录和偏好，退出时释放注册。默认键名和特殊键显示已经实现，但非美式实际硬件/布局仍需实机验证，不把可编译当作该环境验收。

### P1 评审修复与回归（2026-10-29）

本轮修复两项 P2 级缺陷，恢复既有搜索与窗口生命周期契约，不涉及后续 P2 Finder 上下文功能。

- 搜索输入的 Binding setter 同步更新查询、结果和选中 ID，移除延后的 `.onChange` 重建，避免连续输入后立即 Return 执行上一轮结果。
- 收藏定位和明确的文件打开共用面板身份保护。操作开始时保存所属面板，异步完成只关闭同一面板；用户关闭后重新打开的查询不受旧任务影响，失败仍保留当前面板。
- `scripts/quick_search_checks.swift` 直接使用正式面板、输入控件和 AppKit 事件队列，覆盖 `about` 后立即 Return 的导航，以及无匹配查询不执行旧行。隔离草稿防止回归失败误开目录选择器。
- 收藏副作用通过可控 continuation 挂起，分别验证 locate/openFile 的旧任务不关闭重开面板、当前任务成功关闭、失败保留面板。只替换外部打开副作用，仍执行正式 ID、忙碌状态及会话判断。

验证环境：arm64、macOS 27.2、Xcode 27.1 / Swift 6.4，基于 `95c8153` 的当前未提交工作区。

| 检查 | 状态 | 证据与范围 |
| --- | --- | --- |
| 完整离线回归 | passed | 最终 `make verify` 退出 0，含 368 个 Core 测试；`build/quick-search-review-2026-10-29/verify-final.log` |
| 正式 unsigned 构建 | passed | `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` 为 BUILD SUCCEEDED，主应用和嵌入 Finder 扩展可执行文件存在；`build/quick-search-review-2026-10-29/build-final.log` |
| Quick Search 原生回归 | passed | 显式 `NATIVE_QA_SUITES=quick-search` 规划及执行通过；`build/native-checks.noindex/run.tkmq8k23/report.json`。已核对报告中的产品代码与回归脚本 SHA-256 和当前文件一致 |
| 验证边界 | not-run | 按键由 AppKit 合成事件投递；异步等待为可控注入，不代表真实输入法、慢卷书签 I/O 或 Finder 打开已重新验收。旧系统、非美式布局及跨显示器边界保持原记录 |

代码与回归未经提交、推送、正式安装或发布。

## Handoff

- P0 已完成，P1 已接入正式源码并完成隔离原生验收；P2–P3 未实施，尚未发布。
- 当前变更包含所属 SPEC、Core 搜索/偏好、App 控件和路由、共享搜索输入、QA 脚本及回归。未新增依赖或修改生产 entitlement；未写用户正式偏好。
- 完成最终检查后可按用户下一步要求提交或构建发布。未覆盖环境保持 not-run，发布仍遵循独立 Distribution 流程。
