import Foundation
import FileMintCore

/// Rename-only copy stays together, including the recovery controls that remain
/// available when ordinary rename is disabled.
enum BatchRenameText: Hashable {
    case title, rules, nameList, ascending, descending, order, addRule, replace, delete
    case prepend, append, numbering, uppercase, lowercase, search, replacement, text
    case start, step, width, separator, position, before, after, currentBody, unifiedBody
    case original, proposed, state, changed, unchanged, checking, invalid, conflict
    case moveUp, moveDown, remove, paste, listHint, listTooLarge, noRules, noChanges
    case renameCount, undoCount, counts, close, stop, stopping, running, preview
    case reassignTitle, reassignMessage, reassign, cancel, details, location
    case success, undone, restored, recoveryNeeded, renamedNeedsRecovery, resultCounts, unavailable
    case undoLast, restore, exportAndUnblock, finishRetirement, finishCommitted, committedCleanup, busy
    case manualTitle, manualWarning, manualAcknowledgement, manualContinue
    case emptySearch, oversizedLiteral, invalidNumber, overflow, oversizedBody
    case emptyBody, hiddenChange, extensionChange, whitespace, trailingPeriod
    case invalidCharacter, longName, duplicateTarget, occupiedTarget, checkFailed
    case missingSource, blankLine, lineCount, invalidList, invalidPreview, operationFailed
    case accessDenied, unsupported, featureDisabled, protectedItem, recordBlocked
    case stoppedStaging, stoppedPublishing, stoppedCommitting, stoppedCleanup, interrupted
    case workspaceHint, selectedCount, namingMethod, rulesHint, listModeHint, ruleSequence
    case startWithRule, replaceHint, prependHint, numberingHint, moreRules, ruleActions
    case protectedNames, listRequired, previewHint, selectHint, reviewIssues, firstIssue
    case ready, chooseRule, executing, results, resultHint, undoHint, nameBody, uppercaseHint, lowercaseHint
    case startInstruction, readyInstruction, checkingInstruction, reviewInstruction, noChangesInstruction
    case awaitingReassignment, stoppingInstruction

    func text(_ language: AppLanguage) -> String {
        let chinese = language.resolved() == .chinese
        switch self {
        case .title: return chinese ? "批量重命名" : "Batch Rename"
        case .workspaceHint: return chinese ? "设置命名方式，预览并确认更改。" : "Set up your names, then review the changes."
        case .selectedCount: return chinese ? "%d 个项目" : "%d items"
        case .namingMethod: return chinese ? "命名方式" : "Naming method"
        case .rulesHint: return chinese ? "组合规则，按顺序生成新名称。" : "Combine rules to build your new names in order."
        case .listModeHint: return chinese ? "按右侧顺序，为每个项目填写新名称。" : "Enter one new name for each item in preview order."
        case .ruleSequence: return chinese ? "按顺序应用" : "Applied in order"
        case .startWithRule: return chinese ? "从一条规则开始" : "Start with a rule"
        case .replaceHint: return chinese ? "查找并替换名称中的文字" : "Find and replace text in each name"
        case .prependHint: return chinese ? "在名称前加入共同的文字" : "Add shared text before each name"
        case .numberingHint: return chinese ? "为名称添加连续编号" : "Give your names a sequence"
        case .moreRules: return chinese ? "更多规则" : "More rules"
        case .ruleActions: return chinese ? "规则操作" : "Rule actions"
        case .protectedNames: return chinese ? "保留扩展名与隐藏状态" : "Extensions and hidden status stay unchanged"
        case .listRequired: return chinese ? "需要 %d 行名称" : "%d names required"
        case .previewHint: return chinese ? "确认每一个新名称后，再执行重命名。" : "Review every new name before applying changes."
        case .selectHint: return chinese ? "选择一个项目，查看完整名称与详情" : "Select an item to inspect its full names and details"
        case .reviewIssues: return chinese ? "请先解决名称问题" : "Review naming issues"
        case .firstIssue: return chinese ? "查看首个问题" : "Show first issue"
        case .ready: return chinese ? "可以重命名" : "Ready to rename"
        case .chooseRule: return chinese ? "添加规则，开始整理名称" : "Add a rule to get started"
        case .startInstruction: return chinese ? "在左侧添加规则，或切换到名称列表。这里会实时显示每个新名称。" : "Add a rule on the left, or switch to Name List. Every new name appears here."
        case .readyInstruction: return chinese ? "请核对下方的新名称，确认无误后点击右下角的重命名按钮。" : "Check the new names below, then use Rename at the bottom right to apply them."
        case .checkingInstruction: return chinese ? "正在核对名称和目标占用情况，检查完成后才能执行。" : "Checking names and target availability. Wait for the checks to finish before applying changes."
        case .reviewInstruction: return chinese ? "请先修正标记的问题，所有项目检查通过后才能执行。" : "Fix the marked issues before applying changes to the selection."
        case .noChangesInstruction: return chinese ? "当前名称没有变化。调整左侧规则或名称列表后，再查看新的预览。" : "The current names are unchanged. Edit the rules or name list to update the preview."
        case .awaitingReassignment: return chinese ? "请确认名称重新分配" : "Confirm name reassignment"
        case .stoppingInstruction: return chinese ? "正在停止后续改名，并尝试恢复原名。请等待操作结束。" : "Stopping further renames and attempting to restore the earlier names. Wait for the result."
        case .executing: return chinese ? "正在应用新名称…" : "Applying new names…"
        case .results: return chinese ? "操作结果" : "Results"
        case .resultHint: return chinese ? "查看各个项目的实际状态与位置。" : "Review the actual status and location of each item."
        case .undoHint: return chinese ? "确认要恢复的名称后，再执行撤销。" : "Review the names to restore before undoing."
        case .nameBody: return chinese ? "名称主体" : "Name body"
        case .uppercaseHint: return chinese ? "将名称主体中的字母转为大写。" : "Convert letters in the name body to uppercase."
        case .lowercaseHint: return chinese ? "将名称主体中的字母转为小写。" : "Convert letters in the name body to lowercase."
        case .rules: return chinese ? "规则" : "Rules"
        case .nameList: return chinese ? "名称列表" : "Name List"
        case .ascending: return chinese ? "原名自然升序" : "Original Name, Ascending"
        case .descending: return chinese ? "原名自然降序" : "Original Name, Descending"
        case .order: return chinese ? "排序" : "Order"
        case .addRule: return chinese ? "添加规则" : "Add Rule"
        case .replace: return chinese ? "替换" : "Replace"
        case .delete: return chinese ? "删除文字" : "Delete Text"
        case .prepend: return chinese ? "添加前缀" : "Prepend"
        case .append: return chinese ? "添加尾部文字" : "Append Text"
        case .numbering: return chinese ? "编号" : "Numbering"
        case .uppercase: return chinese ? "转为大写" : "Uppercase"
        case .lowercase: return chinese ? "转为小写" : "Lowercase"
        case .search: return chinese ? "查找文字" : "Find Text"
        case .replacement: return chinese ? "替换为" : "Replace With"
        case .text: return chinese ? "文字" : "Text"
        case .start: return chinese ? "起始" : "Start"
        case .step: return chinese ? "步长" : "Step"
        case .width: return chinese ? "最少位数" : "Minimum Digits"
        case .separator: return chinese ? "分隔符" : "Separator"
        case .position: return chinese ? "编号位置" : "Number Position"
        case .before: return chinese ? "主体之前" : "Before Body"
        case .after: return chinese ? "主体之后" : "After Body"
        case .currentBody: return chinese ? "当前主体" : "Current Body"
        case .unifiedBody: return chinese ? "统一主体" : "Unified Body"
        case .original: return chinese ? "原名称" : "Original Name"
        case .proposed: return chinese ? "新名称" : "New Name"
        case .state: return chinese ? "状态" : "Status"
        case .changed: return chinese ? "将更改" : "Will Change"
        case .unchanged: return chinese ? "不变" : "Unchanged"
        case .checking: return chinese ? "正在检查…" : "Checking…"
        case .invalid: return chinese ? "名称无效" : "Invalid Name"
        case .conflict: return chinese ? "名称冲突" : "Name Conflict"
        case .moveUp: return chinese ? "上移规则" : "Move Rule Up"
        case .moveDown: return chinese ? "下移规则" : "Move Rule Down"
        case .remove: return chinese ? "移除规则" : "Remove Rule"
        case .paste: return chinese ? "粘贴" : "Paste"
        case .listHint: return chinese ? "每行填写一个主体，对应全部所选项目；不含受保护的扩展名。无扩展名文件的主体不能加入句点，文件夹可以包含内部句点。" : "One body per selected item, excluding protected extensions. Suffixless files cannot gain a period; folder bodies may contain internal periods."
        case .listTooLarge: return chinese ? "名称列表不能超过 1 MiB；已保留之前的文字。" : "The name list cannot exceed 1 MiB. The previous text was kept."
        case .noRules: return chinese ? "添加规则以预览新的名称。" : "Add a rule to preview new names."
        case .noChanges: return chinese ? "没有需要更改的名称。" : "No names need changing."
        case .renameCount: return chinese ? "重命名 %d 个项目" : "Rename %d Items"
        case .undoCount: return chinese ? "撤销 %d 个项目" : "Undo %d Items"
        case .counts: return chinese ? "%d 项更改 · %d 项不变 · %d 项错误 · %d 项检查中" : "%d changing · %d unchanged · %d errors · %d checking"
        case .close: return chinese ? "关闭" : "Close"
        case .stop: return chinese ? "停止并恢复" : "Stop and Restore"
        case .stopping: return chinese ? "正在停止并尝试恢复…" : "Stopping and attempting restoration…"
        case .running: return chinese ? "正在重命名；关闭窗口将停止并尝试恢复。" : "Renaming. Closing the window stops and attempts restoration."
        case .preview: return chinese ? "预览" : "Preview"
        case .reassignTitle: return chinese ? "重新分配名称列表？" : "Reassign the Name List?"
        case .reassignMessage: return chinese ? "排序将改变每一行对应的项目。保留列表文字，并按新顺序重新分配？" : "The order changes which item receives each line. Keep the list text and reassign it to the new order?"
        case .reassign: return chinese ? "重新分配" : "Reassign"
        case .cancel: return chinese ? "取消" : "Cancel"
        case .details: return chinese ? "完整名称与状态" : "Full Names and Status"
        case .location: return chinese ? "当前位置" : "Current Location"
        case .success: return chinese ? "重命名完成" : "Rename Completed"
        case .undone: return chinese ? "撤销完成" : "Undo Completed"
        case .restored: return chinese ? "已恢复操作前名称" : "Pre-operation Names Restored"
        case .recoveryNeeded: return chinese ? "部分项目仍需恢复" : "Some Items Still Need Recovery"
        case .renamedNeedsRecovery: return chinese ? "已重命名，仍需恢复" : "Renamed; Needs Restoration"
        case .resultCounts: return chinese ? "%d 项已重命名 · %d 项不变 · %d 项已恢复 · %d 项仍需处理" : "%d renamed · %d unchanged · %d restored · %d need attention"
        case .unavailable: return chinese ? "无法确认" : "Unverified"
        case .undoLast: return chinese ? "撤销上次批量重命名…" : "Undo Last Batch Rename…"
        case .restore: return chinese ? "恢复操作前名称" : "Restore Pre-operation Names"
        case .exportAndUnblock: return chinese ? "导出恢复证据并解除阻塞…" : "Export Recovery Evidence and Unblock…"
        case .finishRetirement: return chinese ? "完成恢复记录收口" : "Finish Recovery Record Closure"
        case .finishCommitted: return chinese ? "完成操作收口" : "Finish Operation Cleanup"
        case .committedCleanup: return chinese ? "改名结果已提交。可以核验当前位置并完成暂存与操作记录收口；此操作不会恢复原名。" : "The rename was committed. Verify current locations and finish staging and record cleanup; this does not restore the earlier names."
        case .busy: return chinese ? "另一个文件操作正在进行。请先完成或关闭当前窗口。" : "Another file operation is active. Finish or close the current window first."
        case .manualTitle: return chinese ? "导出证据并人工关闭记录" : "Export Evidence and Manually Close the Record"
        case .manualWarning: return chinese ? "此操作不会恢复或验证用户文件。剩余暂存文件将留在原处，自动恢复和当前的上次重命名撤销将失效。导出并验证恢复证据后才会解除阻塞。" : "This does not restore or verify your files. Remaining staging files stay in place. Automatic recovery and the current last-rename undo will become unavailable. The blocker is cleared only after recovery evidence is exported and verified."
        case .manualAcknowledgement: return chinese ? "我已人工处理文件，并理解以上后果。" : "I have handled the files manually and understand these consequences."
        case .manualContinue: return chinese ? "选择证据导出位置…" : "Choose Evidence Export Location…"
        case .emptySearch: return chinese ? "查找文字不能为空。" : "Find text cannot be empty."
        case .oversizedLiteral: return chinese ? "每个文字参数最多 1 KiB。" : "Each text parameter is limited to 1 KiB."
        case .invalidNumber: return chinese ? "编号起始必须为非负整数，步长至少为 1，位数为 1–20。" : "Start must be a nonnegative integer, step at least 1, and width 1–20."
        case .overflow: return chinese ? "编号超出支持的整数范围。" : "Numbering exceeds the supported integer range."
        case .oversizedBody: return chinese ? "规则生成的主体超过 4 KiB。" : "A rule produces a body exceeding 4 KiB."
        case .emptyBody: return chinese ? "名称主体不能为空。" : "The name body cannot be empty."
        case .hiddenChange: return chinese ? "主体不能以句点开头；隐藏状态受到保护。" : "The body cannot begin with a period; hidden status is protected."
        case .extensionChange: return chinese ? "无扩展名文件的主体不能包含句点。" : "The body of a suffixless file cannot contain a period."
        case .whitespace: return chinese ? "名称不能以空白字符开头或结尾。" : "Names cannot begin or end with whitespace."
        case .trailingPeriod: return chinese ? "名称不能以句点结尾。" : "Names cannot end with a period."
        case .invalidCharacter: return chinese ? "名称包含不允许的字符。" : "The name contains a disallowed character."
        case .longName: return chinese ? "名称超过允许的长度。" : "The name exceeds the permitted length."
        case .duplicateTarget: return chinese ? "多个项目将使用相同的名称。" : "Multiple items would have the same name."
        case .occupiedTarget: return chinese ? "目标名称已被其他项目占用。" : "Another item occupies the target name."
        case .checkFailed: return chinese ? "无法检查目标位置，请检查访问权限和项目是否可用。" : "The target could not be checked. Check access and item availability."
        case .missingSource: return chinese ? "原项目已丢失或发生变化。" : "The original item is missing or has changed."
        case .blankLine: return chinese ? "名称列表包含空行。" : "The name list contains a blank line."
        case .lineCount: return chinese ? "需要 %d 行，当前为 %d 行。" : "Expected %d lines; found %d."
        case .invalidList: return chinese ? "请为每个所选项目填写一个名称主体。" : "Enter one name body for every selected item."
        case .invalidPreview: return chinese ? "请修正错误并等待最新预览完成。" : "Correct the errors and wait for the latest preview."
        case .operationFailed: return chinese ? "操作未完成。请检查恢复状态后继续。" : "The operation did not complete. Check recovery status before continuing."
        case .accessDenied: return chinese ? "无法访问原父文件夹，请检查其写入权限和可用性。" : "The original parent folder is unavailable. Check its write permission and availability."
        case .unsupported: return chinese ? "所选项目或所在位置不满足本地可写 APFS 和独占重命名要求。" : "The items or location do not meet the writable local APFS and exclusive-rename requirements."
        case .featureDisabled: return chinese ? "批量重命名已关闭，或项目已不在当前 Finder 范围内。" : "Batch rename is disabled, or the items are outside the current Finder scope."
        case .protectedItem: return chinese ? "项目包含受保护的位置，或无法确认目录保护边界。" : "An item includes a protected location, or its protection boundary could not be verified."
        case .recordBlocked: return chinese ? "恢复记录需要处理，当前无法开始新的重命名。" : "A recovery record needs attention before another rename can begin."
        case .stoppedStaging: return chinese ? "操作在暂存项目时停止。" : "The operation stopped while staging items."
        case .stoppedPublishing: return chinese ? "操作在应用新名称时停止。" : "The operation stopped while applying new names."
        case .stoppedCommitting: return chinese ? "操作在验证结果或保存撤销记录时停止。" : "The operation stopped while verifying results or saving undo records."
        case .stoppedCleanup: return chinese ? "文件已完成变更，操作记录仍需完成收口。" : "File changes completed; operation records still need finalization."
        case .interrupted: return chinese ? "此前操作曾中断；下方显示当前核验结果。" : "The earlier operation was interrupted. Current verified results are shown below."
        }
    }
}
