import Foundation

enum BuiltInDocumentTemplate: String, CaseIterable, Sendable {
    // Keep versioned resources immutable so saved references survive upgrades.
    case word = "blank-word-v1"
    case excel = "blank-excel-v1"

    var reference: DocumentTemplateReference {
        switch self {
        case .word:
            DocumentTemplateReference(id: UUID(uuidString: "A3FAD62A-7640-47E3-AC46-586F606E16A1")!,
                kind: .docx, byteCount: 32025,
                sha256: "91229fe32398a1d5e2e0472ef97cafd62832377250985a8211547e23c65de277",
                builtInResource: rawValue)
        case .excel:
            DocumentTemplateReference(id: UUID(uuidString: "9F3F7176-ED5B-4B06-8F9C-28A42EC210FA")!,
                kind: .xlsx, byteCount: 4661,
                sha256: "209dbc4d36351b06843dfe287fb761a06b490a7f644a58dc4029add604b0945c",
                builtInResource: rawValue)
        }
    }

    var template: FileTemplate {
        let reference = reference
        var template = FileTemplate(id: self == .word ? "word-document" : "excel-workbook",
            displayName: self == .word ? "Word Document" : "Excel Workbook",
            suggestedFileName: "Untitled.\(reference.kind.rawValue)", group: "Office", content: "",
            rank: self == .word ? 150 : 160, fileExtension: reference.kind.rawValue)
        template.document = reference
        return template
    }

    static var resourceDirectory: URL? {
        resourceDirectory(in: [Bundle.main, Bundle(for: ResourceBundleAnchor.self)])
    }

    static func resourceDirectory(in hostBundles: [Bundle]) -> URL? {
        // Like SwiftPM's accessor, but a missing bundle must report a recoverable
        // document error rather than fatalError or use a developer's build path.
        var candidates = hostBundles.map(\.resourceURL) + hostBundles.map { Optional($0.bundleURL) }
        // The native SwiftPM engine puts resource bundles beside its .xctest,
        // while Bundle.main can belong to swiftpm-testing-helper or xctest.
        // Ordinary app/extension hosts must still use their own bundled resources.
        candidates += hostBundles.filter { $0.bundleURL.pathExtension == "xctest" }
            .map { $0.bundleURL.deletingLastPathComponent() }
        for candidate in candidates {
            if let url = candidate?.appendingPathComponent("FileMintCore_FileMintCore.bundle"),
               let bundle = Bundle(url: url), let resources = bundle.resourceURL {
                return resources.appendingPathComponent("OfficeTemplates", isDirectory: true)
            }
        }
        return nil
    }
}

private final class ResourceBundleAnchor {}
