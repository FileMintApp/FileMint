import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
}

public enum FileMintTextKey: String, CaseIterable, Sendable {
    case general
    case fileTypes
    case folders
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
        .general: ("General", "通用"),
        .fileTypes: ("File Types", "文件类型"),
        .folders: ("Folders", "文件夹"),
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
        .needsAccess: ("Choose once to grant access", "选择一次以授权访问"),
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
        if let pair = focused[key] { return language == .english ? pair.0 : pair.1 }
        switch language {
        case .english:
            return englishText(key)
        case .chinese:
            return chineseText(key)
        }
    }

    public static func templateDisplayName(for template: FileTemplate, language: AppLanguage) -> String {
        switch language {
        case .english:
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
        switch language {
        case .english:
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
            locale: Locale(identifier: language.rawValue),
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
        switch language {
        case .english:
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
