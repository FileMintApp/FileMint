import AppKit
import FileMintCore
import SwiftUI

private struct FinderMenuIconStyleKey: EnvironmentKey {
    static let defaultValue: FinderMenuIconStyle = .colored
}

extension EnvironmentValues {
    var finderMenuIconStyle: FinderMenuIconStyle {
        get { self[FinderMenuIconStyleKey.self] }
        set { self[FinderMenuIconStyleKey.self] = newValue }
    }
}

struct FinderMenuIconStylePicker: View {
    @Binding var selection: FinderMenuIconStyle
    let language: AppLanguage

    var body: some View {
        Picker(FileMintStrings.text(.finderMenuIconStyle, language: language), selection: $selection) {
            ForEach(FinderMenuIconStyle.allCases) { style in
                Text(FileMintStrings.text(style.title, language: language)).tag(style)
            }
        }.settingsMenu().accessibilityIdentifier("settings.finderMenuIconStyle")
    }
}

/// App-only editor. Finder receives only the saved symbol name and colors.
struct MenuIconControl: View {
    @Environment(\.finderMenuIconStyle) private var style
    @Binding private var customization: MenuIconCustomization?
    let language: AppLanguage
    private let target: Target
    @State private var editing = false

    private enum Target {
        case slot(MenuIconSlot)
        case template(FileTemplate)

        var symbol: String {
            switch self {
            case .slot(let slot): slot.defaultSymbolName
            case .template(let template): TemplateCatalog.defaultMenuSymbol(forSuffix: template.fileExtension)
            }
        }
        var colors: (NSColor, NSColor) {
            switch self {
            case .slot(let slot): FileToolAppearance.defaultColors(for: slot)
            case .template(let template): FileToolAppearance.defaultColors(for: template)
            }
        }
        var allowedRestrictedName: String? {
            if case .slot(.airDrop) = self { return MenuIconSlot.airDrop.defaultSymbolName }
            return nil
        }
        func image(customization: MenuIconCustomization?, size: CGFloat, style: FinderMenuIconStyle) -> NSImage? {
            switch self {
            case .slot(let slot):
                return FileToolAppearance.image(for: slot, customization: customization, size: size,
                    defaultBundle: Bundle.main, style: style)
            case .template(var template):
                template.customMenuIcon = customization
                return FileToolAppearance.image(for: template, size: size, style: style)
            }
        }
    }

    init(slot: MenuIconSlot, customization: Binding<MenuIconCustomization?>, language: AppLanguage) {
        self._customization = customization
        self.language = language
        self.target = .slot(slot)
    }

    init(template: FileTemplate, customization: Binding<MenuIconCustomization?>, language: AppLanguage) {
        self._customization = customization
        self.language = language
        self.target = .template(template)
    }

    static func rowTitle(_ language: AppLanguage) -> String {
        language.resolved() == .chinese ? "图标" : "Icon"
    }

    var body: some View {
        Button { editing = true } label: {
            HStack(spacing: 7) {
                if let icon = target.image(customization: customization, size: 18, style: style) {
                    Image(nsImage: icon).renderingMode(style == .systemMonochrome ? .template : .original)
                        .resizable().interpolation(.high).foregroundStyle(.primary)
                        .frame(width: 18, height: 18).accessibilityHidden(true)
                }
                Text(MenuIconText.choose(language))
            }
        }
        .accessibilityIdentifier("menuIcon.choose")
        .popover(isPresented: $editing, arrowEdge: .trailing) {
            MenuIconEditor(customization: $customization, defaultSymbol: target.symbol,
                defaultColors: target.colors, allowedRestrictedName: target.allowedRestrictedName,
                language: language, style: style)
        }
    }
}

private struct MenuIconEditor: View {
    @Environment(\.fileMintPalette) private var palette
    @Binding var customization: MenuIconCustomization?
    let defaultSymbol: String
    let defaultColors: (NSColor, NSColor)
    let allowedRestrictedName: String?
    let language: AppLanguage
    let style: FinderMenuIconStyle
    @Environment(\.dismiss) private var dismiss
    @State private var symbolName: String
    @State private var search = ""
    @State private var visibleCount = 88
    @State private var primary: Color
    @State private var secondary: Color

    init(customization: Binding<MenuIconCustomization?>, defaultSymbol: String,
         defaultColors: (NSColor, NSColor), allowedRestrictedName: String?, language: AppLanguage,
         style: FinderMenuIconStyle) {
        self._customization = customization
        self.defaultSymbol = defaultSymbol
        self.defaultColors = defaultColors
        self.allowedRestrictedName = allowedRestrictedName
        self.language = language
        self.style = style
        self._symbolName = State(initialValue: customization.wrappedValue?.symbolName ?? defaultSymbol)
        let first = customization.wrappedValue.flatMap { Self.color($0.primaryHex) } ?? defaultColors.0
        let second = customization.wrappedValue.flatMap { Self.color($0.secondaryHex) } ?? defaultColors.1
        self._primary = State(initialValue: Color(nsColor: first))
        self._secondary = State(initialValue: Color(nsColor: second))
    }

    private var proposed: MenuIconCustomization? {
        MenuIconCustomization(symbolName: symbolName, primaryHex: Self.hex(primary), secondaryHex: Self.hex(secondary))
    }
    private var preview: NSImage? {
        guard !isRestricted else { return nil }
        return proposed.flatMap { FileToolAppearance.image(for: $0, size: 32, style: style) }
    }
    private var isRestricted: Bool {
        symbolName != allowedRestrictedName && SystemSymbolCatalog.isRestricted(symbolName)
    }
    private var matches: [String] { SystemSymbolCatalog.matching(search) }
    private var visibleSymbols: [String] {
        matches.prefix(visibleCount).filter(SystemSymbolCatalog.isAvailable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(MenuIconText.title(language)).font(.headline)
            HStack(spacing: 12) {
                Group {
                    if let preview {
                        Image(nsImage: preview).renderingMode(style == .systemMonochrome ? .template : .original)
                            .resizable().interpolation(.high).foregroundStyle(.primary).frame(width: 32, height: 32)
                    }
                    else { Image(systemName: "questionmark.square.dashed").frame(width: 32, height: 32) }
                }.accessibilityHidden(true)
                TextField(MenuIconText.symbolName(language), text: $symbolName)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("menuIcon.symbolName")
            }
            if preview == nil {
                Text(isRestricted ? MenuIconText.restricted(language) : MenuIconText.unavailable(language))
                    .font(.caption).foregroundStyle(.red)
            }
            TextField(MenuIconText.search(language), text: $search)
                .textFieldStyle(.roundedBorder).accessibilityIdentifier("menuIcon.catalogSearch")
                .onChange(of: search) { _ in visibleCount = 88 }
            HStack {
                Text(MenuIconText.catalog(language)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(visibleSymbols.count) / \(matches.count)").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34)), count: 8), spacing: 5) {
                    ForEach(visibleSymbols, id: \.self) { name in
                        Button { symbolName = name } label: {
                            Image(systemName: name).font(.system(size: 17)).frame(width: 32, height: 32)
                                .background(symbolName == name ? palette.selection : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain).help(name).accessibilityLabel(name)
                    }
                }
                if matches.count > visibleCount {
                    Button(MenuIconText.more(language)) { visibleCount += 88 }
                        .padding(.top, 8).accessibilityIdentifier("menuIcon.loadMore")
                }
            }.frame(height: 225).id(search)
            HStack(spacing: 14) {
                ColorPicker(MenuIconText.primary(language), selection: $primary, supportsOpacity: false)
                ColorPicker(MenuIconText.secondary(language), selection: $secondary, supportsOpacity: false)
            }.disabled(style == .systemMonochrome)
            Text(style == .systemMonochrome ? MenuIconText.monochromeHint(language) : MenuIconText.colorHint(language))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(MenuIconText.reset(language)) { customization = nil; dismiss() }
                Spacer()
                Button(MenuIconText.cancel(language)) { dismiss() }
                Button(MenuIconText.save(language)) {
                    guard preview != nil, let proposed else { return }
                    customization = proposed
                    dismiss()
                }.disabled(preview == nil).keyboardShortcut(.defaultAction)
            }
        }
        .padding(18).frame(width: 346)
        .onAppear {
            symbolName = customization?.symbolName ?? defaultSymbol
            search = ""
            visibleCount = 88
            primary = Color(nsColor: customization.flatMap { Self.color($0.primaryHex) } ?? defaultColors.0)
            secondary = Color(nsColor: customization.flatMap { Self.color($0.secondaryHex) } ?? defaultColors.1)
        }
    }

    private static func color(_ hex: String) -> NSColor? {
        guard hex.count == 7 else { return nil }
        let text = Array(hex.dropFirst())
        func component(_ index: Int) -> CGFloat? {
            Int(String(text[index...(index + 1)]), radix: 16).map { CGFloat($0) / 255 }
        }
        guard let red = component(0), let green = component(2), let blue = component(4) else { return nil }
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    private static func hex(_ color: Color) -> String {
        let value = NSColor(color).usingColorSpace(.sRGB) ?? .systemBlue
        func channel(_ component: CGFloat) -> Int { max(0, min(255, Int((component * 255).rounded()))) }
        return String(format: "#%02X%02X%02X", channel(value.redComponent), channel(value.greenComponent), channel(value.blueComponent))
    }
}

private enum MenuIconText {
    private static func text(_ language: AppLanguage, _ english: String, _ chinese: String) -> String {
        language.resolved() == .chinese ? chinese : english
    }
    static func choose(_ language: AppLanguage) -> String { text(language, "Icon…", "图标…") }
    static func title(_ language: AppLanguage) -> String { text(language, "Menu Icon", "菜单图标") }
    static func symbolName(_ language: AppLanguage) -> String { text(language, "SF Symbol name", "SF Symbol 名称") }
    static func unavailable(_ language: AppLanguage) -> String { text(language, "Symbol unavailable on this Mac", "此 Mac 上没有该符号") }
    static func restricted(_ language: AppLanguage) -> String { text(language, "This symbol has usage restrictions", "此符号有使用限制") }
    static func search(_ language: AppLanguage) -> String { text(language, "Search system symbols", "搜索系统符号") }
    static func catalog(_ language: AppLanguage) -> String { text(language, "System symbols", "系统符号") }
    static func more(_ language: AppLanguage) -> String { text(language, "Show more", "显示更多") }
    static func primary(_ language: AppLanguage) -> String { text(language, "Main", "主色") }
    static func secondary(_ language: AppLanguage) -> String { text(language, "Accent", "辅色") }
    static func colorHint(_ language: AppLanguage) -> String { text(language, "Some symbols use only the main color.", "部分符号只使用主色。") }
    static func monochromeHint(_ language: AppLanguage) -> String { text(language, "System Monochrome is on. Switch to Colored in General → Appearance to edit colors; your saved colors are preserved.", "已启用系统单色。可在通用 → 外观切回彩色后编辑配色；已保存的颜色会保留。") }
    static func reset(_ language: AppLanguage) -> String { text(language, "Use Default", "恢复默认") }
    static func cancel(_ language: AppLanguage) -> String { text(language, "Cancel", "取消") }
    static func save(_ language: AppLanguage) -> String { text(language, "Save", "保存") }
}
