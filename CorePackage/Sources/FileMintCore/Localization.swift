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
    case createFileErrorTitle
}

public enum FileMintStrings {
    public static func text(_ key: FileMintTextKey, language: AppLanguage) -> String {
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
        case .createFileErrorTitle:
            return "FileMint could not create the file."
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
        case .createFileErrorTitle:
            return "FileMint 无法创建文件。"
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
                    detail: "In Privacy & Security > Extensions > Finder Extensions, turn on FileMint Finder Extension."
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
                    detail: "在“隐私与安全性 > 扩展 > Finder 扩展”中，打开 FileMint Finder Extension。"
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
