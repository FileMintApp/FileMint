import Foundation

public enum LauncherText: Sendable {
    case title, subtitle, shortcuts, externalRequest, draftPending, draftOpened, searchShown, searchFocused
    case chooseLocation, checkingLocation, locationSelected, closeNotice, previewDraft

    public func text(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .title: ("Shortcuts & Launchers", "快捷指令与启动器")
        case .subtitle: ("Set a template and folder once. Enter a name, review, then create.", "配置好模板和位置，日常只填名称，确认后创建。")
        case .shortcuts: ("Shortcuts", "快捷指令")
        case .externalRequest: ("External draft request", "外部创建请求")
        case .draftPending: ("Not saved yet. Review the name, folder and content, then choose Create.", "尚未保存。请检查名称、位置和内容，然后点击创建。")
        case .draftOpened: ("Draft opened. Create the file in FileMint after reviewing it.", "草稿已打开，请在 FileMint 中检查后创建文件。")
        case .searchShown: ("Quick Search is shown.", "快捷搜索已显示。")
        case .searchFocused: ("Quick Search is focused.", "已聚焦快捷搜索。")
        case .chooseLocation: ("Choose save location…", "选择保存位置…")
        case .checkingLocation: ("Checking the selected folder…", "正在核对所选保存位置…")
        case .locationSelected: ("Folder selected. Review the location and choose Create.", "已选择文件夹，请检查位置后点击创建。")
        case .closeNotice: ("Dismiss notice", "关闭提示")
        case .previewDraft: ("Draft Preview", "草稿预览")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}

extension ExternalInvocationError {
    public func message(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .invalidRequest: ("This draft request is invalid. Check the command's parameters.", "无法打开此创建请求，请检查命令参数。")
        case .unsupportedVersion: ("This link version is not supported by FileMint.", "当前 FileMint 不支持此链接版本。")
        case .invalidFilename: ("Use a filename without a path, matching the selected template's extension.", "请只填写文件名，并使用与所选模板一致的后缀。")
        case .templateUnavailable: ("The selected template was removed or disabled. Choose an enabled template.", "所选模板已移除或停用，请重新选择启用的模板。")
        case .contentTemplateMismatch: ("This document template cannot receive text. Use its template content or choose a text template.", "此文档模板不能接收文本，请沿用模板内容或改用文本模板。")
        case .payloadTooLarge: ("The request exceeds this entry's size limit. Shorten it or use native Shortcuts parameters.", "请求超过此入口的大小限制，请缩短内容或使用原生快捷指令参数。")
        case .existingDraft: ("An unfinished draft is open. The new request was not opened; finish or cancel this draft, then retry.", "已有未完成草稿，新请求未打开。请完成或取消当前草稿后重试。")
        case .busy: ("FileMint is completing another operation. Try again when it finishes.", "FileMint 正在完成当前操作，请稍后重试。")
        case .unavailable: ("FileMint cannot show an interactive panel right now. Try again from an unlocked desktop.", "当前无法显示可交互面板，请在已解锁的桌面环境重试。")
        case .destinationUnavailable: ("The save folder is unavailable or changed. Choose the intended folder again; your draft is preserved.", "保存位置不可用或已改变，请重新选择正确的文件夹；草稿已保留。")
        case .authorizationRequired: ("Allow access to this folder when creating the file, or choose another folder.", "创建时需要允许访问此位置，也可选择其他文件夹。")
        case .authorizationDenied: ("Folder access was not granted. Your draft is preserved; choose the folder again.", "未获得文件夹访问权限，草稿已保留，请重新选择。")
        case .conflictingRequestID: ("This request ID was used for different input. Start a new request with a new ID.", "此请求标识已用于其他内容，请使用新的标识重新发起。")
        case .alreadyHandled: ("This request was already handled. Start a new request to open another draft.", "此请求已处理，请重新发起以打开新草稿。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}
