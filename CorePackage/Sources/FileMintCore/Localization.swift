import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system:
            return "Follow System"
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
    public func resolved(preferredLanguages: [String]? = nil) -> AppLanguage {
        guard self == .system else { return self }
        for language in preferredLanguages ?? Locale.preferredLanguages {
            let prefix = language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            if prefix == "zh" { return .chinese }
            if prefix == "en" { return .english }
        }
        return .english
    }

}

public enum FileMintTextKey: String, CaseIterable, Sendable {
    case pasteImageFile, clipboardImageHint, clipboardImageUnsupported, clipboardImageTooLarge, clipboardImageFailed
    case imagePreview, imageFileName
    case defaultFileName, defaultTemplate, makeDefaultTemplate, selectedTemplate, noTemplate
    case importDocumentTemplate, documentTemplate, documentTemplateHint, documentUnsupported
    case documentTooLarge, documentInvalid, documentUnavailable, documentImportFailed, documentDraftEdited
    case followSystem
    case appearance, theme, lightAppearance, darkAppearance
    case launchAtLogin
    case showMenuBar
    case automaticallyCheckForUpdates
    case automaticUpdateHint
    case viewUpdate
    case loginNeedsApproval
    case loginInstallFirst
    case loginRegistrationFailed
    case openLoginSettings
    case retry
    case fullDiskAccess
    case openFullDiskAccess
    case fullDiskAccessStatus
    case fullDiskAccessStatusHint
    case fullDiskAccessEnabledHint
    case fullDiskAccessHint
    case folderAccessReminder
    case folderAccessSaved
    case importSettings

    case settingsLabel
    case basicSettings
    case extensions
    case fileTools
    case fileToolsHint
    case resourceTools
    case resourceToolsHint
    case openWithApps, openWithAppsHint, openWithAppName, addApplication, openWithEmptyTitle
    case openWithEmptyHint, openWithMenuHint, openWithSubmenu, openWithChooseHint, openWithRemove
    case openWithInvalidApp, openWithUnavailableApp, openWithChanged, openWithMissingSelection, openWithFailed
    case openWithUnavailable, openWithConfiguredApps
    case enableFileTools
    case fileToolsOffHint
    case fileToolsActions
    case fileToolsActionsHint
    case toolMenuPosition
    case toolSubmenu
    case toolMainMenu
    case moveHereMenuPosition
    case copyNamesSettingsHint
    case copyPathsSettingsHint
    case moveSettingsHint
    case deleteSettingsHint
    case showInMainMenu
    case moveHereInMainMenu
    case permanentDelete
    case deleteConfirmation
    case deleteRequireConfirmation
    case deleteSilently
    case permanentDeleteHint
    case deleteConfirmTitle
    case deleteConfirmMessage
    case deleteFailedCount
    case airDrop
    case sendAliasToDesktop
    case desktopAliasHint
    case desktopAliasFailedCount
    case desktopAliasAuthorize
    case airDropHint
    case airDropUnavailable
    case fileOperationFailed
    case fileOperationAuthorize
    case copyItemNames
    case copyItemPaths
    case copyItemsHint
    case fileToolsErrorTitle
    case clipboardWriteFailed
    case moveItems
    case moveItemsHint
    case moveSelectedHere
    case moveSelectedHereCount
    case moveFailed
    case moveInvalidSelection
    case moveSourceChanged
    case moveInvalidDestination
    case moveDestinationExists
    case moveStaleRequest
    case moveDisabled
    case moveAuthorizeFolder
    case moveChooseExactFolder
    case creationSettings
    case templatesAndTypes
    case finderAndFolders
    case generalSettingsHint
    case creationSettingsHint
    case finderFoldersHint
    case interfaceLanguage
    case startupAndAccess
    case viewUpdateSettings
    case quickCreation
    case quickCollisionHint
    case afterCreationHint
    case manageTemplates
    case finderExtension
    case menuFolders
    case enabledTypes

    case general
    case fileTypes
    case folders
    case about
    case aboutFileMint
    case version
    case copyright
    case developers
    case specialThanks
    case signingThanks
    case projectPage
    case privacyPolicy
    case license
    case updates
    case checkForUpdates
    case downloadUpdate
    case openInstaller
    case releaseNotes
    case availableVersion
    case updateIdle
    case updateChecking
    case updateCurrent
    case updateAvailable
    case updateDownloading
    case updateVerifying
    case updateInstalling
    case updateFinishWork
    case updateRestartNow
    case updateInstallFailed
    case updateReady
    case updateInstallHint
    case updateSaveHint
    case updateInstallerAuthorizationFailed
    case updateNetworkFailed
    case updateChecksumFailed
    case updateMissingAssets
    case updateInvalidRelease
    case updateNoRelease
    case updateRateLimited
    case updateDownloadFailed
    case updateOpenFailed
    case addType
    case editType
    case remove
    case displayName
    case extensionLabel
    case save
    case paste
    case noClipboardText
    case contentHint
    case creating
    case allowFolder
    case authorizeFolderHint
    case folderHint
    case authorize
    case ready
    case needsAccess
    case productTagline
    case productDetail
    case finderSetup
    case finderSettingsPathModern
    case finderSettingsPathLegacy
    case fileTypeHint
    case customTypeHint
    case restoreConfirm
    case duplicateType
    case emptyTypeName
    case deleteTypeConfirm
    case noCustomSelection
    case newFileShortcut
    case sourceAvailable
    case viewHelp
    case restore

    case status
    case locations
    case templates
    case behavior
    case finder
    case integration
    case finderSyncExtension
    case openExtensionSettings
    case permissionSetup
    case activeMenu
    case lastError
    case addFolder
    case resetBuiltIns
    case moveUp
    case moveDown
    case language
    case naming
    case whenFileExists
    case autoIncrement
    case fail
    case afterCreation
    case revealCreatedFile
    case favoritesFirst
    case openFileMint
    case quitFileMint
    case createNewFileTooltip
    case noTemplatesEnabled
    case newFile
    case customNewFile
    case customPanelSubtitle
    case fileName
    case saveLocation
    case chooseOtherFolder
    case fileFormat
    case initialContent
    case formatHint
    case placeholderHint
    case create
    case cancel
    case replace
    case replaceExistingFileTitle
    case replaceExistingFileMessage
    case invalidFileExtension
    case createFileErrorTitle
}

public enum FileMintStrings {
    private static let focused: [FileMintTextKey: (String, String)] = [
        .appearance: ("Appearance", "外观"),
        .theme: ("Theme", "主题"),
        .lightAppearance: ("Light", "浅色"),
        .darkAppearance: ("Dark", "深色"),
        .pasteImageFile: ("Paste Image as File…", "图片粘贴为文件…"),
        .clipboardImageHint: ("Save the copied image as PNG. Existing files get a new numbered name.", "将拷贝的图片保存为 PNG。同名时自动编号。"),
        .clipboardImageUnsupported: ("Copy one screenshot or image, then try again. File references and animated images are not supported.", "请先拷贝一张截图或图片，再试一次。暂不支持文件引用或动画图片。"),
        .clipboardImageTooLarge: ("Use an image up to 16 million pixels, 16,384 pixels per side and 64 MB.", "请选择不超过 1600 万像素、单边 16384 像素、64 MB 的图片。"),
        .clipboardImageFailed: ("The image could not be converted to PNG. Copy it again and retry.", "图片无法转换为 PNG，请重新拷贝后再试。"),
        .imagePreview: ("Image Preview", "图片预览"),
        .imageFileName: ("Image.png", "图片.png"),
        .defaultFileName: ("Default File Name", "默认文件名"),
        .defaultTemplate: ("Default", "默认"),
        .makeDefaultTemplate: ("Make Default", "设为默认"),
        .selectedTemplate: ("Template: %@", "模板：%@"),
        .noTemplate: ("Plain text", "纯文本"),
        .importDocumentTemplate: ("Import Document Template…", "导入文档模板…"),
        .documentTemplate: ("Document Template", "文档模板"),
        .documentTemplateHint: ("Creates an independent copy with the template’s original content and formatting.", "创建独立副本，保留模板原有的内容和排版。"),
        .documentUnsupported: ("Choose a downloaded DOCX or XLSX document. Links, folders and macro-enabled formats are not supported.", "请选择已下载的 DOCX 或 XLSX 文档。暂不支持链接、文件夹或启用宏的格式。"),
        .documentTooLarge: ("Use a document up to 64 MB, with at most 4,096 package items and 128 MB expanded content.", "请选择不超过 64 MB、内部项目不超过 4096 个、展开后不超过 128 MB 的文档。"),
        .documentInvalid: ("The document is damaged or its format is unsupported. Save a fresh DOCX or XLSX in your office app, then import it again.", "文档已损坏或格式不受支持。请用办公软件重新保存为 DOCX 或 XLSX，再导入。"),
        .documentUnavailable: ("The saved template is missing or damaged. Remove this template and import the original document again.", "保存的模板已丢失或损坏。请移除此模板，并重新导入原文档。"),
        .documentImportFailed: ("The document template could not be saved. Check file access and available disk space, then retry.", "文档模板无法保存。请检查文件访问权限和剩余磁盘空间后重试。"),
        .documentDraftEdited: ("Save or cancel the text you entered before switching to a document template.", "请先保存或取消已输入的文本，再切换到文档模板。"),
        .settingsLabel: ("Settings", "设置"),
        .basicSettings: ("Basics", "基础设置"),
        .extensions: ("Extensions", "扩展功能"),
        .fileTools: ("File & Folder Tools", "文件（夹）工具"),
        .fileToolsHint: ("Choose the tools you need in Finder’s context menu.", "选择需要的工具，让 Finder 右键菜单更顺手。"),
        .resourceTools: ("Resource Tools", "资源工具"),
        .resourceToolsHint: ("Convert, resize and process local images.", "转换格式、调整尺寸，处理本地图片。"),
        .openWithApps: ("Open with App", "使用 App 打开"),
        .openWithAppsHint: ("Your go-to apps, right in Finder’s context menu.", "把常用 App，放进 Finder 右键菜单。"),
        .openWithAppName: ("Open with %@", "使用「%@」打开"),
        .addApplication: ("Add App", "添加 App"),
        .openWithConfiguredApps: ("Applications", "应用列表"),
        .openWithEmptyTitle: ("Keep your favorite apps close", "添加常用 App"),
        .openWithEmptyHint: ("Choose an app, then open selected files and folders with it from Finder.", "添加后，在 Finder 中选中文件或文件夹，右键即可使用它打开。"),
        .openWithMenuHint: ("Submenu entries appear under Open with App. If none remain, the group is hidden.", "二级菜单收纳在「使用 App 打开」中；没有二级项目时，自动隐藏分组入口。"),
        .openWithSubmenu: ("Submenu", "二级菜单"),
        .openWithChooseHint: ("Choose apps to add to Finder’s context menu.", "选择要添加到 Finder 右键菜单的应用程序。"),
        .openWithRemove: ("Remove %@", "移除 %@"),
        .openWithInvalidApp: ("Choose a valid macOS application (.app).", "请选择有效的 macOS 应用程序（.app）。"),
        .openWithUnavailableApp: ("This app is unavailable. Add it again in Open with App settings to update its location or access.", "此 App 已不可用。请在「使用 App 打开」中重新添加，更新位置或访问权限。"),
        .openWithChanged: ("The app or folder settings changed. Select the items and open the Finder menu again.", "应用或文件夹设置已更改，请重新选中项目并打开 Finder 右键菜单。"),
        .openWithMissingSelection: ("Some selected items are no longer available. Select the files or folders again.", "部分所选项目已不可用，请重新选择文件或文件夹。"),
        .openWithFailed: ("The app could not open the selection. Check that it supports these files or folders and try again.", "无法使用此 App 打开所选项目。请确认它支持这些文件或文件夹后重试。"),
        .openWithUnavailable: ("Unavailable · add again to repair", "App 不可用 · 请重新添加"),
        .enableFileTools: ("Enable File & Folder Tools", "启用文件（夹）工具"),
        .fileToolsOffHint: ("Turning this off hides the Finder menu and preserves your choices.", "关闭后隐藏右键菜单，并保留各项设置。"),
        .fileToolsActionsHint: ("Check to enable; choose where each tool appears.", "勾选启用；菜单位置可单独设置。"),
        .toolMenuPosition: ("Menu location", "菜单位置"),
        .toolSubmenu: ("Tools submenu", "工具子菜单"),
        .toolMainMenu: ("Main menu", "一级菜单"),
        .moveHereMenuPosition: ("“Move Here” menu location", "「移到此处」菜单位置"),
        .copyNamesSettingsHint: ("Includes extensions, one item per line.", "包含文件后缀，多选时每项一行。"),
        .copyPathsSettingsHint: ("Copies full paths, one item per line.", "拷贝完整路径，多选时每项一行。"),
        .moveSettingsHint: ("Select items, then right-click their destination to move them.", "先选择项目，再到目标文件夹右键完成移动。"),
        .deleteSettingsHint: ("Bypasses Trash. Deletion cannot be undone.", "不经过废纸篓，删除后无法撤销。"),
        .showInMainMenu: ("Show in main menu", "显示在一级菜单"),
        .moveHereInMainMenu: ("Show “Move Selected Items Here” in main menu", "将「将所选项目移到此处」显示在一级菜单"),
        .permanentDelete: ("Delete Permanently", "彻底删除"),
        .deleteConfirmation: ("Before deleting", "删除方式"),
        .deleteRequireConfirmation: ("Require confirmation", "需要二次确认"),
        .deleteSilently: ("Delete silently", "直接静默删除"),
        .permanentDeleteHint: ("Bypasses Trash and cannot be undone. Silent mode skips confirmation; system permissions still apply.", "不经过废纸篓，删除后无法撤销。静默删除不再二次确认，系统授权仍可能出现。"),
        .deleteConfirmTitle: ("Permanently delete %d selected items?", "彻底删除所选的 %d 个项目？"),
        .deleteConfirmMessage: ("These files and folders will be deleted immediately, bypassing Trash. This cannot be undone.", "这些文件和文件夹将直接删除，不会放入废纸篓，且无法撤销。"),
        .deleteFailedCount: ("Deletion stopped. Deleted: %d. Not completed: %d. Check folder access and select the remaining items again.", "删除已停止。已删除 %d 个，未完成 %d 个。请检查文件夹权限，重新选择剩余项目后再试。"),
        .airDrop: ("AirDrop", "隔空投送"),
        .sendAliasToDesktop: ("Send Alias to Desktop", "发送替身到桌面"),
        .desktopAliasHint: ("Create Desktop shortcuts to the originals. Existing items are kept; duplicate names are numbered.", "在桌面创建指向原项目的替身，保留原文件，重名时自动编号。"),
        .desktopAliasFailedCount: ("Alias creation stopped. Created: %d. Not completed: %d. Check the original items and folder access, then select the remaining items to try again.", "替身创建已停止。已创建 %d 个，未完成 %d 个。请检查原项目和文件夹权限，重新选择剩余项目后再试。"),
        .desktopAliasAuthorize: ("Choose Desktop to allow FileMint to create aliases there.", "请选择桌面文件夹，允许 FileMint 在其中创建替身。"),
        .airDropHint: ("Open the system AirDrop window for the selected files and folders.", "为选中的文件或文件夹打开系统隔空投送窗口。"),
        .airDropUnavailable: ("AirDrop cannot share these items right now. Check that AirDrop is available and the selected items are accessible.", "暂时无法隔空投送这些项目，请检查隔空投送是否可用，以及所选项目是否可访问。"),
        .fileOperationFailed: ("The operation could not be completed. Check the selected items, folder access and tool settings, then try again.", "操作未能完成。请检查所选项目、文件夹权限和功能开关后重试。"),
        .fileOperationAuthorize: ("Choose this exact folder to allow access to the selected items.", "请选择当前文件夹，以允许访问所选项目。"),
        .fileToolsActions: ("Menu actions", "菜单功能"),
        .copyItemNames: ("Copy File / Folder Names", "拷贝文件（夹）名称"),
        .copyItemPaths: ("Copy File / Folder Paths", "拷贝文件（夹）路径"),
        .copyItemsHint: ("Names include extensions. Multiple selected items are copied one per line. An empty tools menu is hidden.", "名称包含后缀。多选时每个项目占一行；没有启用的子功能时隐藏工具菜单。"),
        .fileToolsErrorTitle: ("File & Folder Tools", "文件（夹）工具"),
        .clipboardWriteFailed: ("Could not write to the clipboard. Please try again.", "无法写入剪贴板，请重试。"),
        .moveItems: ("Move File / Folder", "移动文件（夹）"),
        .moveItemsHint: ("Choose items to move, then right-click the destination folder and choose Move Selected Items Here. A new selection replaces the previous one; pending items stay until moved.", "选择要移动的项目，再在目标位置右键选择“将所选项目移到此处”。新选择覆盖旧选择，待移动项目会一直保留。"),
        .moveSelectedHere: ("Move Selected Items Here", "将所选项目移到此处"),
        .moveSelectedHereCount: ("Move Selected Items Here (%d items)", "将所选项目移到此处（%d 项）"),
        .moveFailed: ("Move could not be completed", "未能完成移动"),
        .moveInvalidSelection: ("Select files or folders again. A selection cannot include a folder together with items inside it.", "请重新选择文件或文件夹，不能同时选择文件夹及其内部项目。"),
        .moveSourceChanged: ("A source item is missing or has been replaced. Select the items to move again.", "源项目已不存在或已被替换，请重新选择要移动的项目。"),
        .moveInvalidDestination: ("Choose a different folder. Items cannot be moved to their current folder or inside themselves.", "请选择其他文件夹，不能移动到原文件夹或项目自身内部。"),
        .moveDestinationExists: ("An item with the same name already exists. Nothing will be overwritten. Choose another destination or resolve the name conflict, then try again.", "目标位置已有同名项目，不会覆盖。请选择其他位置或处理同名项目后重试。"),
        .moveStaleRequest: ("The pending selection has changed. Reopen the destination context menu and try again.", "待移动项目已变化，请重新打开目标位置的右键菜单后重试。"),
        .moveDisabled: ("Enable Move File / Folder in File & Folder Tools, and check the configured folder scope.", "请启用文件（夹）工具中的移动功能，并检查菜单文件夹范围。"),
        .moveAuthorizeFolder: ("Allow access to this folder to move the selected items. Choose the indicated folder; your pending selection is kept if you close this dialog.", "移动所选项目需要访问此文件夹。请选择当前指定的文件夹；关闭此对话框会保留待移动项目。"),
        .moveChooseExactFolder: ("Please choose the indicated folder.", "请选择指定的文件夹。"),
        .creationSettings: ("Creation", "创建行为"),
        .templatesAndTypes: ("Templates & Types", "模板与类型"),
        .finderAndFolders: ("Finder & Folders", "Finder 与文件夹"),
        .generalSettingsHint: ("Make FileMint fit the way you work.", "设置语言、启动方式与更新偏好。"),
        .creationSettingsHint: ("Choose what happens when you create a file.", "设置同名处理与创建完成后的行为。"),
        .finderFoldersHint: ("Manage Finder integration and the folders you work in.", "管理 Finder 扩展、菜单范围与文件夹访问权限。"),
        .interfaceLanguage: ("Interface language", "界面语言"),
        .startupAndAccess: ("Startup & menu bar", "启动与菜单栏"),
        .viewUpdateSettings: ("View version and updates…", "查看版本与更新…"),
        .quickCreation: ("Quick creation", "快速创建"),
        .quickCollisionHint: ("Applies to one-click creation from Finder. New File… asks before replacing an existing file.", "适用于 Finder 中的一键创建。“新建文件…”面板仍会在替换已有文件前询问。"),
        .afterCreationHint: ("Select the saved file in Finder after either creation method succeeds.", "任一创建方式成功后，在 Finder 中选中已保存的文件。"),
        .manageTemplates: ("Manage templates and file types…", "管理模板与文件类型…"),
        .finderExtension: ("Finder extension", "Finder 扩展"),
        .menuFolders: ("Menu locations", "菜单显示范围"),
        .enabledTypes: ("enabled", "已启用"),

        .followSystem: ("Follow System", "跟随系统"),
        .launchAtLogin: ("Launch at login", "开机自动启动"),
        .showMenuBar: ("Show in menu bar", "显示在菜单栏"),
        .automaticallyCheckForUpdates: ("Automatically check for updates", "自动检查更新"),
        .automaticUpdateHint: ("While FileMint is running, check for a new version at most once every 7 days. Download and install when you choose.", "FileMint 运行时，每 7 天最多检查一次新版本。下载和安装由你决定。"),
        .viewUpdate: ("View Update", "查看更新"),
        .loginNeedsApproval: ("Allow FileMint in macOS Login Items to finish enabling startup.", "请在 macOS 登录项中允许 FileMint，完成开机启动设置。"),
        .loginInstallFirst: ("Move FileMint to Applications to enable launch at login.", "将 FileMint 移到“应用程序”后启用开机启动。"),
        .loginRegistrationFailed: ("Launch at login could not be enabled. Retry or check macOS Login Items.", "未能启用开机启动，可重试或检查 macOS 登录项设置。"),
        .openLoginSettings: ("Login Items Settings…", "打开登录项设置…"),
        .retry: ("Retry", "重试"),
        .fullDiskAccess: ("Full Disk Access", "完全磁盘访问权限"),
        .openFullDiskAccess: ("Check in System Settings…", "在系统设置中确认…"),
        .fullDiskAccessStatus: ("Status: check the system switch", "授权状态：以系统设置开关为准"),
        .fullDiskAccessStatusHint: ("FileMint cannot read this switch automatically. This guide remaining visible does not mean access is denied.", "FileMint 无法自动读取此开关。此说明仍然显示，不代表你尚未授权。"),
        .fullDiskAccessEnabledHint: ("Switch on: permission is granted. Quit and reopen FileMint after enabling it; no need to add it again.", "开关已开启：已授予权限。开启后退出并重新打开 FileMint，无需重复添加或授权。"),
        .fullDiskAccessHint: ("Switch off or FileMint missing: add the installed FileMint.app in Privacy & Security → Full Disk Access, then turn it on.", "开关关闭或没有 FileMint：在“隐私与安全性 → 完全磁盘访问权限”中添加已安装的 FileMint.app 并开启。"),
        .folderAccessReminder: ("The folder list shows saved access only. Even with Full Disk Access, choose each working folder once to let FileMint remember access.", "列表仅显示各文件夹的授权记录。即使已开启完全磁盘访问，仍需首次选择工作文件夹以记住访问权限。"),
        .folderAccessSaved: ("Folder access saved", "已保存此文件夹的授权"),
        .importSettings: ("Import Settings…", "导入设置…"),

        .general: ("General", "通用"),
        .fileTypes: ("File Types", "文件类型"),
        .folders: ("Folders", "文件夹"),
        .about: ("About", "关于"),
        .aboutFileMint: ("About FileMint", "关于 FileMint"),
        .version: ("Version", "版本"),
        .copyright: ("Copyright", "版权"),
        .developers: ("Developers", "开发者"),
        .specialThanks: ("Special Thanks", "特别感谢"),
        .signingThanks: ("For helping with Developer ID signing and Apple notarization.", "感谢为 FileMint 的 Developer ID 签名与 Apple 公证提供帮助。"),
        .projectPage: ("Project", "项目主页"),
        .privacyPolicy: ("Privacy", "隐私说明"),
        .license: ("License", "使用许可"),
        .updates: ("Software Update", "软件更新"),
        .checkForUpdates: ("Check for Updates…", "检查更新…"),
        .downloadUpdate: ("Update and Restart", "更新并重启"),
        .openInstaller: ("Reopen Installer", "重新打开安装包"),
        .releaseNotes: ("Release Notes", "查看发布说明"),
        .availableVersion: ("Available version", "可用版本"),
        .updateIdle: ("Check for a new version now, or manage automatic checks in General. Downloads always require your confirmation.", "可立即检查新版本，或在“通用”中管理自动检查。下载始终需要你的确认。"),
        .updateChecking: ("Checking for updates…", "正在检查更新…"),
        .updateCurrent: ("You're up to date. No newer stable release is available.", "当前已是最新版本，暂无更新的正式版本。"),
        .updateAvailable: ("A new version is available. Download it when you're ready.", "发现新版本，可下载更新。"),
        .updateDownloading: ("Downloading the installer…", "正在下载安装包…"),
        .updateVerifying: ("Verifying the installer…", "正在校验安装包…"),
        .updateReady: ("Installer verified and opened. Finish installing in Finder.", "安装包已校验并打开，请在 Finder 中完成安装。"),
        .updateInstallHint: ("FileMint will download, verify, install the update and restart automatically. Finish creating or editing files first. macOS may request administrator authorization.", "FileMint 将下载、校验并安装更新，然后自动重启。请先完成文件创建或编辑。macOS 可能要求管理员授权。"),
        .updateInstalling: ("Installing the update and restarting…", "正在安装更新并重启…"),
        .updateFinishWork: ("Finish or cancel the open creation or editing window, then choose Update and Restart again.", "请先完成或取消打开的创建或编辑窗口，再选择更新并重启。"),
        .updateRestartNow: ("Restart to Finish Updating", "重启以完成更新"),
        .updateInstallFailed: ("The update could not be installed. Try again or download the installer from the release page.", "未能安装更新，请重试或从发布页面下载安装包。"),
        .updateSaveHint: ("Choose where to save the installer. It opens after the download is verified.", "请选择安装包的保存位置。下载并校验完成后会打开安装包。"),
        .updateInstallerAuthorizationFailed: ("macOS has not authorized this installer to run. Download again and confirm its location in the system save window.", "macOS 尚未允许此安装包运行。请重新下载，并在系统保存窗口中确认保存位置。"),
        .updateNetworkFailed: ("Could not connect to GitHub. Check your connection and retry, or visit the release page.", "无法连接 GitHub，请检查网络后重试，或前往发布页面。"),
        .updateChecksumFailed: ("Installer verification failed. Nothing was opened. Retry the download or visit the release page.", "安装包校验失败，未打开文件。请重新下载或前往发布页面。"),
        .updateMissingAssets: ("This release is missing a ready installer or checksum. Try again later or visit the release page.", "此版本尚无完整的安装包与校验文件，请稍后重试或前往发布页面。"),
        .updateInvalidRelease: ("The update response could not be verified. Retry or visit the release page.", "更新信息无法验证，请重试或前往发布页面。"),
        .updateNoRelease: ("No published release was found. Try again later or visit the release page.", "暂未找到已发布版本，请稍后重试或前往发布页面。"),
        .updateRateLimited: ("GitHub is limiting requests. Try again later or visit the release page.", "GitHub 暂时限制了请求频率，请稍后重试或前往发布页面。"),
        .updateDownloadFailed: ("Could not save the installer. Check available disk space and retry the download.", "无法保存安装包，请检查磁盘剩余空间后重新下载。"),
        .updateOpenFailed: ("The verified installer could not be opened. Try reopening it or visit the release page.", "已校验安装包，但未能打开。请重新打开或前往发布页面。"),
        .addType: ("New Text Template…", "新建文本模板…"),
        .editType: ("Edit…", "编辑…"),
        .remove: ("Remove", "移除"),
        .displayName: ("Name", "名称"),
        .extensionLabel: ("Extension", "后缀"),
        .save: ("Save", "保存"),
        .paste: ("Paste", "粘贴"),
        .noClipboardText: ("The clipboard does not contain text.", "剪贴板中没有文本内容。"),
        .contentHint: ("Optional. Paste or type text; it is saved exactly as entered.", "可选。粘贴或输入文本，内容会原样保存。"),
        .creating: ("Creating…", "正在创建…"),
        .allowFolder: ("Allow Folder", "允许访问"),
        .authorizeFolderHint: ("Select this folder to let FileMint create files here.", "选择此文件夹，允许 FileMint 在这里创建文件。"),
        .folderHint: ("Menus include your home folder and its subfolders by default. Add other locations here; access is remembered after you choose a folder.", "默认包含当前用户主目录及其子目录的菜单。可在这里添加其他位置，选择后会记住访问权限。"),
        .authorize: ("Authorize…", "授权访问…"),
        .ready: ("Ready", "已就绪"),
        .needsAccess: ("Choose this folder once", "需首次选择此文件夹以授权"),
        .productTagline: ("A new file. Right here.", "新文件，就在此刻。"),
        .productDetail: ("Right-click in Finder to create a file. Use New File… when you want to name it or paste content first.", "在 Finder 右键创建文件。需要命名或粘贴内容时，选择“新建文件…”。"),
        .finderSetup: ("macOS requires you to enable the Finder extension. Click Open Extension Settings, enable FileMint, then return here to refresh its status. You can also use New File… in the sidebar.", "Finder 扩展需要你在 macOS 中开启。点击“打开扩展设置”，开启 FileMint 后返回这里，状态会自动刷新。也可使用侧栏中的“新建文件…”。"),
        .finderSettingsPathModern: ("If needed, find FileMint in System Settings → General → Login Items & Extensions → Finder (or Added Extensions).", "如果没有直接看到 FileMint，请前往“系统设置 → 通用 → 登录项与扩展 → Finder”（或“已添加的扩展”）查找。"),
        .finderSettingsPathLegacy: ("If needed, find FileMint in System Settings → Privacy & Security → Extensions.", "如果没有直接看到 FileMint，请前往“系统设置 → 隐私与安全性 → 扩展”查找。"),
        .fileTypeHint: ("Save different templates for the same format. Enabled templates appear in Finder and the creation panel.", "为同一种格式保存不同模板。勾选后显示在 Finder 和创建面板中。"),
        .customTypeHint: ("Creates UTF-8 text with this suffix. A suffix does not convert text into PDF, images or Office files.", "以此后缀创建 UTF-8 文本；不能通过更改后缀生成 PDF、图片或 Office 文件。"),
        .restoreConfirm: ("Restore built-in types? Custom types will be kept.", "恢复内置类型？自定义类型会保留。"),
        .duplicateType: ("This extension already exists. Edit or enable the existing type.", "这个后缀已存在，请编辑或启用已有类型。"),
        .emptyTypeName: ("Enter a name for this file type.", "请填写文件类型名称。"),
        .deleteTypeConfirm: ("Remove this custom file type? Existing files are unaffected.", "移除此自定义类型？已创建的文件不受影响。"),
        .noCustomSelection: ("Select a custom type to edit or remove.", "选中自定义类型后可编辑或移除。"),
        .newFileShortcut: ("⌘↩ Create", "⌘↩ 创建"),
        .sourceAvailable: ("Local. Native. No account.", "本地运行 · 原生体验 · 无需账号"),
        .viewHelp: ("Installation Help", "安装帮助"),
        .restore: ("Restore", "恢复"),
    ]

    public static func text(_ key: FileMintTextKey, language: AppLanguage) -> String {
        let language = language.resolved()
        if let pair = focused[key] { return language == .english ? pair.0 : pair.1 }
        switch language {
        case .english, .system:
            return englishText(key)
        case .chinese:
            return chineseText(key)
        }
    }

    public static func templateDisplayName(for template: FileTemplate, language: AppLanguage) -> String {
        switch language.resolved() {
        case .english, .system:
            return template.displayName
        case .chinese:
            switch template.id {
            case "plain-text":
                return "文本"
            case "markdown":
                return "Markdown"
            case "swift":
                return "Swift"
            case "json":
                return "JSON"
            case "html":
                return "HTML"
            case "css":
                return "CSS"
            case "shell":
                return "Shell 脚本"
            default:
                return template.displayName
            }
        }
    }

    public static func templateGroupName(for template: FileTemplate, language: AppLanguage) -> String {
        switch language.resolved() {
        case .english, .system:
            return template.group
        case .chinese:
            switch template.group {
            case "Basic":
                return "基础"
            case "Writing":
                return "写作"
            case "Code":
                return "代码"
            case "Data":
                return "数据"
            case "Web":
                return "网页"
            default:
                return template.group
            }
        }
    }

    public static func replaceExistingFileMessage(
        fileName: String,
        language: AppLanguage
    ) -> String {
        String(
            format: text(.replaceExistingFileMessage, language: language),
            locale: Locale(identifier: language.resolved().rawValue),
            fileName
        )
    }

    private static func englishText(_ key: FileMintTextKey) -> String {
        switch key {
        case .status:
            return "Status"
        case .locations:
            return "Locations"
        case .templates:
            return "Templates"
        case .behavior:
            return "Behavior"
        case .finder:
            return "Finder"
        case .integration:
            return "Integration"
        case .finderSyncExtension:
            return "Finder Sync Extension"
        case .openExtensionSettings:
            return "Open Extension Settings"
        case .permissionSetup:
            return "Permission Setup"
        case .activeMenu:
            return "Active Menu"
        case .lastError:
            return "Last Error"
        case .addFolder:
            return "Add Folder"
        case .resetBuiltIns:
            return "Reset Built-ins"
        case .moveUp:
            return "Move Up"
        case .moveDown:
            return "Move Down"
        case .language:
            return "Language"
        case .naming:
            return "Naming"
        case .whenFileExists:
            return "When File Exists"
        case .autoIncrement:
            return "Auto Increment"
        case .fail:
            return "Fail"
        case .afterCreation:
            return "After Creation"
        case .revealCreatedFile:
            return "Reveal Created File"
        case .favoritesFirst:
            return "Favorites First"
        case .openFileMint:
            return "Open FileMint"
        case .quitFileMint:
            return "Quit FileMint"
        case .createNewFileTooltip:
            return "Create a new file"
        case .noTemplatesEnabled:
            return "No Templates Enabled"
        case .newFile:
            return "New File"
        case .customNewFile:
            return "New File…"
        case .customPanelSubtitle:
            return "Choose a template or format, then name your file."
        case .fileName:
            return "File Name"
        case .saveLocation:
            return "Save Location"
        case .chooseOtherFolder:
            return "Choose Other Folder..."
        case .fileFormat:
            return "Format"
        case .initialContent:
            return "Initial Content"
        case .formatHint:
            return "Search a format or enter a custom text-file extension."
        case .placeholderHint:
            return "UTF-8 text · Your edits are saved verbatim."
        case .create:
            return "Create"
        case .cancel:
            return "Cancel"
        case .replace:
            return "Replace"
        case .replaceExistingFileTitle:
            return "A file with this name already exists."
        case .replaceExistingFileMessage:
            return "Replace \"%@\" in the selected folder?"
        case .invalidFileExtension:
            return "Enter a non-empty extension without spaces or path separators."
        case .createFileErrorTitle:
            return "FileMint could not create the file."
        default: return focused[key]?.0 ?? key.rawValue
        }
    }

    private static func chineseText(_ key: FileMintTextKey) -> String {
        switch key {
        case .status:
            return "状态"
        case .locations:
            return "监听目录"
        case .templates:
            return "模板"
        case .behavior:
            return "行为"
        case .finder:
            return "Finder"
        case .integration:
            return "集成"
        case .finderSyncExtension:
            return "Finder 同步扩展"
        case .openExtensionSettings:
            return "打开扩展设置"
        case .permissionSetup:
            return "权限设置"
        case .activeMenu:
            return "当前菜单"
        case .lastError:
            return "上次错误"
        case .addFolder:
            return "添加文件夹"
        case .resetBuiltIns:
            return "重置内置模板"
        case .moveUp:
            return "上移"
        case .moveDown:
            return "下移"
        case .language:
            return "语言"
        case .naming:
            return "命名"
        case .whenFileExists:
            return "文件已存在时"
        case .autoIncrement:
            return "自动递增"
        case .fail:
            return "失败"
        case .afterCreation:
            return "创建后"
        case .revealCreatedFile:
            return "显示新建文件"
        case .favoritesFirst:
            return "收藏优先"
        case .openFileMint:
            return "打开 FileMint"
        case .quitFileMint:
            return "退出 FileMint"
        case .createNewFileTooltip:
            return "新建文件"
        case .noTemplatesEnabled:
            return "没有启用的模板"
        case .newFile:
            return "新建文件"
        case .customNewFile:
            return "新建文件…"
        case .customPanelSubtitle:
            return "选择模板或格式，起个名字，然后创建。"
        case .fileName:
            return "文件名"
        case .saveLocation:
            return "保存位置"
        case .chooseOtherFolder:
            return "选择其他文件夹…"
        case .fileFormat:
            return "格式"
        case .initialContent:
            return "初始内容"
        case .formatHint:
            return "搜索格式，或输入自定义文本文件后缀。"
        case .placeholderHint:
            return "UTF-8 文本 · 编辑后的内容原样保存。"
        case .create:
            return "创建"
        case .cancel:
            return "取消"
        case .replace:
            return "替换"
        case .replaceExistingFileTitle:
            return "已存在同名文件"
        case .replaceExistingFileMessage:
            return "是否替换所选文件夹中的“%@”？"
        case .invalidFileExtension:
            return "请输入非空且不含空格或路径分隔符的后缀。"
        case .createFileErrorTitle:
            return "FileMint 无法创建文件。"
        default: return focused[key]?.1 ?? key.rawValue
        }
    }
}

public struct PermissionGuideStep: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
}

public enum PermissionGuide {
    public static func steps(language: AppLanguage) -> [PermissionGuideStep] {
        switch language.resolved() {
        case .english, .system:
            return [
                PermissionGuideStep(
                    id: "open-settings",
                    title: "Open macOS extension settings",
                    detail: "Use the button below to open the Extensions pane in System Settings."
                ),
                PermissionGuideStep(
                    id: "enable-extension",
                    title: "Enable FileMint Finder Extension",
                    detail: "macOS 15+: General > Login Items & Extensions > Finder. Older macOS: Privacy & Security > Extensions. Enable FileMint."
                ),
                PermissionGuideStep(
                    id: "check-location",
                    title: "Use a monitored folder",
                    detail: "Right-click inside Desktop, Documents, Downloads, or another folder listed in Locations."
                ),
                PermissionGuideStep(
                    id: "relaunch-finder",
                    title: "Relaunch Finder if the menu is still missing",
                    detail: "Finder may need a relaunch after extension permissions change."
                )
            ]
        case .chinese:
            return [
                PermissionGuideStep(
                    id: "open-settings",
                    title: "打开 macOS 扩展设置",
                    detail: "点击下面的按钮，打开系统设置里的扩展面板。"
                ),
                PermissionGuideStep(
                    id: "enable-extension",
                    title: "启用 FileMint Finder 扩展",
                    detail: "macOS 15 及更新版本：通用 > 登录项与扩展 > Finder。旧版：隐私与安全性 > 扩展。启用 FileMint。"
                ),
                PermissionGuideStep(
                    id: "check-location",
                    title: "在监听目录内使用",
                    detail: "在桌面、文稿、下载，或“监听目录”里列出的其他文件夹中右键。"
                ),
                PermissionGuideStep(
                    id: "relaunch-finder",
                    title: "如果菜单仍未出现，重新启动 Finder",
                    detail: "扩展权限变化后，Finder 可能需要重新启动才会刷新菜单。"
                )
            ]
        }
    }
}
