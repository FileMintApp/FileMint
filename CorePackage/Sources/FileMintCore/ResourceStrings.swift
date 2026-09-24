import Foundation

public enum ResourceText: Sendable {
    case enable, hint, chooseImages, output, sourceFolder, chooseFolder, format, quality
    case longestEdge, stitchEdge, direction, horizontal, vertical, run, cancel, close, cancelling
    case whiteBackground, compressHint, originalHint, limits, iconHint, ocrHint, pngSet
    case selected, moveUp, moveDown, preparing, working, completed, cancelled, failed, noText
    case copyText, saveText, saved, copied, previewHint, showOutputs, accuracyHint
    case editOptions
    case metadataHint, metadataDetail

    public func text(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .enable: ("Enable Resource Tools", "启用资源工具")
        case .hint: ("Process selected local images offline. Originals stay unchanged.", "离线处理选中的本地图片，保留原文件。")
        case .chooseImages: ("Choose images…", "选择图片…")
        case .output: ("Save to", "保存位置")
        case .sourceFolder: ("Beside each original", "各原文件所在文件夹")
        case .chooseFolder: ("Choose folder…", "选择文件夹…")
        case .format: ("Output format", "输出格式")
        case .quality: ("Quality", "图片质量")
        case .longestEdge: ("Longest edge (pixels)", "最长边（像素）")
        case .stitchEdge: ("Common width / height (pixels)", "统一宽度 / 高度（像素）")
        case .direction: ("Direction", "拼接方向")
        case .horizontal: ("Horizontal", "横向")
        case .vertical: ("Vertical", "纵向")
        case .run: ("Run", "开始处理")
        case .cancel: ("Cancel", "取消")
        case .close: ("Close", "关闭")
        case .cancelling: ("Cancelling after the current system operation…", "正在取消，等待当前系统操作结束…")
        case .whiteBackground: ("JPEG fills transparent areas with white.", "转为 JPEG 时，透明区域填充白色。")
        case .compressHint: ("Keeps JPEG, HEIC, PNG or TIFF format. Quality affects JPEG/HEIC only; lossless output may not be smaller.", "保留 JPEG、HEIC、PNG 或 TIFF 格式。质量仅影响 JPEG/HEIC；无损输出不保证体积更小。")
        case .originalHint: ("Creates new copies; existing names receive a number. Single-frame, standard-color images only.", "生成副本，同名自动编号。仅处理单帧、普通色彩图片。")
        case .limits: ("Up to 100 images, 64 MiB each. Working images/canvas: up to 16 MP. Resize large originals first.", "最多 100 张，每张不超过 64 MiB；处理图片和拼接画布不超过 1600 万像素。大图请先缩小尺寸。")
        case .iconHint: ("Centers the image on transparent squares. ICNS/PNG: 16–1024 px; ICO: 16–256 px.", "图片居中等比适配透明方形。ICNS/PNG：16–1024 像素；ICO：16–256 像素。")
        case .ocrHint: ("Recognizes text on this Mac. Copy or save the result when ready; nothing is copied automatically.", "在本机识别文字，完成后可主动拷贝或保存；不会自动写入剪贴板。")
        case .pngSet: ("PNG size set", "多尺寸 PNG")
        case .selected: ("Selected images", "选中的图片")
        case .moveUp: ("Move up", "上移")
        case .moveDown: ("Move down", "下移")
        case .preparing: ("Preparing…", "正在准备…")
        case .working: ("Processing", "正在处理")
        case .completed: ("Completed", "已完成")
        case .cancelled: ("Cancelled; completed outputs were kept", "已取消，已完成的输出已保留")
        case .failed: ("Stopped; completed outputs were kept", "处理已停止，已完成的输出已保留")
        case .noText: ("No text recognized", "未识别到文字")
        case .copyText: ("Copy text", "拷贝文字")
        case .saveText: ("Save TXT…", "保存 TXT…")
        case .saved: ("Text saved", "文字已保存")
        case .copied: ("Text copied", "文字已拷贝")
        case .previewHint: ("Preview shows the first 20 thumbnails. Use arrows to confirm stitching order.", "预览显示前 20 张缩略图，可用上下按钮调整拼接顺序。")
        case .showOutputs: ("Show results in Finder", "在 Finder 显示结果")
        case .editOptions: ("Adjust options", "调整参数")
        case .accuracyHint: ("OCR uses supported Chinese/English models; input is limited to a 4096 px longest edge. Review recognized text before use.", "OCR 使用系统支持的中英文识别，输入最长边限制为 4096 像素；使用前请核对结果。")
        case .metadataHint: ("Creates clean copies in the same format. Re-encodes in sRGB up to 16 MP; size or color may change.", "生成同格式的已清理副本。最多处理 1600 万像素，并重新编码为 sRGB；体积或色彩可能变化。")
        case .metadataDetail: ("Removes GPS, camera/device details, dates, IPTC, XMP and text metadata. Does not clean filenames or information visible in the picture.", "移除位置、设备信息、拍摄时间、IPTC、XMP 和文字元数据。文件名及画面中可见的信息不会被清除。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}

extension ResourceError {
    public func message(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .invalidSelection: ("Select regular local images, already downloaded, without links or duplicates.", "请选择已下载的本地普通图片，不包含链接或重复项目。")
        case .unsupportedImage: ("This image is unsupported. Use a standard-color JPEG, PNG, HEIC, TIFF, BMP or static GIF.", "图片不受支持，请使用普通色彩的 JPEG、PNG、HEIC、TIFF、BMP 或静态 GIF。")
        case .multipleFrames: ("Animated and multi-frame images are not supported.", "暂不支持动画或多帧图片。")
        case .sourceChanged: ("An original changed. Select the images again.", "原图片已变化，请重新选择。")
        case .inputTooLarge: ("The input is empty or exceeds 64 MiB.", "输入文件为空或超过 64 MiB。")
        case .dimensionsTooLarge: ("The image or canvas exceeds processing limits. Reduce the requested size.", "图片或画布超过处理上限，请减小目标尺寸。")
        case .invalidOptions: ("Enter a valid size between 1 and 16384 pixels and choose a supported format.", "请输入 1–16384 像素的有效尺寸，并选择支持的格式。")
        case .unsupportedOutput: ("This system cannot write that format. Compression supports JPEG, HEIC, PNG and TIFF.", "当前系统无法写入该格式；压缩仅支持 JPEG、HEIC、PNG 和 TIFF。")
        case .encodingFailed: ("The system could not encode the result. Try another output format.", "系统无法编码结果，请尝试其他输出格式。")
        case .accessDenied: ("The output folder is unavailable or not writable. Choose it again.", "输出文件夹不可用或不可写，请重新选择。")
        case .noText: ("No text recognized.", "未识别到文字。")
        case .textTooLarge: ("Recognized text exceeds the result limit. Select fewer or smaller images.", "识别文字超过结果上限，请减少图片数量或尺寸。")
        case .disabled: ("The tool or its folder scope changed. Enable it and select the images again.", "工具开关或文件夹范围已变化，请启用并重新选择图片。")
        case .failed: ("Processing failed. Originals were preserved; check the image and folder access.", "处理失败，原文件已保留；请检查图片和文件夹授权。")
        case .privateMetadataRemains: ("Private metadata remained in the new copy, so no output was saved.", "新副本仍含隐私元数据，因此未保存输出文件。")
        case .metadataTooLarge: ("This image exceeds the 16 MP limit for privacy cleaning. The original was kept; no smaller copy was made.", "图片超过隐私清理的 1600 万像素上限。原图已保留，也未生成缩小版。")
        case .metadataFormatUnavailable: ("This Mac cannot create a verified clean copy in the image's format.", "当前 Mac 无法生成并验证该图片格式的已清理副本。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}
