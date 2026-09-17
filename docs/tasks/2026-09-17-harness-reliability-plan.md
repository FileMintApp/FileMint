# Harness 可靠性修复方案与实施记录

Status: complete
Next action: 无剩余实现或验证事项；改动尚未提交。

用户已要求立即解决问题，不考虑兼容性、不保留历史包袱。实现只保留新格式和新入口，
所有仓库内调用方一起更新。当前契约以 specs/verification/core.md 为准；
下文调研证据保留其原始时间点，实现结果另行记录。此前按需上下文改造保留。

## 目标与范围

成功退出必须表示：输入有效、至少执行一个用例、所有声明的检查均完成且通过，
并且本次运行的文件准备与清理没有发生未处理的错误。

本轮建议修复 JSON 用例解析、前置文件准备、结果断言、CLI 报告与退出码，
以及 Harness 自身的自动回归。不引入第三方 SPEC 框架、JSON Schema 引擎或运行时依赖。
不修改文件创建产品逻辑，不扩展 Finder/UI 自动化，也不把所有 Swift 测试改写成 JSON。

已加载的上下文：

- [Harness 验证入口](../../specs/HARNESS.md)与[Core 验证说明](../../specs/verification/core.md)。
- [创建契约](../../specs/domains/creation.md)：确认原文内容、命名和不覆盖约束。
- [用例模型与 Runner](../../CorePackage/Sources/FileMintCore/HarnessCase.swift)、[CLI](../../CorePackage/Sources/FileMintHarness/main.swift)、[现有 Harness 测试](../../CorePackage/Tests/FileMintCoreTests/FileCreationHarnessTests.swift)。

## 调研证据

日期：2026-09-17。基准提交：`9d32ad2032dd88f0f5ba09780ead67b843350219`。
环境：macOS 27.0、Apple Swift 6.4、arm64；通过工程 Makefile 使用完整 Xcode。

`make verify` 基线通过：60 个 Swift 测试、5 个 JSON 用例和上下文文档检查。
在本次构建的 CLI 上执行了 19 组探针，另以独立 Swift 程序核对解码与字符串语义。
[原始结果、输入及源文件 SHA-256](../research/2026-09-17-harness-probes.json)保留为证据。
所有文件写入探针都在自行创建的临时目录中运行，并先确认 `TMPDIR` 生效；
越界测试使用的哨兵仍位于该隔离临时目录内，没有使用用户文件。

| 编号 | 发现与实际结果 | 依据与影响 |
| --- | --- | --- |
| F1 | `[]` 退出 0，没有任何输出 | CLI 只检查是否有失败结果；单测的 `results.allSatisfy` 对空数组也为真。 |
| F2 | 未知断言、拼错的可选输入、未支持的 `collisionStrategy` 都可输出 PASS | 合成的 Codable 解码忽略未知字段；用户意图没有被执行。 |
| F3 | 同一对象重复 `expectedFileName`：第一个正确、第二个错误时仍 PASS；转义形式的重复键也一样 | 本机 Foundation 保留第一个值；普通解码后的键集合已经丢失重复信息。 |
| F4 | 重复/空用例名称、重复已有文件名都被接受 | 不直接证明断言错误，但结果身份和前置条件缺少有效性约束。 |
| F5 | 已有文件写成 `missing-parent/seed.txt`，文件准备失败后仍 PASS | `FileManager.createFile` 的返回值未检查，测试实际没有运行在声明的初始状态上。 |
| F6 | 已有文件写成 `../../outside.txt`，当前用例目录之外的临时哨兵被清空，仍 PASS | 这是 Harness 准备文件的路径问题；不是 `FileCreationService` 的产品命名规则失效。 |
| F7 | 预先放在 `TMPDIR/FileMintHarness` 的测试标记会被删除 | CLI 启动即删除固定工作目录，缺少每次运行的所有权隔离。 |
| F8 | 不存在的模板和损坏 JSON 导致进程信号终止，Python 记录退出码 `-5` | 未捕获的顶层异常没有形成受控错误报告；负值表示本次环境中的信号终止。 |
| F9 | 内容不匹配正确退出 1，但只打印文件名 | 有失败信号，缺少失败断言、预期值、实际值和执行汇总。 |

并发证据必须保留边界：4 个进程各 80 个用例，以及确认首个进程已创建用例目录后
启动第二个进程、各 2,000 个用例，这两组均通过。**本轮没有复现并发运行失败。**
固定目录删除行为已经单独复现；并发互相影响仍是结构性风险，不能写成已复现的崩溃。

另有两点不能误判：

- `expectedContentContains: []` 当前表示没有内容断言，并不等于期望空文件；现有前两个用例就是这样。
- Swift `String ==` 可以把不同 Unicode 编码视为相等。既然产品要求精确 UTF-8，未来的 exact 断言必须比较 `Data`。

## 官方依据与实现陷阱

1. Swift 的 `allSatisfy` 明确规定空序列返回 true，因此必须单独检查套件非空。
   [Swift 标准库源码](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/SequenceAlgorithms.swift)
2. `allKeys` 只返回能转换为当前 CodingKey 类型的键。本机探针中枚举 CodingKeys
   只看到 `known`，动态 CodingKey 才能看到 `unexpected`。
   **仅给模型添加 CodingKeys，或在枚举容器上检查 allKeys，都不能完成未知字段校验。**
   [Swift Codable 源码](https://github.com/swiftlang/swift/blob/main/stdlib/public/core/Codable.swift)
3. JSON 标准建议对象内名称唯一，并说明重复名称的处理可能因实现而异。因此不能依赖
   本机“第一个值生效”的偶然结果。扫描时还要识别转义后相同的键。
   [RFC 8259 第 4 节](https://www.rfc-editor.org/rfc/rfc8259.html#section-4)
4. Swift 字符串相等使用规范等价；本机 `é` 与 `e` 加组合重音的字符串比较为 true，
   UTF-8 Data 比较为 false。精确内容断言不得 trim、换行归一化或 Unicode 归一化。
   [Swift 官方语言指南源文](https://github.com/swiftlang/swift-book/blob/main/TSPL.docc/LanguageGuide/StringsAndCharacters.md#string-and-character-equality)

## 推荐设计

### 1. 单一校验入口，整套校验后再写文件

新增共享的 `HarnessSuite.load(data:)` 路径，CLI 和 Swift 测试必须使用它。
流程为：有界读取 → 原始 JSON 结构检查 → 严格解码 → 整套语义校验 → 执行。
所有步骤使用同一份不可变输入字节，避免校验一次、执行时又读取另一份文件。

- 整套用例有效前，不创建运行目录或准备文件。
- 顶层、case、已有文件、expect、content 每一层都通过动态 CodingKey 校验允许/必需字段。
- 未知字段、缺失必需字段、错误类型、不支持的版本/枚举值均为输入错误。
- `requestedFileName` 允许省略或显式 null；其他字段不通过隐含默认值吞掉错误。
- `cases` 必须非空；case ID 必须非空、稳定且唯一；显示名称非空，可以在不同 ID 下重名。
- 模板必须存在；已有文件名不能重复；内容模式和该模式的字段必须一致。
- Runner 只接受不可变的已校验套件；删除旧入口，不保留适配器。

重复 JSON 键不能靠解码后的 Dictionary/allKeys 发现。建议增加一个小型 Swift
原始 JSON 键扫描器：按对象作用域维护键集合，识别字符串与转义、数组和对象嵌套，
按解码后的键拒绝重复。Foundation 继续负责数据解码与类型判断。
不使用正则表达式寻找重复字段，也不引入一套通用 JSON 框架。
扫描器是本次新增逻辑中风险最高的部分，必须有独立边界回归。

建议首版明确限制输入为 UTF-8、最多 1 MiB、嵌套最多 32 层、最多 1,000 个用例。
CLI 读取时按上限截断检测，避免先无限读入；超限统一报输入错误。
现有 5 个用例远低于这些限制，实际并发回归无需使用调研时的 2,000 用例压力规模。

### 2. 一次性升级为 v1 用例格式

建议在审核通过后的同一批改动里升级格式并迁移现有 5 个用例：

```json
{
  "schemaVersion": 1,
  "cases": [
    {
      "id": "increment-text-without-overwrite",
      "name": "已有文本文件时递增命名并保留原文件",
      "templateID": "plain-text",
      "requestedFileName": null,
      "existingFiles": [
        { "name": "Untitled.txt", "content": "existing content\n" }
      ],
      "expect": {
        "fileName": "Untitled 2.txt",
        "content": { "mode": "exact", "value": "" }
      }
    }
  ]
}
```

内容模式首版只支持两种：

- `exact`：只允许 `mode`、`value`，使用 UTF-8 字节完整比较；空字符串合法且表示空文件。
- `contains`：只允许 `mode`、`values`；数组和每个片段必须非空，逐项做明确的 UTF-8 字节片段检查。
  该模式只证明片段存在，报告中不能称为精确内容验证。

**本轮不提供隐式或显式 skip。** 这是对前次口头建议的收紧：目前 5 个用例都能给出
确定内容，没有必要增加绕过内容检查的能力。后续确有仅验证文件名的场景，再设计带理由的显式模式。

现有用例的内容期望直接固化为独立常量：两个文本用例为 `""`，Markdown 为
`"# Untitled.md\n\n"`，JSON 为 `"{}\n"`，Swift 为 `"import Foundation\n\n"`。
禁止调用正在测试的 `TemplateRenderer` 生成 expected，否则实现和断言可能一起出错。
碰撞用例的已有文件写入非空哨兵，并校验创建后仍保持原字节。

首版 JSON 仍只执行内置模板的 increment 创建。未知 `collisionStrategy`、`expectedError`
应报错；fail/replace、符号链接、并发创建和 verbatim 输入继续由现有 Swift 测试覆盖。
这样先收紧验证可信度，不同时构建通用测试 DSL。

### 3. 明确文件准备与执行隔离

- 使用系统安全临时目录创建能力，为每次运行分配唯一目录；每个 case 再使用独立子目录。
- 只清理本次持有的运行目录；禁止启动时删除固定 `FileMintHarness` 或其他运行的目录。
- `existingFiles.name` 与 `expect.fileName` 只允许单个普通文件名：拒绝空名、`.`、`..`、
  绝对路径、路径分隔符和控制字符；不把错误 fixture 路径静默净化为另一个文件名。
- `requestedFileName` 是被测输入，保留 `api/config.json` 等用例来验证产品净化逻辑，
  **不能把 fixture 的路径限制误套到被测输入上。**
- 文件准备采用排他写入；任何创建失败或实际文件名别名冲突都使该 case 进入 setup error，
  不执行产品调用。静态名称不同但文件系统视作同一名称时，也不能静默覆盖。
- 执行后校验最终文件名、显式内容断言、所有已有文件保持原字节，以及目录条目恰好为
  原有文件加本次输出。检查只发生在 Harness 自己的临时目录，不扫描用户目录。
- 先验证返回 URL 仍位于本 case 根目录，再读取输出；不能为了报告失败去读根目录外的文件。
- 正常退出及捕获到的错误路径都清理本次目录；清理失败必须使套件非零退出。
  不承诺 SIGKILL 等不可捕获终止后的立即清理，也不能因此让下次运行删除其他目录。

### 4. 完整结果与稳定退出码

保留默认的人类可读输出，并增加 `--format json`。不新增网络、上传或第三方服务。
结果由同一份报告模型生成，不分别计算“文本版是否通过”和“JSON 版是否通过”。

报告记录 case ID、状态、实际执行的断言、失败路径、预期/实际摘要和套件汇总。
内容差异显示字节数、首个差异位置和有界转义预览，避免一次输出整个大文件。
JSON 模式的 stdout 只输出一份完整 JSON；正常输入错误不能以 Swift fatal error 结束。

| 退出码 | 约定 |
| --- | --- |
| `0` | 有效非空套件，所有 case 与声明断言都完成且通过，且准备/清理无错误。 |
| `1` | 产品行为与成功预期不符：名字/内容/副作用断言失败，或有效 case 的创建调用意外失败。 |
| `2` | 输入读取、解析、校验、fixture 准备或运行器清理错误。 |
| `64` | CLI 使用错误，保留当前 usage 约定，例如未知参数或不支持的输出格式。 |

同一运行同时出现断言失败和运行器错误时，退出码 2 优先，并保留所有已有结果。
整套输入校验失败时执行数为 0、状态为 error，不能以“0 个失败”暗示成功。
输入已验证后，各 case 隔离执行，记录单个 case 的失败并继续其他 case；报告不得因
后面的异常丢失已经完成的结果。进程受信号终止也不能在上层被当作成功。

### 5. 两层自动回归

**Swift 层：** 新增 Harness 专项测试，直接验证严格解码、语义校验、文件准备、断言和结果聚合。
原有 `harnessCasesPass` 改用共享 Suite loader；fixture 路径从 `#filePath` 定位，
避免依赖当前工作目录向上搜索到另一份 checkout 的用例。

**真实 CLI 层：** 新增 Python 标准库脚本，通过 subprocess 启动本次构建的真实二进制，
验证退出码、文本/JSON 输出、临时目录隔离和完整清理。为子进程设置超时，失败时保留诊断。
不在 Swift 单测内部递归执行 `swift run`，避免 SwiftPM 构建目录锁和测试进程互相等待。

增加 `make verify-harness-cli`，先构建 Harness 并使用 `swift build --show-bin-path`
取得同一构建配置的产物路径，再运行 CLI 回归。二进制缺失或构建失败必须失败，不能跳过。
现有 `make verify` 纳入该目标，因此当前 PR CI 自动执行；无需修改发布/签名工作流。
独立的运行目录也应允许重复或并行验证，不能用全局串行化掩盖共享目录问题。

## 验收矩阵

| 检查 | 修复后的结果 |
| --- | --- |
| 迁移后的 5 个现有场景 | 全部通过，内容按独立常量精确检查。 |
| 空 cases；旧数组格式；未知 schemaVersion | 输入错误，退出 2，执行数为 0。 |
| 顶层、case、fixture、expect、content 的未知字段 | 输入错误，给出字段路径；不得忽略。 |
| 拼错 requestedFileName；模式不支持；exact 带 values；contains 带 value | 输入错误，退出 2。 |
| 重复 JSON 键，含转义后的重复键和不同嵌套层 | 同一对象的重复键拒绝；不同对象各自同名合法。 |
| 内容字符串内出现引号、冒号、花括号、转义反斜杠 | 正常解码，不能被键扫描器误判。 |
| 错误类型、缺字段、无效 UTF-8、损坏 JSON、超限输入 | 受控退出 2，无 fatal error、无开始准备文件。 |
| 重复/空 ID、空显示名称、不存在的模板 | 输入错误；不同 ID 的同名描述仍能明确定位。 |
| contains 的空数组/空片段；缺少 content | 输入错误；exact 的空 value 则合法且要求零字节。 |
| 最后一个 case 输入无效 | 整套拒绝；前面的有效 case 也没有产生文件副作用。 |
| 内容多/少一个换行、CRLF 与 LF、首尾空格、规范等价但字节不同的 Unicode | exact 断言失败，退出 1，并报告字节差异。 |
| 错误文件名、错误片段、已有文件被修改、额外文件 | 断言失败，退出 1。 |
| 单测强制 fixture 写入失败 | 不调用产品服务；setup error，套件退出 2。 |
| fixture 的 ../、绝对路径、控制字符、重复/别名文件名 | 拒绝或明确 setup error；外部哨兵不变。 |
| requestedFileName 为 api/config.json | 继续测试产品净化，正确输出 api-config.json。 |
| 输出 URL 越出 case 根目录 | 断言失败；不读取或清理该外部路径。 |
| 固定旧目录中已有哨兵；两个运行共享同一 TMPDIR | 旧哨兵不变，每个运行只持有和清理自己的唯一目录。 |
| 一个 case 失败、一个 case 成功 | 两个结果都保留，汇总与退出码正确。 |
| 捕获错误后的清理；强制清理失败 | 正常错误路径清理成功；清理失败不允许退出 0。 |
| 从仓库之外的 cwd 运行 CLI | 使用明确传入的 fixture 路径正常执行。 |
| 默认文本与 --format json；未知选项 | 两种报告状态一致；未知选项退出 64。 |
| CLI 回归二进制不存在、子进程超时或信号退出 | 回归脚本自身失败，不跳过、不转为成功。 |

这里的 Harness 自测与现有产品测试分别证明不同事情；用例数量增加不等于产品覆盖面增加。
故意构造失败输入应使被测 CLI 非零退出，而验证这些退出码的回归脚本整体通过。

## 文件改动与实施顺序

1. 先更新 `specs/verification/core.md` 的 Harness 格式/错误契约，以及
   `specs/HARNESS.md` 中的验证入口说明；根入口不增加这份长方案或完整格式说明。
2. 调整 `HarnessCase.swift`，按职责拆出必要的 Suite/解析/报告辅助文件；
   保留现有 Package target，不进行无关模块迁移，不改 `FileCreationService` 等产品逻辑。
3. 修改 CLI：受控错误、唯一工作目录、同源报告模型和退出码。
4. 同批迁移现有 5 个 JSON 用例与原单测，增加 Harness 专项 Swift 测试。
5. 增加真实 CLI 回归脚本与 Makefile 目标；验证所有验收矩阵项目和 `make verify`。
6. 更新此任务的执行证据；报告通过/失败/未执行项，不宣称原生 Finder 已因此验收。

## 范围与方案自检

- 用户明确不考虑兼容性：删除旧数组格式、旧字段及旧 Swift Harness 入口；所有调用方直接更新。
  不添加迁移器、兼容别名或双轨执行路径。应用偏好与用户文件不在本次变更范围。
- 未选择“只加非空判断”：它无法解决未知字段、重复键和错误前置条件。
- 未选择“只在 Python/Makefile 前置校验”：直接运行 CLI 或 Swift Runner 会绕过保护。
- 未选择新增通用 JSON Schema 依赖：未知字段与语义规则可以在共享 Swift loader 中完成；
  Schema 引擎本身也不保证解析器保留重复键信息。
- 原始键扫描器的转义/嵌套是主要实现风险，必须先写失败回归，再实现，并检查正确 JSON
  字符串不会被误识别为结构；不只测试一条重复键样例。
- 本次范围不包含 JSON 产品预期错误 DSL、二进制模板、属性测试框架、全仓 mutation testing、
  App/Finder 编译门禁或 UpdateModel 集成测试；它们可独立规划，不与已确认的假通过漏洞混在一起。
- 全部通过仅证明声明的行为和 Harness 执行契约，不能证明需求覆盖完整或 Finder 原生交互正常。

## 实施状态

- 已获用户授权：直接修复，不保留兼容层。
- 旧 `FileCreationHarnessCase`、`HarnessCaseResult`、数组 Runner 入口以及旧字段已从源码删除。
  5 个正式用例直接使用新契约，全部采用独立常量的 exact 断言。
- 解析、报告、执行分别位于 `HarnessCase.swift` / `HarnessJSON.swift`、
  `HarnessReport.swift`、`HarnessRunner.swift`；CLI 与单测使用同一个 Suite loader。
- 原始 JSON 键扫描、全套校验、排他 fixture 写入、唯一私有目录、非符号链接文件描述符读取、
  目录替换检查、已有文件保护、受控退出码与文本/JSON 同源报告均已实现。
- 基线 `make verify`：60 个 Swift 测试、5 个 JSON 用例通过。
- 最终 `make verify`：79 个 Swift 测试（6 个套件）、5 个正式 JSON 用例、
  10 组真实 CLI 回归全部通过；包含四进程并发、错误退出码、输入越界、哨兵保护、
  UTF-8 字节反例、构建产物缺失/超时/信号、setup/cleanup 故障注入和磁盘文件名别名。
- 上下文检查通过：17 个文档、85 个本地链接，入口 5,783 / 7,000 UTF-8 字节。
  `git diff --check` 通过；最终编译无新增 warning/error。
- Unicode CLI 对照使用明确的分解形式文件名，避免把 macOS URL 对组合形式的规范化
  误判为 Harness 失败；另一种显示等价但字节不同的内容必须被 exact/contains 拒绝。
- 产品创建、命名、模板渲染、App、SharedUI 和 Finder 实现未修改。未进行原生 UI 验收，
  也不将 Harness 自测数量视为新增产品场景覆盖。
- 提交/发布：未请求，不执行。
