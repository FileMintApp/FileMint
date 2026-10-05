import Foundation

public enum CreationContentResolver {
    public static let exampleDate = Date(timeIntervalSince1970: 1_767_225_600) // 2026-01-01 UTC
    public static func text(template: FileTemplate, fileName: String, mode: FileContentMode, capturedAt: Date) -> String {
        mode == .verbatim ? template.content : TemplateRenderer.render(template,
            context: .init(fileName: FilenamePolicy.sanitizedFileName(fileName), createdAt: capturedAt))
    }
}
