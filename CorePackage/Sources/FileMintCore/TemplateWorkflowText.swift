import Foundation

public enum TemplateWorkflowText: Hashable, Sendable {
    case copy, copySuffix, preview, previewEnabled, previewHint, openingEnabled, openingHint
    case none, reveal, defaultApp, selectedApp, followTemplate, chooseApp, unresolvedApp
    case createAndOpen, editContent, resultPreview, exampleContext, loading, unavailablePreview
    case savedOpenFailed, savedUnavailable, retryOpen
    case openingApplicationUnavailable, applicationOpenFailed, defaultApplicationOpenFailed
    case importMenu, importPackage, exportPackage, exportSelection, selected, enabled, all, custom
    case add, skip, saveCopy, confirmImport, adoptDefaults, staleReview, recoveryNeeded, cleanupPending
    case packageInvalid, packageTooLarge, packageVersion, noSelection, importFailed, exportFailed
    case importing, basicRevealHint, sourceUnavailable, settingsBusy, applicationRequired
    public func text(_ language: AppLanguage) -> String {
        let pair: (String, String)
        switch self {
        case .copy: pair = ("Copy", "复制")
        case .copySuffix: pair = ("Copy", "副本")
        case .preview: pair = ("Preview", "预览")
        case .previewEnabled: pair = ("Template Preview", "模板预览")
        case .previewHint: pair = ("Show file content previews when managing templates and creating files.", "管理模板和创建文件时显示内容预览。")
        case .openingEnabled: pair = ("Create and Open", "创建后打开")
        case .openingHint: pair = ("Choose an action for each template and override it for the current file.", "逐模板选择创建后动作，创建时可临时调整。")
        case .none: pair = ("Do nothing", "无动作")
        case .reveal: pair = ("Reveal in Finder", "在 Finder 中显示")
        case .defaultApp: pair = ("Open with default app", "使用默认应用打开")
        case .selectedApp: pair = ("Open with selected app", "使用指定应用打开")
        case .followTemplate: pair = ("Follow Template", "跟随模板")
        case .chooseApp: pair = ("Choose App…", "选择应用…")
        case .unresolvedApp: pair = ("Choose this app locally before opening", "请先在本机选择此应用")
        case .createAndOpen: pair = ("Create and Open", "创建并打开")
        case .editContent: pair = ("Edit Content", "编辑内容")
        case .resultPreview: pair = ("Result Preview", "结果预览")
        case .exampleContext: pair = ("Example · 2026-01-01 00:00:00 UTC · requested filename", "示例 · 2026-01-01 00:00:00 UTC · 请求文件名")
        case .loading: pair = ("Loading preview…", "正在加载预览…")
        case .unavailablePreview: pair = ("Preview unavailable", "预览不可用")
        case .savedOpenFailed: pair = ("File saved, but could not open", "文件已保存，但未能打开")
        case .savedUnavailable: pair = ("The saved file is missing or changed.", "已保存的文件不存在或已发生变化。")
        case .openingApplicationUnavailable: pair = ("The application is unavailable or has changed. Choose the application again.", "应用不可用或已发生变化，请重新选择应用。")
        case .applicationOpenFailed: pair = ("The application could not open the saved file. Retry or choose another application.", "应用未能打开已保存的文件，请重试或选择其他应用。")
        case .defaultApplicationOpenFailed: pair = ("macOS could not open the saved file with its default application. Check the file's default application in Finder, retry, or choose an application.", "macOS 未能使用默认应用打开已保存的文件。请在 Finder 中检查此文件的默认应用，重试或选择应用。")
        case .retryOpen: pair = ("Retry Opening", "重试打开")
        case .importMenu: pair = ("Import…", "导入…")
        case .importPackage: pair = ("Import Template Package…", "导入模板包…")
        case .exportPackage: pair = ("Export…", "导出…")
        case .exportSelection: pair = ("Export Templates", "导出模板")
        case .selected: pair = ("Selected", "选中模板")
        case .enabled: pair = ("Enabled", "已启用")
        case .all: pair = ("All", "全部")
        case .custom: pair = ("Custom selection", "自选")
        case .add: pair = ("Add", "添加")
        case .skip: pair = ("Skip", "跳过")
        case .saveCopy: pair = ("Save as copy", "另存副本")
        case .confirmImport: pair = ("Import", "导入")
        case .adoptDefaults: pair = ("Adopt package defaults where no explicit default exists", "没有明确默认模板时采用模板包的默认值")
        case .staleReview: pair = ("Templates changed. Review the updated merge before importing.", "模板已变更，请检查更新后的合并结果再导入。")
        case .recoveryNeeded: pair = ("A template transaction needs recovery. Saved files have been preserved.", "模板事务需要恢复，现有文件已保留。")
        case .cleanupPending: pair = ("Templates imported; private transaction cleanup is pending.", "模板已导入，私有事务清理待完成。")
        case .packageInvalid: pair = ("This template package is damaged or contains unsupported fields.", "模板包已损坏或包含不支持的字段。")
        case .packageTooLarge: pair = ("The package exceeds a size or item limit. Export a smaller selection.", "模板包超过大小或数量限制，请减少导出选择。")
        case .packageVersion: pair = ("This template package version is not supported.", "不支持此模板包版本。")
        case .noSelection: pair = ("Select at least one template.", "请至少选择一个模板。")
        case .importFailed: pair = ("Import was not applied. Your saved templates are unchanged.", "导入未应用，现有模板未改变。")
        case .exportFailed: pair = ("The package could not be saved.", "未能保存模板包。")
        case .importing: pair = ("Processing templates…", "正在处理模板…")
        case .basicRevealHint: pair = ("Used when Create and Open is off, or a file has no template. A template action replaces this fallback.", "创建后打开关闭或文件没有模板时使用；模板动作会代替此基础行为。")
        case .sourceUnavailable: pair = ("The source template is unavailable. Keep this draft and re-import its document.", "源模板不可用，请保留草稿并重新导入文档。")
        case .settingsBusy: pair = ("Templates are being processed. Try changing settings again when this finishes.", "正在处理模板，请完成后再修改设置。")
        case .applicationRequired: pair = ("Choose an application before saving this action.", "保存此动作前，请先选择应用。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}

extension TemplateCreationAction.Kind {
    public var textKey: TemplateWorkflowText {
        switch self {
        case .none: .none
        case .revealInFinder: .reveal
        case .openWithDefaultApp: .defaultApp
        case .openWithApplication: .selectedApp
        }
    }
}
