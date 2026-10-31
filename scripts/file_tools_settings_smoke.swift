import AppKit
import Darwin
import FileMintCore
import SwiftUI

/// Uses the production SwiftUI surface and native images with in-memory preferences.
/// Never opens a user's preferences, performs a file operation or registers an extension.
@main
struct FileToolsSettingsSmoke: App {
    init() {
        for tool in FileTool.allCases {
            for size: CGFloat in [16, 20] {
                guard let image = FileToolAppearance.image(for: tool, size: size),
                      image.size == NSSize(width: size, height: size), !image.isTemplate,
                      let raster = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else { fatalError("Missing native icon: \(tool.rawValue)") }
                let pixels = NSBitmapImageRep(cgImage: raster)
                let hasColor = (0..<pixels.pixelsHigh).contains { y in
                    (0..<pixels.pixelsWide).contains { x in
                        guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                              color.alphaComponent > 0.5 else { return false }
                        return max(color.redComponent, color.greenComponent, color.blueComponent)
                            - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.1
                    }
                }
                precondition(hasColor, "Icon lost its color: \(tool.rawValue)")
            }
        }
        precondition(FileToolAppearance.toolsImage != nil && FileToolAppearance.moveHereImage != nil)
        verifyIconStyles()
        if CommandLine.arguments.contains("--verify-icons") { exit(0) }
    }

    var body: some Scene {
        WindowGroup("FileMint Tools UI QA") { FixtureView() }
            .defaultSize(width: 632, height: 600)
            .windowResizability(.contentSize)
    }
}

private func verifyIconStyles() {
    func checkMenuPixels(_ image: NSImage, dark: Bool, label: String) {
        guard let raster = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { fatalError("Missing transferred menu image: \(label)") }
        let pixels = NSBitmapImageRep(cgImage: raster)
        var visible = 0
        for y in 0..<pixels.pixelsHigh {
            for x in 0..<pixels.pixelsWide {
                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.5 else { continue }
                visible += 1
                let channels = [color.redComponent, color.greenComponent, color.blueComponent]
                precondition(channels.max()! - channels.min()! < 0.03, "Menu icon gained color: \(label)")
                precondition(dark ? channels.min()! > 0.98 : channels.max()! < 0.02,
                             "Unreadable \(dark ? "dark" : "light") menu pixels: \(label)")
            }
        }
        precondition(visible > 0, "Empty transferred menu icon: \(label)")
        precondition(visible < pixels.pixelsHigh * pixels.pixelsWide, "Menu icon lost transparency: \(label)")
    }
    func checkFinderTransfer(_ source: NSImage, label: String) {
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
            let foreground = MonochromeMenuForeground(appearance: appearance)
            guard let image = FileToolAppearance.finderMenuImage(source, foreground: foreground),
                  !image.isTemplate, source.isTemplate,
                  image.size == source.size, let tiff = image.tiffRepresentation,
                  let transferred = NSImage(data: tiff) else { fatalError("Missing Finder menu image: \(label)") }
            let bitmaps = image.representations.compactMap { $0 as? NSBitmapImageRep }
            precondition(bitmaps.count == 2, "Missing 1x/2x menu representations: \(label)")
            for (index, bitmap) in bitmaps.enumerated() {
                let scale = index + 1
                precondition(bitmap.pixelsWide == Int(source.size.width) * scale &&
                             bitmap.pixelsHigh == Int(source.size.height) * scale,
                             "Incorrect menu pixel size: \(label)")
                let representation = NSImage(size: source.size)
                representation.addRepresentation(bitmap)
                checkMenuPixels(representation, dark: dark, label: "\(label)-\(scale)x")
            }
            precondition(!transferred.isTemplate, "TIFF fixture must exercise loss of template metadata")
            precondition(transferred.size == source.size, "Transferred menu size changed: \(label)")
            checkMenuPixels(transferred, dark: dark, label: "\(label)-TIFF")
        }
    }
    func check(_ image: NSImage?, style: FinderMenuIconStyle, label: String) {
        guard let image, image.isTemplate == (style == .systemMonochrome),
              let raster = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { fatalError("Missing icon or incorrect rendering mode: \(label)") }
        let pixels = NSBitmapImageRep(cgImage: raster)
        var visible = false
        var hasColor = false
        for y in 0..<pixels.pixelsHigh {
            for x in 0..<pixels.pixelsWide {
                guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.5 else { continue }
                visible = true
                if max(color.redComponent, color.greenComponent, color.blueComponent)
                    - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.1 { hasColor = true }
            }
        }
        precondition(visible, "Empty icon: \(label)")
        precondition(style == .colored ? hasColor : !hasColor, "Unexpected icon colors: \(label)")
        if style == .systemMonochrome { checkFinderTransfer(image, label: label) }
        else {
            let foreground = MonochromeMenuForeground(appearance: NSAppearance(named: .darkAqua)!)
            precondition(FileToolAppearance.finderMenuImage(image, foreground: foreground) === image,
                         "Colored image was replaced: \(label)")
        }
    }
    precondition(Bundle.main.image(forResource: "FinderMenuIcon") != nil)
    precondition(Bundle.main.image(forResource: "FinderRootMenuIcon") != nil)
    let custom = MenuIconCustomization(symbolName: "folder.fill.badge.plus", primaryHex: "#CC3300", secondaryHex: "#0066CC")!
    let missing = MenuIconCustomization(symbolName: "filemint.missing.symbol", primaryHex: "#CC3300", secondaryHex: "#0066CC")!
    for style in FinderMenuIconStyle.allCases {
        for slot in MenuIconSlot.allCases {
            check(FileToolAppearance.image(for: slot, defaultBundle: .main, style: style),
                style: style, label: slot.rawValue)
            check(FileToolAppearance.image(for: slot, customization: custom, defaultBundle: .main, style: style),
                style: style, label: "custom-\(slot.rawValue)")
            check(FileToolAppearance.image(for: slot, customization: missing, defaultBundle: .main, style: style),
                style: style, label: "fallback-\(slot.rawValue)")
        }
        for var template in TemplateCatalog.builtInTemplates {
            check(FileToolAppearance.image(for: template, style: style), style: style, label: template.id)
            template.customMenuIcon = custom
            check(FileToolAppearance.image(for: template, style: style), style: style, label: "custom-\(template.id)")
            template.customMenuIcon = missing
            check(FileToolAppearance.image(for: template, style: style), style: style, label: "fallback-\(template.id)")
        }
    }
    if let directory = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String {
        let output = URL(fileURLWithPath: directory).appendingPathComponent("invocation-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
        print("QA_RUNTIME_ROOT \(output.path)")
        let result = ["passed": true, "styles": FinderMenuIconStyle.allCases.map(\.rawValue),
                      "slots": MenuIconSlot.allCases.count, "templates": TemplateCatalog.builtInTemplates.count,
                      "menuAppearances": ["aqua", "darkAqua"], "menuScales": [1, 2],
                      "menuTransfer": "TIFF", "menuImagesAreTemplates": false] as [String: Any]
        let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        try! data.write(to: output.appendingPathComponent("icon-rendering-checks.json"))
    }
    print("PASS native icon styles and light/dark 1x/2x monochrome menu pixels after TIFF transfer")
}

private struct FixtureView: View {
    @State private var preferences: FileToolsPreferences = {
        var value = FileToolsPreferences()
        value.isEnabled = true
        value.permanentDelete = true
        return value
    }()
    @State private var language = AppLanguage.chinese
    @State private var dark = false
    @State private var menuIcons: [String: MenuIconCustomization] = [:]
    @State private var iconStyle = FinderMenuIconStyle.colored

    private func text(_ key: FileMintTextKey) -> String {
        FileMintStrings.text(key, language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Picker("QA language", selection: $language) {
                    Text("中文").tag(AppLanguage.chinese)
                    Text("English").tag(AppLanguage.english)
                }.frame(width: 180)
                Toggle("QA dark", isOn: $dark).toggleStyle(.checkbox)
                Spacer()
                NativeToolMenu(language: language, menuIcons: menuIcons, style: iconStyle, dark: dark)
                    .frame(width: 125, height: 24)
            }.padding(10)
            PreferenceRow(title: text(.finderMenuIconStyle)) {
                FinderMenuIconStylePicker(selection: $iconStyle, language: language)
            }.padding(.horizontal, 10).padding(.bottom, 10)
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Text(text(.fileTools)).font(.system(size: 25, weight: .bold))
                Text(text(.fileToolsHint)).font(.callout).foregroundStyle(.secondary)
            }.padding(28)
            Divider().padding(.horizontal, 28)
            FileToolsSettingsView(preferences: $preferences, language: language, menuIcons: $menuIcons).padding(28)
        }
        // 840-point minimum app width minus its 208-point sidebar.
        .frame(width: 632, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(dark ? .dark : .light)
        .environment(\.finderMenuIconStyle, iconStyle)
        .onAppear { record(preferences); recordIcons() }
        .onChange(of: preferences) { record($0) }
        .onChange(of: iconStyle) { _ in recordIcons() }
        .onChange(of: menuIcons) { _ in recordIcons() }
    }

    private func record(_ value: FileToolsPreferences) {
        guard let directory = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String,
              let data = try? JSONEncoder().encode(value) else { return }
        // Readback for regression checks; this path is inside the disposable QA build.
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("last-state.json"), options: .atomic)
    }

    private func recordIcons() {
        struct IconState: Encodable {
            let style: FinderMenuIconStyle
            let icons: [String: MenuIconCustomization]
        }
        guard let directory = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String,
              let data = try? JSONEncoder().encode(IconState(style: iconStyle, icons: menuIcons)) else { return }
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("last-icons-state.json"), options: .atomic)
    }
}

private struct NativeToolMenu: NSViewRepresentable {
    let language: AppLanguage
    let menuIcons: [String: MenuIconCustomization]
    let style: FinderMenuIconStyle
    let dark: Bool

    func makeNSView(context: Context) -> NSPopUpButton {
        NSPopUpButton(frame: .zero, pullsDown: true)
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        button.appearance = appearance
        let foreground = style == .systemMonochrome ? MonochromeMenuForeground(appearance: appearance) : nil
        func menuImage(_ image: NSImage?) -> NSImage? {
            FileToolAppearance.finderMenuImage(image, foreground: foreground)
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "QA menu icons", action: nil, keyEquivalent: "")
        func addTools(to menu: NSMenu) {
            for tool in FileTool.allCases {
                let item = NSMenuItem(title: FileMintStrings.text(tool.title, language: language),
                                      action: nil, keyEquivalent: "")
                item.image = menuImage(FileToolAppearance.image(for: tool,
                    customization: menuIcons[tool.menuIconSlot.rawValue], style: style))
                menu.addItem(item)
            }
            let item = NSMenuItem(title: FileMintStrings.text(.moveSelectedHere, language: language),
                                  action: nil, keyEquivalent: "")
            item.image = menuImage(FileToolAppearance.image(for: .moveHere,
                customization: menuIcons[MenuIconSlot.moveHere.rawValue], style: style))
            menu.addItem(item)
        }
        addTools(to: menu)
        let root = NSMenuItem(title: "QA submenu", action: nil, keyEquivalent: "")
        root.image = menuImage(FileToolAppearance.image(for: .fileTools,
            customization: menuIcons[MenuIconSlot.fileTools.rawValue], style: style))
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        addTools(to: submenu)
        root.submenu = submenu
        menu.addItem(root)
        button.menu = menu
    }
}
