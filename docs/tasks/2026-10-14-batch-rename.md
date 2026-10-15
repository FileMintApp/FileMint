# Task: 批量重命名

Status: in-progress
Readiness: P1 pushed / P2–P4 implemented / P5 local verification; installed-runtime checks remain
Next action: P1 已推送 `4469763`。P2–P4 代码已实现，P5 本地离线 / 构建 / 隔离原生验证见下方记录；剩余安装版 Finder、VoiceOver 和旧系统运行验收单独进行。公开发布仍是独立动作。

Created: 2026-10-14

## Objective and scope

- User-visible outcome: 在 Finder 选中一批项目，通过“批量重命名…”组合规则、查看完整预览，再明确执行；保留扩展名、禁止覆盖，失败可恢复，最近一次成功批次可撤销。
- 当前授权范围（2026-10-15）：P1 提交推送完成，继续实现 P2–P5 的文件执行 / 恢复、原生窗口、Finder / 配置和适用验收。首版保留普通本地文件和文件夹。安装、发布仍是独立动作；当前实现不更改用户的生产偏好和文件。
- 首版定位：文件（夹）工具中的可选动作，沿用本地、离线、原生交互和准确目录授权边界。

### P0 review snapshot

规范行为以 [文件工具 / Batch rename](../../specs/domains/file-tools.md#batch-rename)为准。下表是审核重点，不作为第二份产品契约。

| 能力 | P0 决策摘要 |
| --- | --- |
| 输入 | Finder 明确选中的同一父目录内普通文件、普通文件夹；菜单入口至少 2 项，变更项目可以少于选中项目 |
| 数量 / 传输 | 固定 1,000 项上限，独立受现有 1 MiB 票据限制；超限拒绝整个请求，不截断 |
| 存储支持 | 首版本地可写 APFS 的普通文件和文件夹；检查实际身份、授权、可用性及必要操作能力，不要求证明存储归属；其他环境兼容性未验不阻塞本地需求 |
| 文本替换 / 删除 | 首版固定区分大小写的普通文本匹配；删除用替换为空实现；空查找文本报错 |
| 前缀 / 后缀 | 默认作用于名称主体，扩展名保留原样 |
| 编号 | 统一名称或保留原名，设置起始值、正步长、补零位数和编号位置；参数无效或溢出时禁止执行 |
| 大小写 | 名称主体转大写 / 小写，扩展名保持原样 |
| 规则组合 | 规则按可见顺序执行，可增删和调整顺序；始终从原名重新计算，不累积上一次预览结果 |
| 名称列表 | 独立于组合规则的模式，每行一个名称主体，按明确的预览顺序映射；数量不匹配、空行或无效名称时禁止执行 |
| 排序 | 固定 en_US_POSIX 自然顺序及稳定并列次序；名单非空时改变映射必须明确确认，不假定用户点击顺序 |
| 名称保护 / 限制 | 明确拆分隐藏标记、主体和后缀；无后缀普通文件不能通过主体加点获得后缀，目录允许内部点；新输出上限 255 UTF-8 字节，不静默修整；还原原名不套用新输出上限 |
| 预览 | 原名、新名、状态及计数：将修改、未变化、无效、冲突、检查中 |
| 冲突策略 | 预检失败阻止整个批次；不覆盖、不合并、不自动跳过，也不在执行时临时追加编号 |
| 执行 | 主 App 明确确认后执行，同卷暂存、独占发布；文件夹只修改自身目录项，不遍历其内容 |
| 撤销 | 最近一次成功批次；执行反向计划前重新校验身份、权限、范围和原名占用情况 |
| 人工收口 | 无法恢复或已人工处理时，显式导出原始控制记录并解除阻塞；不清理用户暂存原件，不冒充恢复成功，同时失效已导出的当前撤销收据 |
| 设置 | 独立子开关，新安装和旧配置迁移均默认关闭；菜单位置默认二级菜单，提供图标和中英文文案 |

预览示例：统一名称“产品图”，编号从 1 开始、补三位，按名称自然升序。

```text
IMG_2.JPG   -> 产品图_001.JPG
IMG_10.JPG  -> 产品图_002.JPG
```

### Out of scope for the first version

- 正则 / 捕获组、忽略大小写查找、日期或文件内容 / EXIF 命名、任意位置插入、扩展名修改、规则预设、跨目录批次。
- 文件夹递归改名、后台发现文件、剪贴板监听、文件内容读取、脚本执行、网络服务及新增包依赖。
- 符号链接、Finder 替身、应用和其他包目录、同批重复文件身份（例如同一对象的两个硬链接）、根目录 / 卷根、系统特殊目录本体、观察根目录本体、FileMint 私有存储和已知操作暂存子树，以及包含这些私有存储 / 工作区的祖先目录。具体保护集合见 owning SPEC。
- 为绕过不可用项目而主动下载、跨卷复制降级或扩大权限。首版不增加非本地 / 非 APFS 的专用执行路径；NAS、iCloud 等兼容性标记为未验证，不作为本地实现或验收的前置条件，也不按存储归属名称额外拦截。
- Finder 的 Command-Z 集成、长期操作历史、多个改名窗口、应用内手动选择项目入口。
- 公开发布、正式安装、打包和存储环境兼容性扩展不在本轮范围；P2–P5 产品代码、适用构建和隔离验收已获授权。

### Acceptance criteria

1. 操作始终针对明确捕获的选区；旧菜单、规则变化或新的 Finder 选区不能悄悄替换已确认计划。无效输入不会被隐式过滤。
2. 预览和执行使用同一确定性规则及冻结的排序、参数和目标名称；检查未完成、错误、冲突或全体未变化时不能执行。
3. 名称拆分、排序与 Unicode 比较遵循已固化契约；隐藏标记与原后缀保持原始拼写，无后缀普通文件不得通过规则 / 名单添加后缀；目录内部点仍允许。不静默修整、截断或归一化输出。
4. 所有改名均为原父目录内的独占操作；输入身份改变、目标被抢占或系统返回不支持时停止，不覆盖其他项目，也不退回复制 / 覆盖路径。
5. 大小写改名和批次内名字互换可以完成；批次最终名称重复以及批次外已有目标在预检中报错。
6. 失败和取消会尝试恢复原名；恢复失败保留原件、暂存位置和必要恢复记录，准确报告最终状态，禁止删除未归位项目。
7. 支持进程崩溃后的有界状态核对及用户发起的恢复；不把多文件改名描述为原子事务，不承诺电源故障下的持久性。
8. 撤销同样禁止覆盖；撤销预检发现被移动 / 替换的对象或原名冲突时，不开始写入。
9. 授权准确父目录并保持必要访问至操作结束；授权不扩大 Finder 菜单范围。执行 / 恢复和活动窗口接入现有串行与退出 / 更新保护。
10. 不写文件内容或路径日志；仅保存恢复 / 撤销所需的私有状态。新操作不能静默清理尚未恢复的原件。
11. 拒绝包含 FileMint 私有存储或已知工作区的祖先目录，例如真实用户的 `Library/Application Support`；根据已知位置的真实祖先关系判定，不遍历目录。
12. 损坏 / 不支持版本 / 对象缺失的记录可以在显式人工处置确认后导出证据并收口；导出、验证或私有状态收口失败继续阻塞。整个过程不触碰用户暂存原件，人工关闭不等于已恢复，崩溃后不能重放已退役操作。
13. 普通文件夹可参与批次，仅改自身目录项，不遍历或分类后代；不因后代环境未经证明而默认排除。必要身份、授权或操作能力检查失败仍拒绝，可选存储归属信息缺失不另设关口。

## Selected context

从 [SPEC 路由](../../specs/SPEC.md)按实际行为加载，不递归预载其他领域。

| Domain contract | 使用范围 |
| --- | --- |
| [File tools](../../specs/domains/file-tools.md) | 主归属：选区、菜单动作、开关、改名、批次状态、取消 / 恢复 / 撤销 |
| [Finder and permissions](../../specs/domains/finder-permissions.md) | 捕获目标、配置范围、真实路径 / 身份、准确父目录授权、主 App 所有权 |
| [Startup and preferences](../../specs/domains/startup.md) | 新子开关迁移、窗口所有权、退出和更新重启保护 |
| [Presentation](../../specs/domains/presentation.md) | 设置行、菜单位置、图标、双语、键盘与无障碍 |
| [Creation](../../specs/domains/creation.md) | 仅对照现有名称语义，避免把创建文件的自动修整策略带入改名；不改变创建行为 |

Implementation entry points:

- Core： [FileTools.swift](../../CorePackage/Sources/FileMintCore/FileTools.swift)、[FileMenuAction.swift](../../CorePackage/Sources/FileMintCore/FileMenuAction.swift)、[FileOperationTicket.swift](../../CorePackage/Sources/FileMintCore/FileOperationTicket.swift)、[PendingFileMove.swift](../../CorePackage/Sources/FileMintCore/PendingFileMove.swift)、[StagedFileEntry.swift](../../CorePackage/Sources/FileMintCore/StagedFileEntry.swift)、[FilenamePolicy.swift](../../CorePackage/Sources/FileMintCore/FilenamePolicy.swift)。
- Finder： [FinderSync.swift](../../FinderSyncExtension/FileMintFinderSync/FinderSync.swift)。
- App： [FileOperationCoordinator.swift](../../App/FileMint/FileOperationCoordinator.swift)、[FileToolsSettingsView.swift](../../App/FileMint/FileToolsSettingsView.swift)、[ResourceToolsController.swift](../../App/FileMint/ResourceToolsController.swift)（窗口与生命周期参考）。
- 回归参考： [FileToolsTests.swift](../../CorePackage/Tests/FileMintCoreTests/FileToolsTests.swift)、[FileMoveTests.swift](../../CorePackage/Tests/FileMintCoreTests/FileMoveTests.swift)。

Verification:

- 当前按 [HARNESS](../../specs/HARNESS.md)运行实现后的 `make verify`、未签名 App / Finder 构建及适用隔离 native 验收；公共文件创建 JSON Harness 格式不扩展。历史 P1 验证与本轮结果分别记录。
- 前序 P0.5 隔离 CLI 的 [历史证据](evidence/2026-10-14-batch-rename-p05.md)保留；其分类前置关口已取消，不补设替代前置关口。命令沙盒及宿主 CLI 均不是签名 FileMint App Sandbox 验证；后续需要原生 fixture 时加载 [Native QA](../../specs/verification/native-qa.md)。
- 后续实现： [Core 检查](../../specs/verification/core.md)、[Finder / native 检查](../../specs/verification/finder.md)。
- 工作流： [AI Playbook](../AI_PLAYBOOK.md)及 [Task template](TEMPLATE.md)。

Load additional context when:

- 若调整已收藏项目的解析或显示，加载 [Favorite locations](../../specs/domains/favorite-locations.md)；仅增加相关验收场景不等于授权重写收藏模块。
- 若增加原生 QA fixture，加载 [Native QA](../../specs/verification/native-qa.md)，使用稳定身份和隔离数据。
- 若需要修改项目注册或构建配置，加载 [Distribution](../../specs/domains/distribution.md)；仅编辑 `project.yml` 后 `make project`，不编辑生成的 Xcode 项目。

## Decisions and progress

### Completed analysis

- 2026-10-14：已比较 MouseBoost 更新历史与 FileMint 的当前能力，随后静态核对相关契约、票据、改名原语、操作队列和退出 / 更新保护。
- 初次建档阶段只创建本 task；随后已将 P0 写入 SPEC，上一阶段按审核意见修订。仍没有实现任何改名入口。
- Finder 已有基础替换、添加和编号。首版价值集中在规则组合、完整预览、扩展名保护和真实的批次恢复能力。
- 现有 `FileMoveItem` 可提供文件身份检查；`StagedFileEntry.renameExclusive` 可提供不覆盖的底层操作。
- 现有 `FileMoveService` 排除同目录移动，逐项处理且目标保留原名，不能直接当作批量重命名执行器。
- `StagedFileEntry.claim/restore` 是单项目流程。批次恢复还需在改名之前记录已知暂存位置，并处理多项目依赖和崩溃窗口；不能仅包一层现有 `claim` 就宣称支持恢复。
- `FilenamePolicy.sanitizedFileName` 会修整、替换字符及回退到 `Untitled`；改名另建严格校验策略，保留创建文件现有规则。
- 现有操作票据最多 1 MiB、60 秒内一次性消费。票据寿命约束打开请求，不应被误用为已打开窗口中的计划寿命。

### P0 review revisions completed

P0 已修正三处审核问题，并按前序用户决策取消分类前置关口，首版保留普通本地文件和文件夹。以下是当时的完整目标契约摘要；该复核结束时只实现 P1 纯规则。当前实施状态以下方阶段表和 2026-10-15 证据为准。

| 决策 | 结论 / 理由 | Owning contract |
| --- | --- | --- |
| 输入与格式支持 | 同父目录 2–1,000 项，本地 APFS，严格拒绝无效邻居、重复身份和未知能力；控制首版的命名空间与恢复复杂度 | [Selection and availability](../../specs/domains/file-tools.md#selection-and-availability) |
| 保护对象 | 固定系统 / 用户特殊目录本体、观察根对象、私有存储与操作暂存子树，另排除包含私有存储 / 工作区的祖先目录；按真实对象而非同名目录匹配 | [Selection and availability](../../specs/domains/file-tools.md#selection-and-availability) |
| 名称拆分 | `.env` 无后缀；`.env.local` 保护 `.local`；无后缀普通文件的变更主体禁用 ASCII 点，目录仍允许内部点；固定复合后缀和隐藏标记均保留 | [Names and ordering](../../specs/domains/file-tools.md#names-and-ordering) |
| 名称有效性 | 新输出 255 UTF-8 字节上限，首尾空白 / 末尾点报错，保留 emoji 的 ZWJ；还原精确原名不受新输出工具上限限制 | [Names and ordering](../../specs/domains/file-tools.md#names-and-ordering) |
| 排序与冲突 | 固定 locale 的自然顺序 + 原始 UTF-8 稳定并列规则；比较键只用于保守预检，原生独占操作最终裁决 | [Names and ordering](../../specs/domains/file-tools.md#names-and-ordering) |
| 规则与名单 | 固定区分大小写替换；编号和工作字符串有明确上限；CRLF / CR 归一为分隔符，只忽略一次结尾换行，内部空行不丢弃；重排名单需确认 | [Rules and name lists](../../specs/domains/file-tools.md#rules-and-name-lists) |
| 新请求与确认 | rename 票据在入口及时消费；忙碌时明确拒绝并聚焦现有窗口，不排队到过期，不替换原批次；面板寿命独立于票据 | [Preview and request ownership](../../specs/domains/file-tools.md#preview-and-request-ownership) |
| 恢复协议 | 先写已知位置与身份，再变更目录项；先全批暂存再独占发布；失败 / 取消停止并尝试还原，保留无法归位项目 | [Execution and recovery](../../specs/domains/file-tools.md#execution-and-recovery) |
| 恢复权限 | 普通 rename / undo 依赖当前开关与范围；已开始操作的补偿恢复可在关闭 / 收窄后回到同一父目录对象，不扩大范围 | [Finder authorization](../../specs/domains/finder-permissions.md#batch-rename-authorization) |
| 异常记录收口 | 用户确认人工处置与后果后，先导出并验证原始私有记录，再持久化退役标记并解除阻塞；失效当前撤销，不清理用户原件，不建立应用内长期档案 | [Manual resolution](../../specs/domains/file-tools.md#manual-resolution-of-recovery-records) |
| 私有状态 / 撤销 | 一条未完成操作 + 最近一次成功收据；版本化、有界、权限受控，启动仅提示；undo 失败回到 undo 开始前状态，成功后不生成 redo | [Persistent state and undo](../../specs/domains/file-tools.md#persistent-state-and-undo) |
| 生命周期 / UI | 独立窗口和串行 guard；恢复入口在禁用区域之外；普通 Return 不提交、Command-Return 仅提交当前有效预览 | [Lifecycle](../../specs/domains/startup.md#batch-rename-lifecycle), [Presentation](../../specs/domains/presentation.md#batch-rename-presentation) |

审核修正记录（2026-10-14）：

- 已补私有存储祖先保护，防止 `Application Support` 进入暂存时携带现有偏好、票据、待移动记录及可能位于其中的恢复索引。
- 已补损坏 / 无法恢复记录的人工收口、原始证据导出、撤销失效及收口中断边界。
- 扩展名决策采用保留原承诺的收紧方案：`README -> README.txt`、`.env -> .env.local` 禁止；普通目录 `Photos -> Photos.2026` 允许。不重新解析 / 修整生成主体。
- 曾将正向非受管分类前移为 P0.5，并完成局部探针；用户随后取消这一前置门槛。原始观察保留，不把旧的 incomplete 改写成 passed，该门槛不再作为实施依赖。

当前实施边界：

- 仅检查完成操作所需的实际身份、父目录、权限、可用性、名称冲突及文件系统能力。必要信息无法确认则拒绝；可选 provider 查询缺失不构成额外阻塞，也不能替代上述检查。不建立全局存储归属分类器或云盘路径扫描流程。
- 255 UTF-8 字节是主动选择的保守工具输出上限，不宣称等于 APFS 通用上限；旧长名称不被改写，恢复 / 撤销仍能尝试还原原始合法组件。
- 文件系统大小写 / Unicode 行为、目录句柄、进程崩溃窗口及恢复授权尚未实测。P0 完成仅表示文档修订完成，不表示原生方案已验证。

### Current scope decision (2026-10-14)

- 用户明确取消“正向证明非受管”的准入和实施前置要求；不新建同义的替代关口。首版保留同一真实父目录中的普通本地文件和文件夹，仍以本地可写 APFS 为已规划执行范围。
- 系统决定权限和原生操作能否执行；FileMint 负责冻结选区 / 预览、必要身份与范围检查、独占不覆盖、失败停止、尽力恢复及真实结果报告。系统成功单次改名不等于整个批次原子成功，现有日志 / 撤销 / 人工收口要求保留。
- 不遍历目录以证明后代存储归属，不扫描提供商或云盘根，不要求用户声明项目“非受管”。目录仅改自身目录项，后代随其路径变化，不逐项处理内容。
- NAS、iCloud 等兼容性留待确有需求或实际问题时专项验证，不阻塞本地实现 / 验收，不宣称已经支持。每次请求仍遵守同一必要能力与安全检查，不能绕过系统拒绝。
- 后续验证聚焦普通本地文件 / 文件夹、冲突和并发替换、授权取消、系统返回不支持、暂存 / 发布失败及恢复。适用的 Harness / 原生验收要求保持；该范围决策阶段仅修订文档，当前 P1 实现进展见下方记录。

### Historical P0.5 observations (prerequisite withdrawn)

前序 [可行性记录](evidence/2026-10-14-batch-rename-p05.md)、[原始观测](evidence/2026-10-14-batch-rename-p05-observations.json)和 [探针源码](evidence/2026-10-14-batch-rename-p05-probe.md)保留。它们记录 macOS 27.2 的隔离普通文件 / 目录元数据，不能替代签名 App Sandbox、实际改名或恢复验收。

当时的跨 provider 正向分类结论为 **incomplete / gate not passed**；本轮用户已撤销该关口，不把历史结论改为 passed，也不继续要求补齐原分类矩阵。查询空值 / 错误仍不能证明任何存储归属，但这一归属结论已不是产品准入必需事实。原始 JSON、源码和 hash 不变。

### Final design review (2026-10-14)

- 前序复核未发现阻碍进入实现的新设计问题，当时标记为待实现。命名 / 名单、普通目录、身份 / 授权、票据 / 窗口所有权、暂存 / 独占发布、失败恢复、撤销及人工收口的任务描述与 owning SPEC 一致。
- 前序三项审核问题已闭合；原分类前置门槛已取消，未以兼容性待验重新引入。
- 目录句柄、大小写 / Unicode 对照、系统错误、syscall 与日志间的崩溃窗口、回滚 / 撤销及恢复授权仍需按 P1–P5 实现和验证。这些是已规划的实现验收项，不是已通过的运行证据。

### P1 implementation (2026-10-14)

- [RenameNamePolicy](../../CorePackage/Sources/FileMintCore/RenameNamePolicy.swift) 独立于创建文件 sanitizer：捕获隐藏标记 / 后缀，严格输出校验，保留原始 UTF-8；包含 unchanged / restoration 豁免、namespace 预检键和固定自然排序。
- [BatchRenameRule](../../CorePackage/Sources/FileMintCore/BatchRenameRule.swift) 实现按序字面替换 / 删除、前后缀、编号及默认 Unicode 大小写映射。字面参数使用字节精确相等，编号先检查全批溢出，字符串扩容前检查预算。
- [BatchRenamePlanner](../../CorePackage/Sources/FileMintCore/BatchRenamePlanner.swift) 复用不可变原名批次；提供排序、名单行绑定与显式重分配、逐行状态 / 计数、最终命名空间冲突及不可变命名计划。名单先检查行数再拆分，避免为不匹配的百万空行分配逐行对象。
- 目标观察为显式注入数据，不执行元数据查询；缺失 / pending 保持 checking，错误不当作 absent。观察绑定完整批次、revision、模式 / 参数、顺序及命名环境；更新观察会撤销旧的成功状态，不累积遗漏项。
- 仅在命名和注入目标检查完整且有实际名称变化时允许 freeze。冻结的是命名提案，未验证真实父目录 / 文件身份、授权、源可用性或现场目标；P2 必须执行这些原生复验后才能操作文件。
- 新增 [名称策略测试](../../CorePackage/Tests/FileMintCoreTests/RenameNamePolicyTests.swift)、[规则测试](../../CorePackage/Tests/FileMintCoreTests/BatchRenameRuleTests.swift)及 [规划器测试](../../CorePackage/Tests/FileMintCoreTests/BatchRenamePlannerTests.swift)，共 52 个纯测试，已随完整 `make verify` 通过；见 [P1 验证记录](evidence/2026-10-14-batch-rename-p1.md)。本轮不创建菜单、窗口、票据、恢复存储或文件执行器。

### P2–P5 implementation (2026-10-15)

- 按用户指定顺序，先提交并推送 P1 为 `4469763`，随后实现后续阶段；实现与验证证据一起交付。
- Core 新增 [native 身份 / 句柄](../../CorePackage/Sources/FileMintCore/BatchRenameNative.swift)、[文件执行器](../../CorePackage/Sources/FileMintCore/BatchRenameService.swift)、[私有状态存储](../../CorePackage/Sources/FileMintCore/BatchRenameStore.swift)。准备预留、固定有界 scratch、意图先记、全批暂存、独占发布、rollback / undo / 原始证据人工退役都已有实现和故障覆盖。
- App 新增 [控制器](../../App/FileMint/BatchRenameController.swift)、[原生视图](../../App/FileMint/BatchRenameView.swift)、[操作与生命周期接入](../../App/FileMint/BatchRenameOperations.swift)和[准确父目录授权](../../App/FileMint/BatchRenameAccess.swift)。独立持有父目录 grant，范围收窄后仍保留补偿恢复能力；状态面板区分恢复原名、已提交操作收尾与纯私有记录收口。
- Finder / 配置新增默认关闭的 batchRename、独立菜单位置 / 图标 / 双语及 rename 票据路由。忙碌时立即消费并明确拒绝，不替换窗口输入；原移动请求仍按既有队列执行。设置外部恢复卡、File 菜单 undo 和退出 / 更新 busy guard 已接入。
- `make verify` 已通过 Core 318、Images 22、公共 Harness 5/5 和 CLI 10；未签名 App / Finder 构建及隔离 signed sandbox fixture 已通过。完整命令、测试修正、native 断言、源码快照和未验边界见 [P2–P5 证据](evidence/2026-10-15-batch-rename-p2-p5.md)。
- 当前普通本地 APFS 实测与真实窗口证据不等于安装版 Finder 回调、VoiceOver、macOS 13/14 或其他存储环境已验证。没有安装覆盖生产 App、改生产偏好或公开发布。

### Execution and recovery design

实现必须遵守 [执行协议](../../specs/domains/file-tools.md#execution-and-recovery)和 [私有状态 / undo](../../specs/domains/file-tools.md#persistent-state-and-undo)。下列是实现分工概要；每次底层改名可以独占执行，整个批次不具备原子性。

1. **捕获 / 授权**：菜单保留完整 URL 选区；明确点击后捕获身份。主 App 重新检查完整请求，授权准确父目录，固定父目录身份。
2. **建立 / 冻结计划**：为项目分配稳定行 ID，计算原名、新名和依赖关系；参数或排序变化产生新的计划版本，过期异步预览不能启用执行。确认后锁定计划。
3. **全量预检**：检查身份、范围、开关、输入类型、父目录、卷能力、保护对象祖先关系和所有目标；不要求存储归属证明。占用检查失败不能视为不存在；仅大小写变化不等于未变化。
4. **准备日志和暂存器**：为批次建立已知的同卷私有暂存位置，先持久化恢复信息和操作意图，再改变用户目录项。记录失败则不执行。
5. **暂存源项目**：逐项独占迁入暂存位置，并核验实际对象身份。仅处理会变化的行；保留未变化项目，不把它们的名称当作空闲目标。
6. **发布目标**：按冻结计划独占发布，逐步更新真实状态；目标被抢占、授权失效、开关 / 范围变化或取消时停止新增发布并进入恢复。
7. **恢复原名**：已发布项目先回到受控暂存，再按原名恢复，避免互换 / 环形依赖造成回滚冲突。恢复只处理本批次拥有的对象，不覆盖后来到达的项目。
8. **完成 / 撤销**：保留最近一次成功批次的必要映射；反向计划全量预检后才能写入。暂存目录仅在已验证属于本批次且为空时删除；正常完成 / 恢复后收口私有记录，异常记录的人工退役只走下方独立协议。

恢复补充要求：

- 启动时只读取私有索引中的已知任务；不扫描用户目录找暂存文件，不自动继续改名。
- 日志状态仅作线索；改名成功但日志未更新的崩溃窗口，需要核对原位置、暂存位置、目标位置和身份。
- 未完成操作由用户明确发起恢复；无法安全恢复时保留文件，展示实际位置和后续操作。
- 功能关闭或范围收窄停止新提交；补偿恢复沿用已固化的同一父目录对象授权规则，不依赖重新开启功能。
- 恢复 / 撤销状态是有限的私有操作数据，不是路径日志、遥测或无限历史；不保存文件内容和不必要的规则输入。
- 无法恢复或用户已人工处理时，使用 [人工收口协议](../../specs/domains/file-tools.md#manual-resolution-of-recovery-records)；原始证据先导出验证，再在原 unresolved 槽内记录退役并清理已导出的私有控制文件。失败保持阻塞，不触碰用户原件，不把人工关闭标为恢复成功。

### Implementation phases

| Phase | Status | Deliverable | Completion gate |
| --- | --- | --- | --- |
| P0 — 契约 | complete; ready for implementation | 最终设计复核完成；保留普通本地文件 / 文件夹及既定安全约束 | 文档与链接检查通过；任务待实现 |
| P0.5 — 原分类可行性研究 | archived; prerequisite withdrawn | 局部原生观察保留，原 incomplete 结论不改写成 passed | 历史记录，无当前实施依赖 |
| P1 — 纯规则 | complete | 三份 Core 实现、冻结命名计划 / 逐行状态及 52 个纯测试 | 完整 `make verify` 已通过；2026-10-15 已推送 `4469763` |
| P2 — 文件执行 | implemented; local native verified | `BatchRenameService`、同卷暂存、独占发布、恢复日志、人工收口和最近批次撤销 | 普通文件和文件夹的句柄原语、祖先保护、互换 / 大小写改名、并发替换、系统拒绝、恢复冲突、导出收口及崩溃窗口在隔离目录验证 |
| P3 — 原生窗口 | implemented; local native verified | App-owned `BatchRenameController` / `BatchRenameView`，规则与名单模式、完整预览、计数、取消 / 恢复 / 撤销 | 一次只处理一个会话；过期预览不执行；键盘 / 无障碍可操作；原生窗口不打开设置 |
| P4 — Finder / 配置 | implemented; installed Finder pending | 新 `FileTool`、票据及菜单动作，接入操作队列、开关迁移、菜单位置、图标及双语 | 新旧配置默认关闭；完整选区、旧菜单、忙碌请求、授权和退出 / 更新保护正确 |
| P5 — 验收 | local verification; installed/older OS pending | Core / Harness、未签名构建、隔离 native / installed Finder 验收 | 验证已承诺的普通本地文件 / 文件夹场景及失败恢复；其他环境未验证如实记录，不阻塞本地验收 |

2026-10-15 已进入 P2 → P3 → P4 → P5，没有存储归属分类前置关口。P1–P4 类型均已落地，具体结果见本轮证据。执行规则与文件执行器保持在 CorePackage；Finder API 留在扩展，操作窗口和设置留在 App。无需新包依赖。

### Verification scenarios for implementation

- 规则：组合顺序、未匹配、全体不变、部分不变、中文 / emoji / 组合字符、隐藏文件、复合后缀、长名称、空名称、非法字符、编号溢出、名单数量 / 空行、排序映射及过期预览。
- 扩展名：规则和名单均拒绝 `README -> README.txt`、`.env -> .env.local`；普通目录 `Photos -> Photos.2026` 可行；已有后缀保持原字节，未变化旧名与恢复 / undo 不误套用新输出限制。
- 文件系统：大小写敏感 / 不敏感卷、仅大小写改名、交换和环形命名、批次最终目标重复、未变化项目占位、批次外重名、目标被抢占、源 / 父目录被替换、权限错误、不支持独占改名。
- 普通文件夹：单目录项改名、与文件混合批次、目录互换、取消 / 失败恢复；确认不遍历或重命名后代。必要元数据、授权或原生操作失败仍停止；可选归属字段缺失不使正常本地文件 / 文件夹失去入口。
- 保护范围：私有存储本体 / 子树 / 祖先、已知暂存工作区祖先均拒绝；例如真实用户 `Library/Application Support`。普通同名目录仍可用；仅根据已知位置验证祖先关系，不递归遍历。
- 失败恢复：暂存中和发布中失败 / 取消；操作成功与日志更新之间的中断；恢复原名被占用、日志损坏、父目录丢失 / 授权失效。验证保留原件并准确计数，不能仅检查错误码。
- 人工收口：损坏 / 不支持版本记录、对象缺失或人工归位；确认 / 导出取消，导出失败 / 被占用、验证失败、状态变化、退役标记及清理失败；逐个崩溃窗口、重启后显式收口、当前 undo 失效和关闭开关时的入口。验证原始字节保留、失败继续阻塞、用户暂存原件完全不动、手动关闭后可以开始新批次且无应用内档案增长。
- 集成：完整选区与非法混合选择、旧菜单、票据过期 / 重放 / 超限、重复请求、功能关闭、范围收窄、授权取消、冷 / 热启动、设置不被打开、关闭窗口、退出及更新重启。
- 原生交互：中英文、明暗外观、键盘、VoiceOver、1,000 项预览响应和实际变更计数；已有收藏项目改名后仍定位原对象，不能打开旧路径上的替换对象。
- P1 按 HARNESS 运行 `make verify`；后续 App / Finder 实现还需未签名构建及对应原生验收，不能以本轮纯规则测试代替。

## Evidence

### Current P2–P5 evidence (2026-10-15)

基线 `4469763` 加当前主 checkout 改动；本地检查及隔离原生结果见 [本轮验证记录](evidence/2026-10-15-batch-rename-p2-p5.md)。下方 P1 表格是历史结果，不代替当前实现验证。

### Historical P1 evidence (2026-10-14)

Tested commit/worktree: 主 checkout `/Users/daigua/Documents/Ray/FileMint`，`main` / `ea9259bb978b555051e31e7d708d2d3f5d0b6ec1` 加本轮未提交 P1 变更；文件摘要见 P1 验证记录。
Environment: 2026-10-14，macOS 27.2（26B5101f）/ arm64 / Xcode 27.0（27A266a）/ Swift 6.4。运行 P1 和现有仓库验证，未运行批量改名文件执行器、App / Finder 原生验收、安装或发布。

| Check / command | Status | Observed result / evidence link |
| --- | --- | --- |
| 当前契约与相关调用路径静态核对 | passed | 已定位身份检查、单次票据、独占改名、队列及退出 / 更新保护；不构成新功能运行证据 |
| 前序最终设计复核 | passed (historical) | 当时未发现实施阻塞；P1 当前实现及运行结果单独记录 |
| Task / 证据 / SPEC 文本与链接检查 | passed | P1 的 9 个改动文件、3 份 Markdown、70 个本地链接（task 57 个）、结构与空白检查通过；代码 / 测试及最终日志 hash 与验证记录一致；`git diff --check` 通过 |
| `make verify-context` | passed | 随最终 `make verify` 及结果回写后检查通过；22 个上下文文档、129 个本地链接，入口 6986/7000 UTF-8 bytes |
| 前序 P0.5 CLI 编译与本地观测 | passed (historical) | 同一隔离探针在命令沙盒 / 宿主执行完成；只证明 [记录中的元数据观察](evidence/2026-10-14-batch-rename-p05.md#probe-safety-and-raw-results)，本轮未重跑 |
| 原 P0.5 正向非受管分类 gate | withdrawn | 当时结论为 incomplete / not passed；用户已取消该要求，未改写原始观察或宣称分类成功 |
| iCloud / 第三方 provider / NAS 实测 | not-run | 兼容性待后续专项验证，不作为当前本地需求的阻塞条件 |
| `make verify` / Swift / Harness | passed | Core 287（含新增 P1 52）、Images 22、公共 Harness 5/5、CLI 10 及其余离线检查通过；[完整 P1 记录](evidence/2026-10-14-batch-rename-p1.md)含初次失败与修正过程 |
| App / Finder build、signed native QA | not-run | 本轮仅 P1；未验证实际授权、Finder 回调、窗口、真实改名 / 恢复或旧系统运行行为 |

Background references, read during the preceding analysis:

- [MouseBoost 更新历史](https://www.mouseboost.com/zh-CN/releases)：v5.2.8 记录名称列表和指定位置插入等增强；作为需求背景，不是 FileMint 验收证据。
- [MouseBoost 功能文档](https://www.mouseboost.com/zh-CN/docs/features#section-12)：规则与预览能力背景。
- [Apple：批量重命名](https://support.apple.com/zh-cn/guide/mac-help/mchlp1144/27/mac/27)：Finder 已有替换、添加、格式 / 编号等基本入口。
- [Apple：卷能力定义](https://developer.apple.com/documentation/foundation/urlresourcekey?changes=_7)：卷大小写和独占改名能力需检查；实际实现仍需原生验证。

Additional P0 source checks (2026-10-14):

- [Apple：File Provider URL lookup](https://developer.apple.com/documentation/fileprovider/nsfileprovidermanager/getidentifierforuservisiblefile%28at%3Acompletionhandler%3A%29?changes=latest_2)：负查询不能证明其他提供商不存在。
- [Apple：File Provider services](https://developer.apple.com/documentation/foundation/filemanager/getfileproviderservicesforitem%28at%3Acompletionhandler%3A%29)：成功的自定义服务列表允许为空，不是通用的受管 / 非受管判断。
- [Apple：File Provider updates](https://developer.apple.com/documentation/updates/fileprovider)：受管的已知文件夹和外置卷使单靠固定路径排除不充分。

## Handoff

- Remaining work: P2–P4 实现与本地验证已完成；P5 的安装版 Finder、VoiceOver、macOS 13/14 和独立大小写敏感卷运行证据仍待补。NAS / iCloud / 第三方同步兼容性未验证，不重新建立 provider 分类前置关口。
- Delivery scope: P1 已推送 `4469763`；当前新 Core 执行 / 存储及测试、App 窗口 / 授权 / 协调器、Finder / 配置 / 图标 / 双语、隔离 native fixture 与本轮文档均留在主工作区。公共 creation JSON Harness 和原 P0.5 数据未改变，无新增包依赖或生产权限。
- Known limitations: 未安装覆盖生产 App、未改生产数据、未打包或公开发布。未签名构建不是安装验收；signed QA 使用独立身份、容器和合成样本。以本轮证据中的确切来源和环境为准。
- Next action and minimum context: 先读本 task、[本轮证据](evidence/2026-10-15-batch-rename-p2-p5.md)，再按 SPEC router 加载 file-tools / Finder / startup / presentation 和 HARNESS；后续交付或新增 native 验收按用户指令继续。
