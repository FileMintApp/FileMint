import Foundation

public enum FavoriteText: Sendable {
    case title, subtitle, add, searchAll, searchPlaceholder, emptyTitle, emptyHint, savedItems
    case allGroups, allTypes
    case pinned, recent, all, files, folders, unavailable, group, ungrouped
    case choose, locate, relink, remove, rename, openFile, clearRecent
    case added, duplicate, unavailableHint, damagedHint, addFailed, locateFailed
    case showAddInFinder, showListInFinder, finderHint, selectedCount, pin, unpin
    case moveToGroup, saved, cancel, checkLocations, moveUp, moveDown
    case recover, recoverConfirm, recovered, showBackup

    public func text(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .title: ("Favorite Locations", "常用文件（夹）")
        case .subtitle: ("Find saved files and folders in a moment.", "快速定位常用文件和文件夹。")
        case .add: ("Add to Favorite Locations", "加入常用文件（夹）")
        case .searchAll: ("Search All Favorites…", "搜索全部常用项目…")
        case .searchPlaceholder: ("Search names, paths or groups…", "搜索名称、路径或分组…")
        case .emptyTitle: ("Keep important places close", "把常用位置放在手边")
        case .emptyHint: ("Add files and folders here, or right-click a selection in Finder.", "可在此添加文件或文件夹，也可在 Finder 中选中后右键加入。")
        case .savedItems: ("Saved items", "保存的项目")
        case .allGroups: ("All groups", "全部分组")
        case .allTypes: ("All types", "所有类型")
        case .pinned: ("Pinned", "已固定")
        case .recent: ("Recently Located", "最近使用")
        case .all: ("All", "全部")
        case .files: ("Files", "文件")
        case .folders: ("Folders", "文件夹")
        case .unavailable: ("Unavailable", "不可用")
        case .group: ("Group", "分组")
        case .ungrouped: ("Ungrouped", "未分组")
        case .choose: ("Add Files or Folders…", "添加文件或文件夹…")
        case .locate: ("Show in Finder", "在 Finder 中定位")
        case .relink: ("Relink…", "重新定位…")
        case .remove: ("Remove Favorite", "移除常用")
        case .rename: ("Name and Group…", "名称与分组…")
        case .openFile: ("Open File", "打开文件")
        case .clearRecent: ("Clear Recent Use", "清除最近使用记录")
        case .added: ("Added %d; already saved %d", "已加入 %d 项；%d 项已存在")
        case .duplicate: ("Already saved", "已存在")
        case .unavailableHint: ("This item is unavailable. Relink or remove it.", "项目不可用，请重新定位或移除。")
        case .damagedHint: ("The saved catalog could not be read. It was preserved; adding is disabled until recovery.", "无法读取常用项目数据，原文件已保留；恢复前不能继续添加。")
        case .addFailed: ("Could not add the selection. Check access and try again.", "无法加入所选项目，请检查访问权限后重试。")
        case .locateFailed: ("Could not locate this item. Relink it in settings.", "无法定位此项目，请在设置中重新定位。")
        case .showAddInFinder: ("Show direct Add in Finder", "在 Finder 中显示直接加入入口")
        case .showListInFinder: ("Show favorite shortcuts in Finder", "在 Finder 中显示常用列表")
        case .finderHint: ("Finder menus appear only inside configured folders. The app can add items from anywhere you choose.", "Finder 菜单只在已配置的文件夹中出现；App 可添加你主动选择的其他位置。")
        case .selectedCount: ("%d selected", "已选 %d 项")
        case .pin: ("Pin", "固定")
        case .unpin: ("Unpin", "取消固定")
        case .moveToGroup: ("Move to Group…", "移至分组…")
        case .saved: ("Save", "保存")
        case .cancel: ("Cancel", "取消")
        case .checkLocations: ("Check Locations", "检查位置")
        case .moveUp: ("Move Up", "上移")
        case .moveDown: ("Move Down", "下移")
        case .recover: ("Back Up and Reset…", "备份并重置…")
        case .recoverConfirm: ("The unreadable catalog will be backed up in FileMint's private folder, then an empty catalog will be created. Original files are not changed.", "无法读取的常用项目目录会备份到 FileMint 私有文件夹，再创建一个空目录。原文件不会改变。")
        case .recovered: ("The damaged catalog was backed up as %@.", "损坏的目录已备份为 %@。")
        case .showBackup: ("Show Backup in Finder", "在 Finder 中显示备份")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}
