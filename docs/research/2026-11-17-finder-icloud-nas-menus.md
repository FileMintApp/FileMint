# iCloud Drive 与 NAS 的 Finder 菜单调研

调研日期为 2026-11-17，核对 FileMint 源码 `e7170aa` 及 Apple 的公开接口。

## 能否开启这两类菜单

本次未找到能保证 FileMint 菜单出现在 iCloud Drive 或 NAS 入口的公开设置或 API。Finder Sync 可以用 `directoryURLs` 注册实际目录。Finder 在符合条件的目录、选中项目或指向受监视目录的侧栏项目上请求扩展返回菜单。Apple DTS 进一步说明，同一目录的扩展可能相互竞争，嵌套目录和部分系统目录也有限制。公开资料没有给出对 iCloud Drive 或 NAS 下每个子目录的一律禁止或支持结论。[Finder Sync 指南](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html) · [目录注册接口](https://developer.apple.com/documentation/findersync/fifindersynccontroller/directoryurls) · [Apple DTS 说明](https://developer.apple.com/forums/thread/756711)

- **iCloud Drive**。系统侧栏入口与其中可选的实际文件夹应分别判断。同一论坛讨论有开发者报告某些 iCloud Drive 路径无法监视，这条报告来自第三方开发者。File Provider 的菜单动作只为该提供方的内容定义，不能借此给系统自带的 iCloud Drive 增加 FileMint 菜单。[File Provider 菜单动作](https://developer.apple.com/documentation/fileprovider/nsfileprovidercustomaction) · [Apple 的 macOS File Provider 说明](https://developer.apple.com/videos/play/wwdc2021/10182/?time=989)
- **NAS**。Finder 的「网络」或服务器入口用于连接和登录。连接后选择的共享卷或文件夹才是文件操作的目标。服务器允许读写后，macOS 仍可要求该 App 的文件访问许可。挂载成功也无法据此确认 Finder 会在指定入口请求 FileMint 菜单。[连接共享服务器](https://support.apple.com/en-nz/guide/mac-help/mchlp1140/27/mac/27) · [Apple 平台安全的文件访问规则](https://support.apple.com/en-ie/guide/security-pdf/secddd1d86a6/web)

## 菜单回调与访问权限

Apple 公开支持用 `NSOpenPanel` 让用户明确选择目录，再用安全范围书签保存访问。iCloud Drive 和网络卷也受 macOS 的文件访问隐私控制。文件权限、服务器权限及占位文件的可用性仍影响实际读写。由此能判断授权途径，无法把缺少菜单直接归因为权限不足。[macOS App Sandbox 文件访问](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox) · [Apple 平台安全的文件访问规则](https://support.apple.com/en-ie/guide/security-pdf/secddd1d86a6/web)

FileMint 的「Finder 与文件夹」保存注册路径，扩展收到回调后根据目标 URL 和设置范围生成菜单。「文件访问」保存主 App 执行操作时可用的授权。这两条链路都没有按存储名称区分的专用入口。[Finder 实现](../../FinderSyncExtension/FileMintFinderSync/FinderSync.swift) · [目录和权限契约](../../specs/domains/finder-permissions.md#folders-and-permissions)

## 处理结果

从公开待办、使用指南、验收清单和权限迁移夹具中移除这两类专项场景。保留通用目录回调和授权规则。旧版权限迁移原型的 NAS 探针当时未运行，批量重命名的 P0.5 隔离调研也未测这两类真实入口。本次为官方资料及源码核对，菜单交付情况没有新增实机观察。[旧原型的历史记录](https://github.com/FileMintApp/FileMint/blob/e7170aa3c105f3efb6233e48f6ea3c1df9255b51/docs/tasks/access-migration-prototype.md#evidence) · [P0.5 调研](../tasks/evidence/2026-10-14-batch-rename-p05.md#finder-sync-distinction)
