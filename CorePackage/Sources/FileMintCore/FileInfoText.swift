import Foundation

public enum FileInfoText: Equatable, Sendable {
    case title, type, size, location, created, modified, unavailable, file, directory
    case algorithm, sha256, sha512, sha1, md5, all, sha256Hint, sha512Hint, sha1Hint, md5Hint, allHint
    case calculate, recalculate, cancel, close, copy, copyAll, copyPath, copied, copyFailed
    case notCalculated, preparing, waiting, reading, stopping, cancelled, complete, readScope
    case comparison, expected, emptyComparison, chooseSingle, invalidComparison, calculateFirst, match, mismatch
    case directoryHint, unsupported, placeholder, invalidSelection, changed, accessDenied, readFailed, disabled, busy, authorize

    public func text(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .title: ("File Info", "文件信息")
        case .type: ("Kind", "类型")
        case .size: ("Logical size", "逻辑大小")
        case .location: ("Location", "位置")
        case .created: ("Created", "创建时间")
        case .modified: ("Modified", "修改时间")
        case .unavailable: ("Unavailable", "不可用")
        case .file: ("File", "文件")
        case .directory: ("Folder", "文件夹")
        case .algorithm: ("Checksum algorithm", "校验算法")
        case .sha256: ("SHA-256 · Recommended", "SHA-256 · 推荐")
        case .sha512: ("SHA-512", "SHA-512")
        case .sha1: ("SHA-1 · Legacy compatibility", "SHA-1 · 兼容旧系统")
        case .md5: ("MD5 · Legacy compatibility", "MD5 · 兼容旧系统")
        case .all: ("All four algorithms", "全部四种算法")
        case .sha256Hint: ("Recommended for general file checks. A checksum is not encryption and cannot prove a file’s origin.", "推荐用于一般文件校验。校验值不是加密，也不能单独证明文件来源可信。")
        case .sha512Hint: ("A SHA-2 algorithm producing 128 hexadecimal characters. Use when a SHA-512 checksum is needed.", "使用 SHA-2 系列算法，输出 128 个十六进制字符；适合需要 SHA-512 校验值的场景。")
        case .sha1Hint: ("SHA-1 is no longer cryptographically secure. Use only for legacy checksums; choose SHA-256 for general checks.", "SHA-1 已不被认为具备密码学安全性，仅建议兼容旧校验值时使用。一般文件校验请选择 SHA-256。")
        case .md5Hint: ("MD5 is no longer cryptographically secure. Use only for legacy checksums; choose SHA-256 for general checks.", "MD5 已不被认为具备密码学安全性，仅建议兼容旧校验值时使用。一般文件校验请选择 SHA-256。")
        case .allHint: ("Includes MD5 and SHA-1 for compatibility. Prefer SHA-256 or SHA-512 for file integrity checks.", "包含 MD5 / SHA-1，仅建议用于兼容性校验；判断文件完整性优先使用 SHA-256 或 SHA-512。")
        case .calculate: ("Calculate checksum", "计算校验值")
        case .recalculate: ("Recalculate", "重新计算")
        case .cancel: ("Cancel", "取消")
        case .close: ("Close", "关闭")
        case .copy: ("Copy result", "拷贝结果")
        case .copyAll: ("Copy all", "拷贝全部")
        case .copyPath: ("Copy path", "拷贝路径")
        case .copied: ("Copied", "已拷贝")
        case .copyFailed: ("Could not write to the clipboard. Try again.", "无法写入剪贴板，请重试。")
        case .notCalculated: ("Not calculated", "尚未计算")
        case .preparing: ("Reading file information…", "正在读取文件信息…")
        case .waiting: ("Waiting for read access… You can cancel.", "正在等待读取…可随时请求取消。")
        case .reading: ("Calculating checksums…", "正在计算校验值…")
        case .stopping: ("Cancelling… Waiting for the read to finish.", "正在取消…等待读取清理完成。")
        case .cancelled: ("Calculation cancelled. No checksum was kept.", "已取消计算，未保留校验值。")
        case .complete: ("Calculation complete", "计算完成")
        case .readScope: ("These checksums describe the file data read this time. They exclude names, metadata and resource forks; later changes require recalculation.", "校验值对应本次读取的文件数据，不含名称、元数据或资源叉；文件后续变化需重新计算。")
        case .comparison: ("Compare checksum", "比对校验值")
        case .expected: ("Expected checksum", "预期校验值")
        case .emptyComparison: ("Enter or paste a checksum to compare.", "请输入或粘贴要比对的校验值。")
        case .chooseSingle: ("Select one algorithm to compare a checksum.", "请先选择一种算法进行比对。")
        case .invalidComparison: ("Enter the exact number of hexadecimal characters for the selected algorithm. Internal spaces are not allowed.", "请输入所选算法对应长度的十六进制字符，值内部不能包含空白。")
        case .calculateFirst: ("Calculate this algorithm before comparing.", "请先计算当前算法的校验值。")
        case .match: ("Checksums match", "校验值一致")
        case .mismatch: ("Checksums do not match", "校验值不一致")
        case .directoryHint: ("Checksums apply only to ordinary files. Folder contents are not scanned; total size and item count are not calculated.", "校验值仅适用于普通文件；此处不扫描文件夹内容，不计算总大小或子项数量。")
        case .unsupported: ("Packages, symbolic links, Finder aliases and special items are not supported. Their contents and targets are not read.", "不支持包、符号链接、Finder 替身或特殊设备；不会读取其内容或目标。")
        case .placeholder: ("Download this item in Finder first, then try again. FileMint does not request cloud downloads.", "请先在 Finder 下载此项目后重试。FileMint 不主动请求云端下载。")
        case .invalidSelection: ("Select one local file or folder in Finder and try again.", "请在 Finder 选择一个本地文件或文件夹后重试。")
        case .changed: ("The file or its folder changed. No checksum was kept. Recalculate, or select the item again if it was replaced.", "文件或所在文件夹已变化，未保留校验值。请重新计算；若项目已被替换，请重新选择。")
        case .accessDenied: ("Read access was denied. Choose the exact item when prompted, or check its permissions in Finder.", "读取权限不足。请在授权时选择同一项目，或在 Finder 检查读取权限。")
        case .readFailed: ("Could not finish reading. Check that the file and its volume are available, then try again.", "无法完成读取。请检查文件及所在磁盘是否可用后重试。")
        case .disabled: ("File Info is disabled or this item is outside the configured Finder folders.", "文件信息功能已关闭，或项目已不在配置的 Finder 范围内。")
        case .busy: ("Another file operation is in progress. Finish or cancel it, then try again.", "另一项文件操作正在进行，请完成或取消后重试。")
        case .authorize: ("Choose this exact item to allow read access. FileMint will not change it.", "请选择同一项目以授予读取权限。FileMint 不会修改它。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}
