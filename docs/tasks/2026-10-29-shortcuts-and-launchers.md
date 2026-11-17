# Task: 快捷指令与启动器联动

Status: 0.8.2 已发布初版，完整原生、首次使用者及素材验收仍有缺项。
Next action: 需要继续验收时，按 [Handoff](#handoff) 选未覆盖场景。初版不包含 Alfred 专用接入。

## 当前入口

- 用户操作：[中文指南](../SHORTCUTS_AND_LAUNCHERS.zh-CN.md) · [English guide](../SHORTCUTS_AND_LAUNCHERS.md)。
- 产品契约：[启动与入口](../../specs/domains/startup.md#shortcuts-and-launchers)、
  [草稿与 URL](../../specs/domains/creation.md#external-drafts-and-launcher-requests)、
  [目录授权](../../specs/domains/finder-permissions.md#external-draft-destinations)。
- [原生验证](../../specs/verification/native-qa.md)、[0.8.2 发布证据](release-0.8.2.md#evidence)。
  应用最低 macOS 13.0，接入功能最低 13.3；编译目标不等于旧系统实机证据。
- 原始设计、阶段划分、三项示例及首次使用者与素材验收标准见[历史方案](https://github.com/FileMintApp/FileMint/blob/46882c07d1eee100cb6c200a89e72201c78a36c8/docs/tasks/2026-10-29-shortcuts-and-launchers.md#14-验证与验收矩阵)。
  以下记录保留当时的环境、结果和失败边界。

## Evidence

Initial design baseline: primary checkout `acd6ca7`；初版设计开始时工作区干净。审核后修订沿用该检出及已有方案/路线图改动，未修改产品源码。
Environment: 2026-10-29；初版与审核阶段仅做文档/静态检查。以下先保留设计阶段证据，P0 实施观察单独列在后表；产品实现与最终用户体验尚未验收。

| Check / command | Status | Observed result / evidence |
| --- | --- | --- |
| 现有实现/契约检查 | passed | 新设计对应当前路由、草稿、窗口及权限边界 |
| 本机 AppIntents SDK availability | passed | `AppIntent`: macOS 13；`supportedModes`: 26；旧前台属性在 26 弃用 |
| 文档本地链接与 diff | passed | 本任务相对链接目标存在；`git diff --check` 无错误；`make verify-context` 通过，22 文档 / 146 本地链接，入口 6976/7000 bytes |
| 审核后方案一致性与文档检查 | passed | 定向复核生成器交接、搜索结果及 URL 校验边界与 P0/验收/handoff 一致；`make verify-context` 通过，22 文档 / 146 本地链接；单独检查本方案及路线图的 30 个本地链接/锚点与行尾空白通过，覆盖未跟踪方案文件 |
| 核心体验方案与路线图检查 | passed | 本轮定向复核三项体验目标、非模态接入指南、授权边界和演示终点一致；`make verify-context`、`git diff --check` 通过；本方案及路线图的 31 个本地链接/锚点与行尾空白检查通过，包含未跟踪方案文件 |
| 交互预览离线检查 | passed | HTML 标签配对、55 个唯一 ID、45 个静态脚本 ID 引用、label/ARIA 目标和显式按钮类型通过；`node --check` 通过，无外部网络调用；正常/冲突/授权状态路径已静态审阅 |
| 交互预览浏览器渲染 | blocked | Browser Use URL policy 拒绝 `file:` 本地预览。未绕过策略；不声称尺寸、明暗色、焦点或实际点击已通过浏览器验收 |
| 初版设计阶段 Swift tests / App build / 签名原生联动 | not-run | 当时是纯方案阶段；不作为当前 P0 实施状态 |
| 首次接入 / 日常单项输入 / 第一眼体验 / 宣传素材 | not-run | 本轮仅明确本版本的完成条件；第 14.3 节真实使用者验收及第 15 节最终版本演示均待实现后执行，既有原型不作为通过证据 |

### P0 实施观察（尚未整体通过）

主检出 `acd6ca7` + 当前未提交 QA 基础设施；macOS 27.2 arm64 / Xcode 27.1 / Shortcuts 10.0 / Raycast 2.10.1.0。探针使用独立 Developer ID 签名、App Sandbox、`filemint-launcher-qa` scheme 和自有容器。日志由探针原生导出到 `build/launcher-integration-verification.noindex/`，只含合成输入。这些证据证明系统边界，不证明尚未实现的生产 parser、草稿种子或集成 UI。

| 项目 | 状态 | 已观察结果 / 本地证据 |
| --- | --- | --- |
| QA 身份和构建 | passed | 独立 launcher-integration kind；Developer ID、arm64、沙盒签名验证通过；App Intents metadata 实际生成且被 Shortcuts 搜索到 |
| 初轮基础设施回归 | passed | `make verify` 完成，日志 `make-verify.log`；URL 探针 6 项离线回归通过。后续构建/启动修正仍需最终复核 |
| URL 交付边界 | passed | AppKit 与 GURL 各 30/30 真交付。两者均规范化裸 `%`、`%2`、`%GG`、裸中文空格；原始事件未增加原文可观察性。非法 UTF-8、未知/重复字段、fragment、NUL 和越限仍会交付。报告 `url-delegate/both-comparison.json`；生产选择既有 AppKit 入口并严格校验实际收到表示 |
| Raycast 真实入口 | passed | 实际导入隔离目录并运行；`FileMint-QA 中文 & # + % ? =` 经 percentEncoded 单次编码后完整显示；重复调用保留编辑过的旧草稿。`p0-shortcuts-raycast-before-deferred-run.mJIasM.jsonl` |
| Intent 目录访问生命周期 | passed | public.folder 选择、返回后持有 scope、显式哨兵创建/清理和取消释放已观察，目录前后均 0 项。`p0-scope-cancel-search-run.tCYZUq.jsonl`。这尚不独立证明 IntentFile 指向源目录而非系统副本 |
| Intent 源目录身份 | not-run | 已补探针 device/inode 只读元数据，主机期望值保存在 `scope-expected-identity.json`；尚需用真实目录输入核对两侧身份，不以空目录前后均空替代 |
| Intent 取消与搜索结果 | passed | 20 秒延迟被 Shortcuts 停止后记录 cancelled-before-presentation，未晚弹；搜索返回 shown/alreadyVisible/busy，复用保留查询，模态时真实报 busy。见同一 run.tCYZUq 日志 |
| 外部会话窗口归属 | passed | 现代前台路径 `run.pG6A6t` 的冷搜索可直接输入；迟到 reopen 聚焦外部搜索；关闭后普通 reopen 打开控制窗。`p0-session-window-ownership-run.pG6A6t.jsonl`。这不证明普通冷启动或另一 API 路线已通过 |
| 普通冷启动 / 原始 13.0 前台入口 | failed | `run.2HrieF` 普通冷启动只记录 pending，之后被工具 reopen 才开控制窗；原始 openAppWhenRun=true 的 Intent 冷启动则在 perform 前开了普通窗。`p0-13_plain-normal-cold-run.2HrieF.jsonl`、`p0-13_plain-intent-cold-run.2HrieF.jsonl`；最新源是这一待修正对照，不能用于产品 |
| 13.3 单一接续候选 | not-run（完整验收） | `run.Ndp0pQ` 已编译签名并最终返回 shown/alreadyVisible，但前台接续分别等待 351.803 秒、224.429 秒；用户反馈未手动确认或切到 QA。原因未定，不能把它算作满足响应与首次接入要求。`p0-13_3-continuation-run.Ndp0pQ.jsonl` |
| 探针问题修复 | passed | Swift 6 static 常量；去除额外 ProvidesDialog；目录参数约束；禁止自动窗口标签。Xcode 自动注册 unsigned staging 曾导致 LinkDaemon teamID 错误，已只撤销 QA 暂存路径；构建退出清理本次暂存注册，发布后注册稳定签名路径 |
| 历史范围：macOS 13 运行 / Alfred | 当时 blocked / deferred | 当时暂无旧系统环境，Alfred 专用接入移至二期；后续曾选择最低 26，现已撤回。当前最低系统须由最终选定单一路线的 P0 定稿，本行不提供旧系统运行证据，Alfred 仍为二期 |

### 2026-10-29 收尾与次日检查

用户要求先稳定当前更改，测试验收明天再来。停止进一步 UI 场景和产品实现推进；保留已导出的证据与明确失败项，不将 P0 宣告完成。生产 `project.yml`、CorePackage 的最低版本和产品源码均未改动。

- 最新 P0 源固定为 plain AppIntent + openAppWhenRun=true、macOS 13.0，用于继续隔离启动问题；没有按系统版本分叉。13.3 和 26 实验的日志各保留原 run ID，不与最新源码混称同一次验收。
- 构建器新增每次运行的源文件快照与 SHA-256 清单，并拒绝捕获期间的输入变化，防止长构建中混入后续编辑。此收尾改动只做静态检查；完整构建/回归留到恢复时执行。
- QA 快捷指令保留在 `FileMint P0 QA 2026-10-29` 文件夹（Draft、Search）；Raycast 仅增加本项目隔离目录中的 `FileMint P0 URL Probe`。它们都是测试入口，不是已上线产品功能。
- QA 已退出，收尾通过 `native_qa.py check-stopped launcher-integration` 只读确认；未强退。恢复时仍先检查运行状态，构建器会拒绝覆盖仍在运行的测试应用。
- 收尾静态检查通过：shell 语法、Python AST、probe plist、`make verify-context` 与 `git diff --check`。按用户要求没有继续交互场景或重跑完整产品验收；最新源快照构建器仍待恢复后实际构建验证。
- 本轮 5 份相关文档的 126 个本地链接/锚点未新增失效项；验收历史已有 32 个被忽略 build 产物链接在本机不可用，与 HEAD 相同，未修改历史证据或宣称它们已恢复。
- 明天先修正/复核普通冷启动与 Intent 启动隔离，再核对目录 device/inode、多行文本、最终选定路径的取消和 busy。P0 完成后才进入生产实现；首次使用者、日常单项输入、第一眼体验与宣传素材仍在后续验收阶段。

### 2026-10-30 恢复验收（仍未整体通过）

基线为主检出 `f4eaa612b43cf4947ddbe4e6b2842fbdb3357cd6`，开始时工作区干净。环境仍为 macOS 27.2 arm64 / Xcode 27.1 / Shortcuts 10.0 / Raycast 2.10.1.0。本轮证据根目录为 `build/launcher-integration-verification.noindex/2026-10-30/`；每次构建保留 `source/manifest.json`，不能混用不同 run 的结果。生产 App、偏好及最低版本均未改。

| 检查 | 状态 | 本轮观察与证据 |
| --- | --- | --- |
| 13.3 系统前台接续 | failed | `run.UoD2Ah` 的真实冷搜索在 `requestToContinueInForeground()` 等待 34.377 秒仍无 outcome/搜索，也未在 Shortcuts 窗口看到确认。主动停止后才由工具 reopen 展示控制窗；不推断停顿的系统内部原因。日志 `p0-13_3-system-continuation-run.UoD2Ah.jsonl` |
| 13.3 主进程执行加 AppKit 展示候选 | passed（部分场景） | `run.zujClS` 使用 `ForegroundContinuableIntent`、`openAppWhenRun=false`，在 perform 内先认领会话，然后走同一 AppKit 展示。真实冷搜索 request→可交互 outcome 为 0.231 秒，热搜索 0.016 秒且返回 alreadyVisible/保留输入，模态返回 busy。该 Intent 会话内普通窗展示次数为 0；不将这些耗时冒充从点击工具到完成的端到端延迟 |
| 取消与已有草稿 | passed | 延迟 20 秒的真实草稿动作在 5.556 秒被停止，取消后 60.578 秒到下一请求期间无展示 outcome；后续正常草稿可打开。重复草稿真实报 existingDraft，已编辑名称保持 `P0 EDITED — preserve.txt`。日志 `p0-appkit-sessions-run.zujClS.jsonl` |
| 多行文本 | passed（P0 参数交付） | Shortcuts 直接带入中文、emoji、换行、`& # + %`、字面量 `{{year}}`、`$()` 和反引号，QA 原生编辑区完整显示；无 URL 桥接/脚本执行。这不证明尚未实现的产品 verbatim writer |
| Intent 源目录身份及返回后的 scope | passed | 新建隔离空目录，两侧 metadata 均为 device `16777230` / inode `148493108`。动作返回后手动 probe 仍持有 scope；显式唯一哨兵创建/删除成功，主机独立确认仍为 0 项；取消记录 scope-released。`scope-expected-identity.json` 与 `p0-appkit-sessions-run.zujClS.jsonl` |
| 普通 Finder 冷启动 | failed | `run.zujClS` 正常退出后由 Finder 真正双击稳定签名应用，仍只记录 ordinary-startup-pending；直到约 3.76 秒后的观察工具 reopen 才展示普通窗。`p0-appkit-normal-cold-before-fix-run.zujClS.jsonl`。因此不能用观察工具打开后看到窗口作为普通冷启动通过证据 |
| 最新回调观测构建 | passed（构建） / blocked（运行） | `run.UrOuCN` 增加公开 should-open-untitled 回调日志以定位普通启动；构建签名成功，当前四份源与该 run 的 SHA-256 清单一致。实际 entitlements 仅 App Sandbox 与 user-selected read/write，见 `final-probe-entitlements.plist`。操作系统锁屏后 CUA 明确拒绝 UI，已请求用户手动解锁；未使用 shell/自动解锁绕过 |
| 完整离线回归 | passed | `make verify` exit 0：381 Swift tests / 38 suites、23 image tests、公共 Harness 5/5，以及全部 Python/受限子进程检查。`make-verify.log`；该轮结束后仅增加启动回调观测，最终源码仍需完成适用复核 |
| 原生自动选择 | blocked（人工边界） | `make native-qa-plan` 只选择 launcher-integration 人工边界；`make verify-native-affected` 如实返回 blocked，无自动 GUI suite；报告 `build/native-checks.noindex/run.0y71z7w0/report.json`。上表实测独立记录，不改写 runner 为通过 |
| 尚未完成 | blocked / not-run | 锁屏阻断最新构建的普通冷启动、冷草稿及最终 Raycast/URL 复跑；macOS 13.3 无实际运行环境。P1–P4 生产接入、三个示例/生成器、真实创建、3 名首次使用者与宣传素材均未完成，不能用 P0 替代 |

机器可读的阶段汇总为 `partial-report.json`，明确 status=incomplete。当前只收敛 P0，不更新 owning SPEC 为产品可用，也不将 API 起始版本当作已验证的最低系统。

锁屏后完成最新源的定向复核：`make verify-context verify-launcher-probe verify-native-qa verify-native-checks-runner` exit 0（22 文档 / 148 链接、6/15/24 项脚本回归），probe plist、构建脚本语法和 `git diff --check` 通过。`native_qa.py check-stopped launcher-integration` 确认 QA 未运行；没有在锁屏时启动 GUI。已请求手动解锁，等待期间未绕过限制，生产功能、未完成的原生场景和首次使用者验收均保留原状态。

### 2026-10-30 解锁后的 P0 收敛与 P1

用户已手动解锁并要求继续。公开 untitled-open 回调未触发，不能作为分类依据；随后在 SDK 公共 `kAEApplicationActivationExpected` 参数发现可靠的本机差异：真实 Finder 双击带 true，Intent 的后台宿主启动不带该参数。最终探针仅在 default launch 且明确要求激活时显示普通控制窗，其余由外部请求认领窗口；删除了等待 activation 的悬置状态，不按进程 PID、私有字段或计时猜测。

最终 `run.JCKtYr` 的四份源/配置 SHA-256 清单与当前 probe 源一致，Developer ID / App Sandbox / user-selected read-write 已从签名核对。所有以下结果均来自这同一构建、macOS 27.2 arm64 / Xcode 27.1 (27A9275)，不继承早期 run 的通过状态。

- **passed**：Finder 真双击的普通冷启动在任何观察工具 reopen 前已自主展示；Intent 冷草稿、冷搜索和冷 URL 不误开普通窗。草稿、搜索成功 outcome 均同时核对可见、key 和文本焦点。
- **passed**：多行中文/emoji/保留字符/字面模板 token；同一 source 目录 device/inode；Intent 返回后的显式哨兵写入/清理；目录 picker 取消保留草稿；取消释放 scope，隔离目录仍为 0 项。
- **passed**：重复草稿报 existingDraft 并保留编辑值；搜索 shown/alreadyVisible/busy 与真实可交互窗口对应；真实 Shortcuts 停止后 118.893 秒观察期间无迟到 outcome。
- **passed**：30/30 AppKit URL 样本各送达一次，首条覆盖冷启动，其余热启动；仅裸 `%`、`%2`、`%GG`、裸中文空格这四类由上游规范化。没有重跑 GURL 对照，旧原文可观察性结果仍归属 10 月 29 日；生产候选选择 AppKit 交付表示，parser 必须独立严格校验。
- **passed**：真实 Raycast 已导入命令的冷调用保留 `FileMint-QA 中文 & # + % ? =`，再次真实调用保留 `P0 Raycast EDITED — keep.txt`。输出 0.10/0.07 秒仅是脚本部分耗时，不是端到端或 p95 指标。
- **passed**：最终 P0 源的 `make verify` exit 0，日志 `make-verify-final.log`；381 Core / 23 image tests、公共 Harness 5/5 和全部脚本/子进程检查。随后 `native_qa.py check-stopped launcher-integration` 确认正常退出。
- **blocked（自动选择器的人工边界）**：`make native-qa-plan verify-native-affected` 没有可代替真实工具交付的自动 suite，报告 `build/native-checks.noindex/run.96xaf56_/report.json`；上面的人工/真实系统边界另附证据，未把 runner 改成虚假通过。

证据仍位于 `build/launcher-integration-verification.noindex/2026-10-30/`：`acceptance-report.json` 为当前 P0 汇总（status=passed-current-environment），`p0-final-*.jsonl`、`url-final-delegate/comparison.json` 和最终签名/entitlements。早期 `partial-report.json` 保留锁屏时的不完整状态，不能作为最终结论。macOS 13.3 实际运行仍 **blocked**；IME/Space/全屏/多显示器、产品辅助功能/三名首次使用者/宣传素材不由 P0 证明。

P1 先更新 Creation、Startup 和 Finder owning SPEC，再新增 `ExternalDraftRequest`、`ExternalDraftRoute`、`ExternalDraftAdmission`：严格收件表示解析、单次解码/限额、精确模板/正文种子、内存有界去重与准备/呈现/完成状态。`ExternalDraftTests` 的 15 项测试场景（含 49 条非法/边界参数化样本）定向通过，包含真实独立文件 fixture 的逐字写入、重名增量和原件保留；日志 `p1-core-tests.log`。这些产品 Core 代码尚未接入原生入口，后续仍需 `make verify`、App build 和产品 fixture 验收。


### 2026-10-30 产品实现与本机技术验收进度

本节补充并取代文末上一版仅到 P1 的当前状态，不改写前面的历史失败/通过记录。
用户最后要求先记录进度、明天继续，因此暂停，不再开启新测试。用户另明确选择
“本轮完成技术验收，3 人体验保留待验收”；这不等于首次使用者体验已经通过，也
不授权发布。

**已实现**：共享严格 URL/typed request/有界内存 admission，App Intents 两个动作，
同一生产创建/搜索面板、目录会话访问与绑定目录对象的安全写入；设置中的三个场景、
生成器、预览 sheet 受控交接、Raycast 原子导出/通用链接、非模态接入及本机接收反馈。
新建双语指南 [English](../SHORTCUTS_AND_LAUNCHERS.md) /
[中文](../SHORTCUTS_AND_LAUNCHERS.zh-CN.md)。单一 API 路线采用
`ForegroundContinuableIntent`、`openAppWhenRun=false` 加 AppKit 展示，开发版主 App /
Finder / Core 最低目标 13.3，不做按 OS 分叉，也没有发布新版。

**本次真实复现后修复**：

- 外部草稿曾可见但 app/key 状态不成立：外部展示使用明确的 AppKit 激活路径，
  返回成功仍要求实际可交互；真实调用已复测。
- SDK 生成的条件参数引用曾使用 Swift case 名而非其不同的 raw value，导致缺少
  Text 字段；case 改为 `text`，新增真实 `extract.actionsdata` 的 12 种条件表单检查。
- 生成器读链接时曾写入 `@Published error`，关闭/清空配置引发 SwiftUI 重复刷新；
  validation 已保持纯读取，5 个有效/无效配置的实际 QA 检查通过，设置关闭不再卡住。
- 预览结束焦点曾回到名称：已等待 sheet key 时序后回到 Preview，实际 AX 焦点通过。
- Shortcuts 会保留隐藏参数旧值，Specified Text 切 Empty Content 曾误报 invalid；
  原生适配器现在仅选择当前模式字段，再进入共享 typed 校验。真实切换后空文件为
  0 字节，原先 70 字节文件完全保留；URL 互斥字段的严格校验不放宽。

**已观察的产品运行证据**（macOS 27.2 arm64 / Xcode 27.1 / Shortcuts 10.0 /
Raycast 2.10.1.0；各 run 只证明自己的源快照）：

| 范围 | 结果与构建 |
| --- | --- |
| 真实原生与 Raycast 创建 | `run.UlFu68` 首次生产端到端场景通过：参数正确，只有明确 Create 后新增文件，Markdown 字节匹配。 |
| 原生临时目录 | `run.LpVnFv` 从未配置到 FileMint 的实际原始目录传入，Intent 返回后仍可创建，空格/换行/中文/emoji/字面 token 精确保留；不是临时目录副本。 |
| 搜索与取消 | 同 run 的 shown/alreadyVisible 保留 query，真实独占/模态 busy；停止延迟准备后 74.55 秒无迟到面板。 |
| 生成器 | `run.1Zp0gH` 预览取消/创建恢复原配置，导出取消不报成功，导出脚本 0700 且被真实 Raycast 自动发现并运行，非模态指南未阻断外部请求，本机 nonce 匹配才报告接收。 |
| 预览生命周期 | `run.FExOfX` 目录选择取消保留草稿，取消草稿才恢复生成器及 Preview 焦点。`run.Xen8zo` 设置关闭后独立草稿保留，旧配置不复活；5 个 validation 读取用例通过。 |
| 普通冷启动 | `run.Xen8zo` Finder 显式打开的 activationExpected=true，在观察工具 reopen 前已显示普通窗。 |
| 日常项目笔记 | `run.GprAyE` 真实 Shortcuts、Raycast 各连续 3 个不同名称，均含真正退出后冷启动；运行只填名称，未重新选模板/位置/正文或授权。六份 Markdown 文件逐字匹配名称。 |
| 上游文本 | `run.GprAyE` 真实工作流“文本 → 打开文件草稿”，正文为魔法变量，固定名称，无第二次输入；创建文件字节精确匹配多行原文。另一次新请求被已有草稿保护，原正文未变。 |
| 碰撞与 Office 校验 | 同名替换确认取消后保留原文件和草稿；另取名称显式创建空文件通过。真实 Word 模板 + 上游文本被明确拒绝，无新草稿/文件；正常 Office 模板创建尚待续验。 |

全部本地日志主目录：`build/launcher-integration-verification.noindex/2026-10-30/`。
当前产品 fixture：`build/native-qa.noindex/launcher-product/FileMintLauncherProductQA.app`，
bundle ID `io.github.daigua.filemint.launcher-product-qa`，URL scheme `filemint-product-qa`。
最新**已运行**的源快照：`build/launcher-product-harness.noindex/run.GprAyE/source/manifest.json`。
其目录为 `/private/tmp/FileMint-Launchers-QA.b7YDAa`（规范化显示 `/tmp/...`），六份笔记
和一份上游文本共 7 个文件；指定原生目录 `/private/tmp/FileMint-Intent-Only-QA.f3sxloo0`
保留原文本及 `FileMint-QA Empty Native.md`。不要清理这些证据目录。

关键证据文件：

- `product-created-files-run.GprAyE.json`：六份日常笔记及上游正文逐字检查均 true。
- `product-daily-shortcuts-hot-run.GprAyE.jsonl` / `product-daily-shortcuts-cold-run.GprAyE.jsonl`。
- `product-daily-raycast-hot-run.GprAyE.jsonl` / `product-daily-raycast-cold-run.GprAyE.jsonl`。
- `product-pause-run.GprAyE.jsonl`：暂停前最后一次元数据导出，pendingWorkers=0。
- `p2-product-real-cancellation-run.LpVnFv.jsonl`、`p3-generator-routing-run.1Zp0gH.jsonl`、
  `p3-render-and-owner-run.Xen8zo.jsonl`：相应边界，不混称最终 run。

**自动化/构建/分发元数据**：

- `make verify` 最近通过：402 Core / 40 suites，23 image / 2 suites，Harness 5/5，
  URL probe 6、Intents metadata 4 及其余脚本/受限子进程检查；
  `product-make-verify-final.log`。最后两处 fixture 小修在此后，尚未重新构建/完整检查。
- 14 项自动原生 suite **分轮均有通过**，不是一次全绿：
  `build/native-checks.noindex/run.2dz2ayyy/report.json` 的 11 项通过；
  `run.f7fub847/report.json` 的 favorite-model / hotkey-sandbox 通过；
  `run.0p1ss_qv/report.json` 的严格 quick-search 在解锁后通过。
  favorite-model 曾漏列共享源，已修复；正式 App 占用 Control-Option-K，正常退出后
  才能测注册，已恢复 `/Applications/FileMint.app` 正常运行，偏好/授权未改。
- 后几次焦点失败核对发现 Mac 再次锁屏，不能据此归因于产品。
  临时的 SettingsWindowController / SharedUI 激活条件修改、搜索 fixture 的等待与
  焦点诊断均已撤回；`scripts/quick_search_checks.swift` 与 HEAD 相同。
- unsigned 主 App/Finder 构建曾通过（`product-app-build.log`），实际 minos 和
  LSMinimumSystemVersion 均为 13.3。较后的 `product-app-build-final.log` 对应含随后
  撤回的临时焦点改动；明天重建当前源码，不把旧产物冒充当前最终包。
- Homebrew 模板从 project.yml 读取最低版本：Ventura 主版本依赖 + 仅版本比较的
  preflight。实际 Homebrew style/readall/metadata 通过，真实 preflight 在模拟
  13.0/13.2.1 拒绝，在 13.3/13.3.1/14.0/27.2 接受；
  `p4-brew-info.json`、`p4-brew-version-boundaries.json`、`p4-brew-metadata.log`。
  未安装/升级应用、未推送 tap；临时校验 tap 已注销，brew 自动开启的 developer
  标记已恢复。模拟版本检查不是旧 OS 实机证据。

## Handoff

- 先比对已保留的真实工具和 URL 观察，再补未覆盖的 Shortcuts 正常 Office 草稿、
  Raycast 首次添加脚本目录、实机权限恢复及脚本管理。自动原生夹具与真实工具
  接入分开记；隔离夹具的废纸篓通过不等于签名沙盒产品的实际删除通过。
- macOS 13.0/13.3 实机、IME、VoiceOver、全屏与多屏等仍需独立环境。
  当时完整 quick-search 原生检查受 Control-Option-K 被占用阻塞；
  后续其他构建的结果见[验收历史](../ACCEPTANCE.md)。
- 保留三名首次使用者覆盖两种工具、草稿首屏五秒理解检查和双语最终演示素材的验收。
  现有示例、素材和本地日志均按原构建归属，具体完成条件见[实施路线](../ROADMAP.md#快捷指令与-raycast-接入验收)。

## 2026-10-31 本机技术复核与剩余边界

本节是最新状态；上面的 10 月 30 日 Handoff 保留为历史停止点。用户要求续上昨天
中断的工作；“本轮完成技术验收，三人体验保留待验收”的决定继续有效。本轮验收基线为
主 checkout `main`、HEAD `f4eaa612b43cf4947ddbe4e6b2842fbdb3357cd6` 的未提交工作区，origin 未变。

本轮产品实现没有改动。`source-comparison-final.json` 比较 `run.GprAyE`、
`run.B5nrJA`、`run.h4wOH4` 与最终 `run.y5O1nO` 的冻结清单，差异均仅为
`FixtureApp.swift`。因此旧的真实 Raycast/日常单项输入证据仍归属旧构建，不混称本轮
重新运行；本轮新增场景分别绑定自己的 run。完整本机汇总是
`build/launcher-integration-verification.noindex/2026-10-31/acceptance-report.json`，
明确 `fullAcceptanceComplete=false`。

### 本轮修正

- 原生条件映射的标准化路径修正在 `run.B5nrJA` 实测通过：12 种位置/内容组合正确，
  3 个当前必需字段缺失均拒绝；不再继承旧 run 的整体 false。
- 截图背景修正首次实测仍失败：`NSBitmapImageRep.draw` 复制了透明区域。改为明确
  source-over 合成不透明背景，重建后逐份目视复核，并对五份主截图做像素抽样，
  最小 alpha 均为 1。`integrations-zh-light.png` 是修正前失败产物，不能作为素材。
- 夹具的语言/外观切换此前仅改临时偏好，外部草稿读的是 committed snapshot。
  现在语言通过 `save()`、外观通过生产 `setAppearance` 保存。最终 `run.y5O1nO`
  的四次切换均记录 saved=true；真实 Shortcuts 新草稿分别显示英文深色和中文浅色。
  这两项修正都只在 QA 夹具；没有改用户正式偏好或产品保存规则。
- 第 4.1 节按已验证的原生隐藏字段语义消除设计期假设；公共 URL 的互斥校验不变。

### 自动化与构建

| 检查 | 状态与证据 |
| --- | --- |
| 最终 `make verify` | **passed**；402 Core tests / 40 suites，23 image tests / 2 suites，公共 Harness 5/5 及全部脚本/受限子进程检查；`make-verify-final.log`。 |
| unsigned `make build` | **passed**；主 App、Finder 可执行文件均存在且仅 arm64；Mach-O minos、LSMinimumSystemVersion 均为 13.3；生产提取出的 Intents metadata 12 种条件表单通过。`app-build.log`、`app-artifacts.json`。后续仅修改夹具，不需要冒充另一份主 App 构建。 |
| template-workflow | **passed**；`build/native-checks.noindex/run.vn5g3lgk/report.json` 的该项通过。该轮随后检测到夹具修正使源快照改变，整体如实 blocked，没有把未执行项改绿。 |
| 其余受影响原生回归 | **passed**；冻结源码后，creation-opening、design-ui、favorite-model、quick-search 四项在 `build/native-checks.noindex/run.9g1vqbzn/report.json` 同轮通过。不是宣称 14 项本轮全重跑。 |
| 最终产品 fixture | **passed**；`product-final-build.log`、`product-final-run.y5O1nO.jsonl`：12+3 原生映射、5 种生成器读取、保存后的语言/外观与真实草稿通过。导出时 pendingWorkers=0；正常退出后 `native_qa.py check-stopped launcher-product` exit 0。 |

### 新增实际运行证据

- **正常 Office**（`run.B5nrJA`）：真实 Shortcuts 从 Word + Template Content 打开
  草稿；创建前隔离目录为空，Command-Return 后生成 32,025 字节独立文件，与内置
  `blank-word-v1.docx` 逐字相同，SHA-256 为
  `91229fe32398a1d5e2e0472ef97cafd62832377250985a8211547e23c65de277`。
  UI 明确说明保留原文档内容/排版；`office-result.json`。
- **手动草稿保护**（同 run）：编辑名称和多行正文后再次真实运行 Shortcuts，明确
  existingDraft；旧名称/正文保留，原生 undo/redo 可撤销并恢复先前编辑。取消后无文件。
- **目录替换与恢复**（同 run）：草稿接收后把仅含合成 Office 文件的本轮目录移开，
  在原路径放空目录；创建正确拒绝，原件及替换目录都不变，输入保留。取消重新选择
  仍保留草稿；明确选回原目录后也不自动写入，第二次 Create 才生成正确 Markdown。
  `directory-replacement.json` 记录独立 inode 和原件哈希；原目录已恢复到原路径，
  空替换目录单独保留，不清理证据。
- **真实上游文本、关闭设置和键盘**（`run.h4wOH4`）：恢复 Workflow Text 为
  Markdown + Specified Text，原魔法变量仍连接。关闭设置不丢已建立草稿；明确创建
  后 72 字节文件逐字匹配空格、LF、中文、emoji 和字面 token。Tab 循环经过格式、
  位置、正文、粘贴、取消、创建再回名称；`upstream-text-final.json`。
- **全屏调用**（同 run）：先清空旧草稿，再通过 Shortcuts 的“进入全屏幕”菜单
  真正进入；运行后草稿 visible/key/active，名称可立即键入 `q.md`。取消不写入，
  “退出全屏幕”菜单确认状态并恢复原窗口；`native-boundaries.json`。快捷键尝试本身
  未触发全屏，不拿它冒充这份菜单实测。
- **视觉**：六份 AppKit 内容视图导出已与实际界面核对，包括中文浅色/英文深色
  接入页与真实 Shortcuts 文本草稿、英文深色生成器，以及最终 run 在内建显示器上
  被可用区域约束的滚动页面。截图不是整屏录像；最后一份也不是精确 760×570 最小
  尺寸证据。`acceptance-report.json` 记录每份实际 run、尺寸和 SHA-256。

本轮证据目录为 `build/launcher-integration-verification.noindex/2026-10-31/`。
合成文件分别保留在 `/private/tmp/FileMint-Launchers-QA.oau97J`（Office 与恢复后的
Markdown）和 `/private/tmp/FileMint-Launchers-QA.DkWcTK`（72 字节上游文本）；最终
builder 的 `/private/tmp/FileMint-Launchers-QA.ak1ZiT` 仍为空。不要清理昨天证据目录。

### 剩余边界与最终停止状态

- **IME / VoiceOver：blocked（工具可观察性）**。用户本轮明确允许临时切换并恢复。
  已查看系统仅安装 ABC 和微信输入法，切换快捷键原本开启；未改输入法列表、键位
  或输入预测设置。工具未提供稳定的候选窗/中英文模式，不能把普通字符或 Unicode
  传递称作组合输入通过。输入源按键探测之后首个请求曾只显示 `.md`，随后直接点击
  Run 及再次 Command-R 均正确带入完整名；尚不能归因，需可观察真实候选窗时复测。
  旁白开关从原始 off 临时开到 on，但服务未报告运行、朗读反馈不可观察，仍不计通过；
  已恢复 off，实用工具正常退出，原本开启的字幕选项未改。系统设置回到原通用页面。
- **连续双语演示：blocked**。系统 Screenshot 录屏组件无法经 CUA 启动，曾返回
  launchd spawn failed；未尝试用其他输入技术绕过工具，也没有用截图序列充当连续录像。
- **额外 Chrome URL 复跑：blocked**。浏览器工具仅允许 HTTP/HTTPS，拒绝自定义
  scheme；没有换浏览器/命令绕过。昨天的真实系统/Raycast 交付仍按其原 run 留存，
  当前 Core 协议/去重检查通过，不将这两者混为本轮 Chrome 成功。
- **保留缺项**：macOS 13.3 实机仍无环境；三名首次使用者及 5 秒理解测试按用户决定
  待验收。完整的多显示器调用迁移、该新页面精确最小尺寸、大收藏 UI、真实 IME/旁白、
  对比度/减少动态效果和 p95 测量没有全部建立证据，不能由泛化的 automation 代替。
- QA 已正常退出，没有 worker；Shortcuts 文本示例恢复为可运行的 Markdown +
  Specified Text。未创建提交、推送、发布、安装新版、同步远端 tap 或查看远端 Actions。
  当前是已覆盖本机检查通过，完整 P3/P4 体验/素材闸门仍未满足，不勾选路线图完成。


## 2026-10-31 最低系统范围纠正

本节覆盖此前设计和执行记录中将接入门槛扩展为应用整体最低版本的决定。用户原意是检测系统是否满足接入功能要求，不满足时禁用该功能；应用整体兼容范围不变。

- 基线：主 checkout `main`，HEAD `6a36217`，工作区最初干净，origin/main 在该提交之前；本轮不提交、推送或发布。
- 选定领域：Startup（版本判断、禁用 UI、注册及外部调用保护）、Distribution（主 App/Finder/CorePackage/QA 最低版本与 Homebrew）、Creation（外部调用错误）、Presentation（双语状态与指南）。
- 应用、Finder 扩展、CorePackage 及产品/通用 QA 编译目标恢复 13.0；P0 隔离实验保留自身 13.3 目标与历史证据。App Intent 与注册使用 13.3 availability 保护。
- 接入功能统一版本判断；不满足 13.3 时设置按钮置灰并说明原因，草稿/搜索/查询/预览/导出入口拒绝工作；原有创建、Finder 与内部快捷搜索仍沿用原流程。
- Homebrew 去掉为功能门槛添加的 13.3 preflight，恢复 Ventura 声明式安装要求；指南与路线图明确两个最低版本。
- 证据目录：`build/launcher-integration-verification.noindex/2026-10-31-system-requirements/`；机器可读汇总 `verification-report.json`，明确完整联动验收仍未完成。

| 本轮检查 | 结果 |
| --- | --- |
| `make project`、`make verify` | **passed**；403 Core tests / 41 suites、23 image tests / 2 suites、公共 Harness 和全部离线脚本/受限子进程检查；`make-verify.log`。Homebrew 回归确认应用最低 13.0、Ventura 声明且无 preflight。 |
| `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` | **passed**；`app-build.log`、`app-artifacts.json`：主 App 与嵌入 Finder 扩展均为 arm64，Mach-O minos 与 LSMinimumSystemVersion 均为 13.0；两个 Intent 的提取元数据 introducedVersion 均为 13.3，12 种条件表单仍通过。 |
| `NATIVE_QA_SUITES=design-ui,quick-search make verify-native-affected` 的 design-ui | **passed**；`build/native-checks.noindex/run.vjcrhi1_/report.json`。实际宿主为 macOS 27.2 / Xcode 27.1，注入 13.0/13.2/13.3，双语原生 accessibility 树确认 9 个接入按钮的禁用/启用及系统要求提示；全局快捷键设置仍可用。低系统直接调用草稿、搜索、快照、预览和命令生成均拒绝，操作预留和收藏读取计数均为 0。 |
| 同轮 quick-search | **failed**；首次在 Escape 后恢复 Templates 查询检查处失败，原始日志保留为 `run.vjcrhi1_/quick-search.log`，不改写为通过。 |
| `NATIVE_QA_SUITES=quick-search make verify-native-affected` 诊断复跑 | **passed**；`build/native-checks.noindex/run.ej9xrruc/report.json`，与首轮的源码/工作区指纹完全相同；键盘、查询/选择恢复、窗口关闭、模态和已有草稿等检查通过。首次失败未复现，原因未定，没有因此修改快捷搜索实现。 |
| `bash scripts/build_launcher_product_harness.sh` | **passed**；`product-build.log`、`product-artifacts.json`：独立签名产品夹具 `run.HpTsJr` 最低 13.0、两个 Intent 元数据最低 13.3；本轮只构建，未用它复跑真实 Shortcuts/Raycast，旧入口证据保留原归属。 |
| macOS 13.0/13.3 实机 | **blocked**：无旧系统环境。注入版本、较新系统上的原生检查和目标元数据均不作为旧系统运行证据；原有体验缺项继续保留。 |

Native planner 因 18 份通用 QA/验证脚本恢复目标字面值而保守选出所有套件；逐份确认这些脚本的唯一变化为 `arm64-apple-macos13.3` → `arm64-apple-macos13.0`，本轮按行为显式缩到 design-ui、quick-search，并另外编译产品夹具，不重放无关 Finder/安装/权限流程。全部 QA 正常退出；产品夹具只构建未启动，没有替换正式应用或改用户偏好。最终任务状态更新后另执行文档检查。

## 2026-10-31 生成器与启动器管理反馈

- 范围：用户截图中的内容下拉框对齐缺陷；导出后 Raycast 接入引导；已导出脚本的编辑、定位与删除；将快捷指令/启动器拆到扩展功能下。沿用 Ponytail Pragmatic 的完整修复和按风险验证原则。
- 契约：startup、presentation、creation、finder-permissions；先更新 owning SPEC，再修改实现。保留应用最低 13.0 / 接入功能最低 13.3 的边界。
- 设计判断：快捷指令编排原生工作流，启动器管理 Raycast 命令与通用 URL，分别放在扩展功能下，比低频集成占据偏好设置顶层更清楚。共享执行链与生成器，分别提供与该入口相关的场景和操作。
- Raycast 官方手册要求在 Settings → Script Commands 中添加脚本目录（Raycast 1 为 Extensions → + → Add Script Directory）：<https://manual.raycast.com/script-commands>、<https://github.com/raycast/script-commands>。当前本机 Raycast 2 的公开 URL 分发器不接受 settings/preferences 路由，实际尝试的两种设置 URL 未打开目标；不使用臆造链接、私有配置改写或 UI 自动化。新导出后通过公开命令 deeplink 打开 Search Script Commands，同时保留剩余设置步骤、目录路径拷贝及 Finder 定位。首次目录接入仍由用户完成，不宣称自动导入。
- 脚本管理仅保存明确导出/选择的文件引用、权限书签、身份与摘要，不复制脚本正文，不枚举目录。旧导出可手动添加；只接受已知生成格式，按数据解析且不执行脚本。编辑恢复原配置并更新原文件；外部修改、替换或链接拒绝覆盖/删除。删除确认移到废纸篓；仅移除列表记录不改文件。
- 计划检查：`make verify`、无签名 `make build`；共享文件修改已审阅，相关自动原生范围为 `design-ui,quick-search`。新增核心回归检查格式还原、同文件更新与旧快照拒绝、索引持久化/损坏保护；原生补充三种内容模式在中英/600与680宽度下的实际控件对齐，以及编辑/保存/外部修改保护。沙盒书签、真实 Raycast 跳转与手动接入另记观察边界。
- 实现补充：编辑保留原脚本的完整请求（包括已有请求 ID），原子更新同一个文件并刷新文件身份和书签；返回编辑后继续更新原文件。本机预览不携带脚本的公共去重 ID，避免预览提前消耗真实调用。脚本正文只存在导出文件与当前编辑器内存中。
- **passed — 离线与编译**：基线 `c36fa36e8745dce9a4fdd12a19676e8df8d3d414` 上的本轮未提交修改；arm64 macOS 27.2、Xcode 27.1 / Swift 6.4。最终 `make verify` 通过（407 Core / 42 suites、23 image / 2 suites、5/5 公共 harness 及脚本回归），`CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO make build` 通过，主 App 和嵌入 Finder 扩展的可执行文件存在。最终日志为证据目录的 `verify-verified.log`、`build-verified.log`。
- **passed — 自动原生**：`NATIVE_QA_SUITES=design-ui make verify-native-affected`，最终报告 `build/native-checks.noindex/run.bc07jt9r/report.json`。包含中英、600/680 宽度 × 三种内容模式的 12 组实际控件左边缘断言；独立页面/低系统禁用；原配置还原、同文件连续两次更新、请求 ID 保留、索引重载；外部改动拒绝覆盖/删除、仅移除列表不改文件；真实废纸篓事务和原字节保留，随后将该唯一合成文件恢复到夹具目录，未遗留该轮 Trash 项。最终截图和报告已复制到本轮证据目录。
- **passed — 保留的沙盒实测**：不可变产品夹具 `run.MAO4Rc`、独立身份 `io.github.daigua.filemint.launcher-product-qa`。用保存面板导出合成脚本，自动打开 Raycast 的 Search Script Commands 确认页；正常退出/重启后列表恢复，直接编辑并更新原文件，无需再次选择文件；添加同一已有脚本后仍只有一条记录；删除确认的取消保留条目和文件；脚本实际模式为 0700、标题字节符合更新结果。已正常退出 QA。最终源码后来增加非空 ID 的还原/预览隔离，并将确认提示从“首次”改为“打开时”；上述实测脚本无 ID，所测导出/书签/更新行为未变，因此保留原 run 归属，不宣称最终源码重新执行了沙盒实测。具体观察为 `product-observations.json`。
- **failed retained → corrected**：`run.1yk59hao` 的 design-ui 在 12 组布局通过后，因夹具用 `/private/tmp` 与 Foundation 标准化的 `/tmp` 直接比较而失败；修正夹具预期后 `run._fmiqpnb` 通过。补充 Trash 回归的 `run.s_19sqin` 在合成文件创建前查询其卷 Trash 位置，返回 Cocoa 3328 / POSIX 2；修正检查顺序后最终 `run.bc07jt9r` 通过。原始失败报告均保留。
- **blocked — 完整 quick-search 原生检查**：`run.1yk59hao` 的 quick-search 在第一个建议键注册断言失败；独立 Carbon 诊断同一 Control-Option-K 返回 -9878（SDK 定义的已存在热键错误）。未改动用户配置、未终止占用者，也未将该项重跑成绿。新增页面的导航和显示已由最终 design-ui 覆盖；完整搜索回归仍需空闲组合键环境。
- **not-run / 原有缺项**：本轮没有给 Raycast 添加目录或宣称完成导入；没有提交沙盒实际移入废纸篓操作（真实事务自动检查使用独立 design-ui 夹具）。没有 macOS 13.0/13.3 实机，原有 IME/旁白/首次使用者/素材缺项不因本轮 UI 回归通过而关闭。终端读取 QA 私有容器索引被系统拒绝，持久化观察来自 App UI，未绕过容器访问限制。
- 证据汇总：`build/launcher-settings-feedback.noindex/2026-10-31/verification-report.json`。本轮未提交、推送、安装或发布。

## 2026-10-31 本地 Debug 构建与安装

- 用户明确要求构建本地 Debug 并安装；此操作不走发布、远端 CI 或 Homebrew 同步流程。
- **passed — 构建/签名**：按 `docs/DEVELOPMENT.md` 用 Debug 配置和 `ENABLE_DEBUG_DYLIB=NO` 构建，保留 `DEBUG` / `-Onone`，应用版本仍为 0.8.1（30）。使用现有 Developer ID（Team 8S66M2ZLD5）签署主 App、Finder 扩展及嵌套组件；源副本、安装临时副本和最终安装副本均通过 `verify_bundle.sh` 与 Developer ID 检查，保持 macOS 13.0、arm64、原沙盒权限。
- **passed — 替换/保留**：通过 App UI 正常退出原 FileMint 并核对进程停止，原应用以 `previous-FileMint.app.zip` 备份；ZIP 全量 CRC 和原可执行文件 SHA-256 一致。验证新副本后替换 `/Applications/FileMint.app`，安装副本主 App/Finder 可执行文件与源副本哈希相同。安装器未读写用户配置、模板或目录书签。
- **passed — 本机启动/界面**：安装后丢弃旧电脑操作绑定，从 Finder 显式打开已安装 App；确认“扩展功能”下有独立快捷指令/启动器入口、已创建脚本管理区；实际打开生成器并展开“模板内容”，观察下拉框左对齐，再取消返回启动器页。未创建或导出用户文件。
- **passed — 路由/注册**：只运行一个正式 FileMint 进程，执行位置为 `/Applications/FileMint.app/Contents/MacOS/FileMint`；`filemint://` 的默认处理 App 为 `/Applications/FileMint.app`。已注销已知 Debug/Release 开发副本注册并注册安装副本；Finder 扩展查询只返回一个已启用插件，路径位于已安装 App 内。没有通过 pluginkit 改动启用状态，没有回放完整 Finder 回调检查。
- 证据：`build/local-debug-install.noindex/run.SWUw8Y/installation.json`，同目录的 build/sign/verify 日志、`process-info.json`、`finder-registration.log` 和原应用备份。Debug App 保持运行，停留在启动器页。没有提交、推送或发布。

## 2026-10-31 后续界面修正与重新安装

- 快捷指令与启动器页共用的“限制与帮助”展开内容改为撑满可用宽度并左对齐，多行文字显式采用 leading 对齐。
- 快捷搜索用统一的选中项滚动定位：选回首项时定位首个分组标题的顶部，其余项目保留原来的最小可见滚动；重新打开面板恢复首项时采用同一逻辑。没有改变结果顺序、键盘选择规则或草稿执行路径。
- 用户要求不跑测试，并要求后续本地构建安装不做校验。两处修正已用 Debug / `ENABLE_DEBUG_DYLIB=NO` 编译、按原身份签名，备份旧 App 后安装到 `/Applications/FileMint.app`；没有追加测试、签名/包校验或 UI 验收，不把此前的原生结果当作本次修正的运行证据。
- 最近安装记录：`build/local-debug-install.noindex/run.ygBp29/installation.json`，同目录保存构建/签名日志和旧 App 备份。原有完整搜索及平台/体验验收缺项继续保留。
