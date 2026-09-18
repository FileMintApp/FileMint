import AppKit
import CoreGraphics
import CoreText
import ImageIO
import SwiftUI
import FileMintCore

/// A stand-in for settings only. It never reads the owner's preferences.
@MainActor
final class PreferencesModel: ObservableObject {
    @Published var preferences = FileMintPreferences.default
    func save() {}
}

@MainActor
final class FileOperationCoordinator {
    static let shared = FileOperationCoordinator()
    func chooseImages(for tool: ResourceTool) {}
}

@main
@MainActor
final class ResourceToolsSmoke: NSObject, NSApplicationDelegate {
    private var activeController: ResourceToolsController?
    private var settingsWindow: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = ResourceToolsSmoke()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do { try await exercise() }
            catch { print("FAIL resource native fixture: \(error)"); exit(1) }
            NSApp.terminate(nil)
        }
    }

    private func exercise() async throws {
        for tool in ResourceTool.allCases {
            for size in [16.0, 20.0] {
                guard let image = FileToolAppearance.image(for: tool, size: size),
                      image.size == NSSize(width: size, height: size), !image.isTemplate,
                      let raster = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else { throw ResourceError.failed }
                let pixels = NSBitmapImageRep(cgImage: raster)
                let hasColor = (0..<pixels.pixelsHigh).contains { y in
                    (0..<pixels.pixelsWide).contains { x in
                        guard let color = pixels.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                              color.alphaComponent > 0.5 else { return false }
                        return max(color.redComponent, color.greenComponent, color.blueComponent)
                            - min(color.redComponent, color.greenComponent, color.blueComponent) > 0.1
                    }
                }
                guard hasColor else { throw ResourceError.failed }
            }
        }
        guard FileToolAppearance.resourceToolsImage != nil else { throw ResourceError.failed }
        guard let path = Bundle.main.object(forInfoDictionaryKey: "FixturePath") as? String else {
            throw ResourceError.failed
        }
        let root = URL(fileURLWithPath: path, isDirectory: true)
        let preferencesFile = root.appendingPathComponent("fixture-preferences.json")
        var preferences = FileMintPreferences.default
        preferences.monitoredFolderURLs = [root]
        preferences.resourceTools.isEnabled = true
        let first = root.appendingPathComponent("示例图片.png"), second = root.appendingPathComponent("Second image.png")
        try makeImage(first, blue: false)
        try makeImage(second, blue: true)
        let original = try Data(contentsOf: first)
        for (language, appearance) in [(AppLanguage.chinese, NSAppearance.Name.aqua), (.english, .darkAqua)] {
            NSApp.appearance = NSAppearance(named: appearance)
            preferences.language = language
            try FileMintPreferencesStore(fileURL: preferencesFile).save(preferences)
            let model = PreferencesModel()
            model.preferences = preferences
            let settings = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 632, height: 600),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            settings.isReleasedWhenClosed = false
            settings.appearance = NSAppearance(named: appearance)
            settings.contentView = NSHostingView(rootView: ResourceToolsPane().environmentObject(model).padding(28))
            settingsWindow = settings
            settings.center()
            settings.makeKeyAndOrderFront(nil)
            try await Task.sleep(for: .milliseconds(250))
            model.preferences.resourceTools.isEnabled = false
            try await Task.sleep(for: .milliseconds(100))
            settings.close()
            settingsWindow = nil

            for tool in ResourceTool.allCases {
                let controller = ResourceToolsController(preferencesFile: preferencesFile)
                activeController = controller
                let present = Task { try await controller.present(selection: [first, second], tool: tool) }
                try await waitUntil { !controller.inputs.isEmpty && !controller.isPreparing }
                let panel = try require(NSApp.windows.first { $0 is NSPanel && $0.isVisible })
                guard NSApp.isActive, panel.isKeyWindow else { throw ResourceError.failed }
                panel.appearance = NSAppearance(named: appearance)
                panel.setContentSize(NSSize(width: 820, height: 560))
                try await Task.sleep(for: .milliseconds(180))
                if ProcessInfo.processInfo.environment["FILEMINT_RESOURCE_INTERACTIVE"] == "1", tool == .stitch {
                    print("READY interactive \(language.rawValue)")
                    try await present.value
                    activeController = nil
                    continue
                }
                // Production Run action, engine and UI progress with fixture preferences.
                if tool == .stitch {
                    controller.options.stitchEdge = 6000
                    controller.run()
                    try await waitUntil { !controller.isRunning && controller.result != nil }
                    guard controller.result?.failure == .dimensionsTooLarge,
                          controller.result?.completed == 0 else { throw ResourceError.failed }
                    controller.editOptions()
                    guard controller.result == nil else { throw ResourceError.failed }
                    controller.options.stitchEdge = 1024
                }
                controller.run()
                try await waitUntil { !controller.isRunning && controller.result != nil }
                guard let result = controller.result, result.failure == nil, result.completed == 2 else {
                    throw controller.result?.failure ?? ResourceError.failed
                }
                if tool == .ocr {
                    guard controller.hasText, controller.text.contains("FILEMINT") else { throw ResourceError.noText }
                    controller.setEditedText("")
                    guard !controller.hasText else { throw ResourceError.failed }
                    controller.setEditedText("Edited OCR\n{{year}}\n")
                    guard controller.hasText, controller.text == "Edited OCR\n{{year}}\n" else { throw ResourceError.failed }
                }
                try await Task.sleep(for: .milliseconds(100))
                print("PASS native \(tool.rawValue) \(language.rawValue), completed=\(result.completed)")
                controller.cancel()
                try await present.value
                activeController = nil
            }
        }
        guard try Data(contentsOf: first) == original else { throw ResourceError.sourceChanged }
        print("PASS original preserved; clipboard untouched; no owner preferences loaded; fixture=\(root.path)")
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<1200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ResourceError.failed
    }

    private func require<T>(_ value: T?) throws -> T {
        guard let value else { throw ResourceError.failed }
        return value
    }

    private func makeImage(_ url: URL, blue: Bool) throws {
        let context = try require(CGContext(data: nil, width: 800, height: 300, bitsPerComponent: 8,
            bytesPerRow: 3200, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(blue ? CGColor(red: 0.85, green: 0.93, blue: 1, alpha: 1) : CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 300))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 60, nil)
        let line = NSAttributedString(string: "FILEMINT 12345", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
        ])
        context.textPosition = CGPoint(x: 30, y: 140)
        CTLineDraw(CTLineCreateWithAttributedString(line), context)
        let image = try require(context.makeImage())
        let output = try require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw ResourceError.encodingFailed }
    }
}
