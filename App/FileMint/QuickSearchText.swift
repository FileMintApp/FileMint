import FileMintCore

enum QuickSearchText {
    case title, menu, placeholder, noResults, keyboardHint, unavailable, busy
    case enable, enableHint, combination, defaultKey, recording, reset, active, disabled, unassigned, inactive, retry, recordingHint, previousActive
    func text(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .title: ("Quick Search", "快捷搜索")
        case .menu: ("Quick Search…", "快捷搜索…")
        case .placeholder: ("Search actions, templates, favorites or settings…", "搜索动作、模板、常用位置或设置…")
        case .noResults: ("No matching results", "没有匹配的结果")
        case .keyboardHint: ("↑↓ Select  ·  Return Open  ·  Esc Close", "↑↓ 选择  ·  回车打开  ·  Esc 关闭")
        case .unavailable: ("This item is no longer available. Search again.", "该项目已不可用，请重新搜索。")
        case .busy: ("Please wait for the current operation to finish.", "请等待当前操作结束。")
        case .enable: ("Enable Global Shortcut", "启用全局快捷键")
        case .enableHint: ("Open Quick Search while FileMint is running, even from another app.", "FileMint 运行时，可从其他应用呼出快捷搜索。")
        case .combination: ("Key Combination", "快捷键组合")
        case .defaultKey: ("⌃⌥K · Default", "⌃⌥K · 默认")
        case .recording: ("Press keys…", "请按组合键…")
        case .reset: ("Restore Default", "恢复默认")
        case .active: ("Shortcut active", "快捷键已生效")
        case .previousActive: ("Your previous shortcut remains active.", "原快捷键仍然有效。")
        case .disabled: ("Disabled. Your saved combination is kept.", "已关闭，保留已设置的组合。")
        case .unassigned: ("Record a combination to finish setup.", "请录制组合键以完成设置。")
        case .inactive: ("Shortcut inactive", "快捷键未生效")
        case .retry: ("Retry", "重试")
        case .recordingHint: ("Default: Control-Option-K. Click to record; Escape cancels.", "默认为 Control + Option + K，点击录制，Esc 取消。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}
