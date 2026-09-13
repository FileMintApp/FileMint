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
    case followSystem
    case launchAtLogin
    case showMenuBar
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

    case general
    case fileTypes
    case folders
    case about
    case aboutFileMint
    case version
    case copyright
    case developers
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
        .followSystem: ("Follow System", "跟随系统"),
        .launchAtLogin: ("Launch at login", "开机自动启动"),
        .showMenuBar: ("Show in menu bar", "显示在菜单栏"),
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
        .folderAccessReminder: ("The list below shows saved folder access only. Even with Full Disk Access, choose each working folder once to let FileMint remember access.", "下方仅显示各文件夹的授权记录。即使已开启完全磁盘访问，仍需首次选择工作文件夹以记住访问权限。"),
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
        .projectPage: ("Project", "项目主页"),
        .privacyPolicy: ("Privacy", "隐私说明"),
        .license: ("License", "使用许可"),
        .updates: ("Software Update", "软件更新"),
        .checkForUpdates: ("Check for Updates…", "检查更新…"),
        .downloadUpdate: ("Download Update", "下载更新"),
        .openInstaller: ("Reopen Installer", "重新打开安装包"),
        .releaseNotes: ("Release Notes", "查看发布说明"),
        .availableVersion: ("Available version", "可用版本"),
        .updateIdle: ("Check GitHub for a new version when you choose. No automatic checks or downloads.", "主动检查 GitHub 上的新版本，不会自动检查或下载。"),
        .updateChecking: ("Checking for updates…", "正在检查更新…"),
        .updateCurrent: ("You're up to date. No newer stable release is available.", "当前已是最新版本，暂无更新的正式版本。"),
        .updateAvailable: ("A new version is available. Download it when you're ready.", "发现新版本，可下载更新。"),
        .updateDownloading: ("Downloading the installer…", "正在下载安装包…"),
        .updateVerifying: ("Verifying the installer…", "正在校验安装包…"),
        .updateReady: ("Installer verified and opened. Finish installing in Finder.", "安装包已校验并打开，请在 Finder 中完成安装。"),
        .updateInstallHint: ("After the installer opens, quit FileMint and drag the new app into Applications to replace it. Eject the FileMint installer volume, then reopen FileMint from Applications. macOS may ask you to approve the app or Finder extension again.", "安装包打开后，请退出 FileMint，将新版拖入“应用程序”替换旧版。推出“FileMint”安装磁盘，再从“应用程序”重新打开 FileMint。macOS 可能需要再次确认应用或启用 Finder 扩展。"),
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
        .addType: ("Add Type…", "添加类型…"),
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
        .folderHint: ("Add the folders where you create files. Access is remembered after you choose a folder.", "添加常用文件夹，选择后会记住访问权限。"),
        .authorize: ("Authorize…", "授权访问…"),
        .ready: ("Ready", "已就绪"),
        .needsAccess: ("Choose this folder once", "需首次选择此文件夹以授权"),
        .productTagline: ("A new file. Right here.", "新文件，就在此刻。"),
        .productDetail: ("Right-click in Finder to create a file. Use New File… when you want to name it or paste content first.", "在 Finder 右键创建文件。需要命名或粘贴内容时，选择“新建文件…”。"),
        .finderSetup: ("Enable FileMint in macOS Finder extensions, then add your working folders.", "在 macOS 中启用 FileMint Finder 扩展，再添加常用文件夹。"),
        .fileTypeHint: ("Checked types appear in Finder and the format picker. Drag to reorder, or use Move Up / Down.", "勾选后显示在 Finder 和后缀选择器中。拖动排序，或使用上移、下移。"),
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
            return "Name it. Choose a type. Add content if you need it."
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
            return "起个名字，选个后缀，需要时再加点内容。"
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
