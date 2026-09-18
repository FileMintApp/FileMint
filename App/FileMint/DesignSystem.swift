import AppKit
import SwiftUI
import FileMintCore

enum FileMintStyle {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
        }
    }
    static let backgroundNS = adaptive(0xFBFBFA, 0x202221)
    static let accentNS = adaptive(0x3A8067, 0x98CBB0)
    static let background = Color(nsColor: backgroundNS)
    static let surface = Color(nsColor: adaptive(0xFFFFFF, 0x2B302D))
    static let soft = Color(nsColor: adaptive(0xF1F3EF, 0x252B27))
    static let line = Color(nsColor: adaptive(0xE3E7E1, 0x3A413C))
    static let accent = Color(nsColor: accentNS)
    static let selection = Color(nsColor: adaptive(0xE1ECE4, 0x354B3E))
    static let strong = Color(nsColor: adaptive(0x244D3B, 0xA9D2B6))
    static let onStrong = Color(nsColor: adaptive(0xFFFFFF, 0x1C3325))
    static let radius: CGFloat = 12
}

struct MintButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: primary ? .medium : .regular))
            .padding(.horizontal, 13).padding(.vertical, 8)
            .foregroundStyle(primary ? FileMintStyle.onStrong : Color.primary)
            .background(primary ? FileMintStyle.strong : FileMintStyle.surface, in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(primary ? Color.clear : FileMintStyle.line, lineWidth: 0.7))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}

extension View {
    func mintSurface(padding: CGFloat = 17) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: FileMintStyle.radius))
            .overlay(RoundedRectangle(cornerRadius: FileMintStyle.radius).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
    }
}

struct PreferenceRow<Control: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var control: Control
    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13))
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            control
        }.padding(.vertical, 2)
    }
}

enum InterfaceText {
    case fileCreation, preferences, localOnly, useTools, menuSettings, finderTip, preview, original
    case parameters, keepOriginal, previewMissing, allImages, outputSize, start, more, chooseImages
    case resourceSubtitle, generalSubtitle, creationSubtitle, typesSubtitle, foldersSubtitle, filesSubtitle
    case interface, enabledFinder, disabledFinder, selectedImages, textResult, reduceWithoutUpscale
    case busy, pixelWidth, pixelHeight, fitting, inFinder, launchHint, menuBarHint, menuEnabled, prepared
    func text(_ language: AppLanguage) -> String {
        let pair: (String, String) = switch self {
        case .fileCreation: ("File Creation", "文件创建")
        case .preferences: ("Preferences", "偏好设置")
        case .localOnly: ("Processed on your Mac", "只在你的 Mac 上处理")
        case .useTools: ("Use Tools", "使用工具")
        case .menuSettings: ("Finder Menu Settings", "Finder 菜单设置")
        case .finderTip: ("Select images in Finder and choose Resource Tools from the context menu.", "也可以在 Finder 中选中图片，右键选择「资源工具」直接开始。")
        case .preview: ("Preview", "预览")
        case .original: ("Original", "原图")
        case .parameters: ("Options", "处理参数")
        case .keepOriginal: ("Originals stay unchanged", "原文件始终保留")
        case .previewMissing: ("Preview unavailable", "暂时无法预览")
        case .allImages: ("Images", "图片列表")
        case .outputSize: ("Output dimensions", "输出尺寸")
        case .start: ("Process images", "处理图片")
        case .more: ("Details and limits", "更多说明与限制")
        case .chooseImages: ("Choose images to process", "选择要处理的图片")
        case .resourceSubtitle: ("From selected images to finished work.", "从选中图片，到完成处理。")
        case .generalSubtitle: ("Quietly at work, just the way you like.", "按你的习惯，安静地工作。")
        case .creationSubtitle: ("A few thoughtful details for every new file.", "照顾每一次新建的小细节。")
        case .typesSubtitle: ("Keep your everyday starting points close.", "把常用的起点，留在手边。")
        case .foldersSubtitle: ("You decide where FileMint can work.", "你决定 FileMint 可以在哪里工作。")
        case .filesSubtitle: ("Just the tools you need in the context menu.", "让右键菜单，恰好够用。")
        case .interface: ("Interface", "界面")
        case .enabledFinder: ("Finder extension enabled", "Finder 扩展已启用")
        case .disabledFinder: ("Set up Finder extension", "设置 Finder 扩展")
        case .selectedImages: ("Selected images", "选中的图片")
        case .textResult: ("Recognized text", "识别结果")
        case .reduceWithoutUpscale: ("Keeps proportions. Never enlarges the original.", "保持比例，不放大原图。")
        case .busy: ("Finish or close the current operation first.", "请先完成或关闭当前操作。")
        case .pixelWidth: ("Common width (px)", "统一宽度（像素）")
        case .pixelHeight: ("Common height (px)", "统一高度（像素）")
        case .fitting: ("Centered on a transparent square", "居中适配透明方形")
        case .inFinder: ("Show in Finder", "在 Finder 中显示")
        case .launchHint: ("Ready for Finder actions after login.", "登录后即可使用 Finder 右键功能。")
        case .menuBarHint: ("Quick access to creation and settings.", "随时新建文件，快速打开设置。")
        case .menuEnabled: ("Show Resource Tools in Finder", "在 Finder 中显示资源工具")
        case .prepared: ("Ready when you are.", "准备好了，随手新建。")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
    }
}
