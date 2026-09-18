import AppKit
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
    }

    var body: some Scene {
        WindowGroup("FileMint Tools UI QA") { FixtureView() }
            .defaultSize(width: 632, height: 600)
            .windowResizability(.contentSize)
    }
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
                NativeToolMenu(language: language).frame(width: 125, height: 24)
            }.padding(10)
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                Text(text(.fileTools)).font(.system(size: 25, weight: .bold))
                Text(text(.fileToolsHint)).font(.callout).foregroundStyle(.secondary)
            }.padding(28)
            Divider().padding(.horizontal, 28)
            FileToolsSettingsView(preferences: $preferences, language: language).padding(28)
        }
        // 840-point minimum app width minus its 208-point sidebar.
        .frame(width: 632, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(dark ? .dark : .light)
        .onAppear { record(preferences) }
        .onChange(of: preferences) { record($0) }
    }

    private func record(_ value: FileToolsPreferences) {
        guard let directory = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String,
              let data = try? JSONEncoder().encode(value) else { return }
        // Readback for regression checks; this path is inside the disposable QA build.
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("last-state.json"), options: .atomic)
    }
}

private struct NativeToolMenu: NSViewRepresentable {
    let language: AppLanguage

    func makeNSView(context: Context) -> NSPopUpButton {
        NSPopUpButton(frame: .zero, pullsDown: true)
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "QA menu icons", action: nil, keyEquivalent: "")
        func addTools(to menu: NSMenu) {
            for tool in FileTool.allCases {
                let item = NSMenuItem(title: FileMintStrings.text(tool.title, language: language),
                                      action: nil, keyEquivalent: "")
                item.image = FileToolAppearance.image(for: tool)
                menu.addItem(item)
            }
            let item = NSMenuItem(title: FileMintStrings.text(.moveSelectedHere, language: language),
                                  action: nil, keyEquivalent: "")
            item.image = FileToolAppearance.moveHereImage
            menu.addItem(item)
        }
        addTools(to: menu)
        let root = NSMenuItem(title: "QA submenu", action: nil, keyEquivalent: "")
        root.image = FileToolAppearance.toolsImage
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        addTools(to: submenu)
        root.submenu = submenu
        menu.addItem(root)
        button.menu = menu
    }
}
