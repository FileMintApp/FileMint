import AppKit
import SwiftUI
import FileMintCore

enum FileMintStyle {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return srgbColor(value)
        }
    }

    static func srgbColor(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: 1)
    }

    static func srgbValue(_ color: NSColor) -> UInt32? {
        guard let value = color.usingColorSpace(.sRGB) else { return nil }
        let channels = [value.redComponent, value.greenComponent, value.blueComponent]
        guard channels.allSatisfy(\.isFinite) else { return nil }
        return channels.reduce(0) { result, channel in
            (result << 8) | UInt32(min(255, max(0, (channel * 255).rounded())))
        }
    }

    static let backgroundNS = adaptive(0xFBFBFA, 0x202221)
    static let background = Color(nsColor: backgroundNS)
    static let surface = Color(nsColor: adaptive(0xFFFFFF, 0x2B302D))
    static let soft = Color(nsColor: adaptive(0xF1F3EF, 0x252B27))
    static let line = Color(nsColor: adaptive(0xE3E7E1, 0x3A413C))
    static let radius: CGFloat = 12
}

struct FileMintPalette {
    let accentNS: NSColor
    let selectionNS: NSColor
    let strong: Color
    let onStrong: Color

    var accent: Color { Color(nsColor: accentNS) }
    var selection: Color { Color(nsColor: selectionNS) }

    private init(accent: (UInt32, UInt32), selection: (UInt32, UInt32),
                 strong: (UInt32, UInt32), onStrongDark: UInt32) {
        accentNS = FileMintStyle.adaptive(accent.0, accent.1)
        selectionNS = FileMintStyle.adaptive(selection.0, selection.1)
        self.strong = Color(nsColor: FileMintStyle.adaptive(strong.0, strong.1))
        onStrong = Color(nsColor: FileMintStyle.adaptive(0xFFFFFF, onStrongDark))
    }

    private init(rgb: UInt32) {
        let light = AppAccentPalette(rgb: rgb, dark: false)
        let dark = AppAccentPalette(rgb: rgb, dark: true)
        self.init(accent: (light.accent, dark.accent), selection: (light.selection, dark.selection),
                  strong: (light.strong, dark.strong), onStrongDark: dark.onStrong)
    }

    static let mint = FileMintPalette(accent: (0x3A8067, 0x98CBB0), selection: (0xE1ECE4, 0x354B3E),
                                    strong: (0x244D3B, 0xA9D2B6), onStrongDark: 0x1C3325)
    private static let blue = FileMintPalette(accent: (0x285E9D, 0x9DBFEC), selection: (0xDFEAF8, 0x30445E),
                                             strong: (0x1D426D, 0xADC9EF), onStrongDark: 0x192E48)
    private static let purple = FileMintPalette(accent: (0x694898, 0xC9AFE9), selection: (0xEDE5F7, 0x463654),
                                               strong: (0x503472, 0xD2B9F0), onStrongDark: 0x37254C)
    private static let amber = FileMintPalette(accent: (0x93521E, 0xEDB784), selection: (0xF6E8D9, 0x503D2D),
                                              strong: (0x723D15, 0xF2C59C), onStrongDark: 0x472B14)
    private static let teal = FileMintPalette(rgb: 0x087D86)
    private static let indigo = FileMintPalette(rgb: 0x4654AC)
    private static let moss = FileMintPalette(rgb: 0x5D721C)
    private static let coral = FileMintPalette(rgb: 0xBD503C)
    private static let rose = FileMintPalette(rgb: 0xAD3D74)
    private static let slate = FileMintPalette(rgb: 0x536B83)

    static func resolve(_ choice: AppAccentColor, customRGB: UInt32? = nil) -> FileMintPalette {
        switch choice {
        case .mint: .mint
        case .blue: .blue
        case .purple: .purple
        case .amber: .amber
        case .teal: .teal
        case .indigo: .indigo
        case .moss: .moss
        case .coral: .coral
        case .rose: .rose
        case .slate: .slate
        case .custom: customRGB.map { FileMintPalette(rgb: $0) } ?? .mint
        }
    }
}

/// The active accent is derived from the main app's committed preferences.
@MainActor
final class FileMintTheme: ObservableObject {
    static let shared = FileMintTheme()
    @Published private(set) var palette = FileMintPalette.mint
    private(set) var accentColor: AppAccentColor = .mint
    private var customRGB: UInt32?

    private init() {}

    func apply(_ preferences: FileMintPreferences) {
        let choice = preferences.accentColor
        let rgb = choice == .custom ? preferences.customAccentRGB : nil
        guard accentColor != choice || customRGB != rgb else { return }
        accentColor = choice
        customRGB = rgb
        palette = FileMintPalette.resolve(choice, customRGB: rgb)
    }
}

private struct FileMintPaletteKey: EnvironmentKey {
    static let defaultValue = FileMintPalette.mint
}

extension EnvironmentValues {
    var fileMintPalette: FileMintPalette {
        get { self[FileMintPaletteKey.self] }
        set { self[FileMintPaletteKey.self] = newValue }
    }
}

@MainActor
private struct FileMintThemeModifier: ViewModifier {
    @ObservedObject private var theme = FileMintTheme.shared

    func body(content: Content) -> some View {
        let palette = theme.palette
        content.environment(\.fileMintPalette, palette).tint(palette.accent)
    }
}

struct MintButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.fileMintPalette) private var palette
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @State private var hovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: primary ? .medium : .regular))
            .padding(.horizontal, 13).padding(.vertical, 8)
            .foregroundStyle(configuration.role == .destructive ? Color.red : primary ? palette.onStrong : Color.primary)
            .background(primary ? palette.strong : hovered && enabled ? FileMintStyle.soft : FileMintStyle.surface,
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(
                focused && enabled ? palette.accent : primary ? Color.clear : FileMintStyle.line,
                lineWidth: focused && enabled ? 1.5 : 0.7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .opacity(enabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .onHover { hovered = $0 }
    }
}

extension View {
    @MainActor func fileMintTheme() -> some View {
        modifier(FileMintThemeModifier())
    }

    func settingsMenu(width: CGFloat? = 180) -> some View {
        self.labelsHidden().pickerStyle(.menu).controlSize(.small).tint(.primary)
            .fixedSize().frame(width: width, alignment: .trailing)
    }

    func mintSurface(padding: CGFloat = 17) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(FileMintStyle.surface, in: RoundedRectangle(cornerRadius: FileMintStyle.radius))
            .overlay(RoundedRectangle(cornerRadius: FileMintStyle.radius).strokeBorder(FileMintStyle.line, lineWidth: 0.7))
    }
}

struct SettingsSectionTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SettingsInsertionIndicator: View {
    @Environment(\.fileMintPalette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Circle().frame(width: 8, height: 8)
            Rectangle().frame(height: 2)
        }
        .foregroundStyle(palette.accent)
        .padding(.horizontal, 12)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// A functional preference group shared by settings pages, not a persistence layer.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsSectionTitle(title: title)
            VStack(alignment: .leading, spacing: 14) { content }.mintSurface()
        }
    }
}

struct SmallSettingsSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Toggle(isOn: configuration.$isOn) { configuration.label }
            .toggleStyle(.switch).controlSize(.small)
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

struct FinderMenuSection<Content: View>: View {
    let language: AppLanguage
    @ViewBuilder var content: Content
    var body: some View {
        SettingsSection(title: language.resolved() == .chinese ? "Finder 菜单" : "Finder Menu") { content }
    }
}

struct CreationPlacementPicker: View {
    @Binding var selection: CreationMenuPlacement
    let language: AppLanguage
    let label: String
    var body: some View {
        Picker(label, selection: $selection) {
            Text(language.resolved() == .chinese ? "隐藏" : "Hidden").tag(CreationMenuPlacement.hidden)
            Text(FileMintStrings.text(.toolMainMenu, language: language)).tag(CreationMenuPlacement.main)
            Text(language.resolved() == .chinese ? "二级菜单" : "Submenu").tag(CreationMenuPlacement.submenu)
        }.settingsMenu(width: language.resolved() == .chinese ? 106 : 124).accessibilityLabel(label)
    }
}

extension CreationMenuAction {
    func detail(_ language: AppLanguage) -> String {
        let pair: (String, String)
        switch self {
        case .newFile: pair = ("Choose a name, format and content before creating.", "填写文件名、格式和内容后创建")
        case .clipboardText: pair = ("Read clipboard text once and confirm before creating.", "读取一次剪贴板文字，确认后创建")
        case .clipboardImage: pair = ("Save one clipboard image as a PNG file.", "将剪贴板中的单张图片保存为 PNG")
        }
        return language.resolved() == .chinese ? pair.1 : pair.0
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
        case .foldersSubtitle: ("Choose where FileMint appears in Finder.", "选择 FileMint 菜单在 Finder 中的显示位置。")
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
