import Foundation

public struct TemplateContext: Sendable {
    public var fileName: String
    public var createdAt: Date

    public init(fileName: String, createdAt: Date) {
        self.fileName = fileName
        self.createdAt = createdAt
    }
}

public enum TemplateRenderer {
    public static func render(_ template: FileTemplate, context: TemplateContext) -> String {
        var output = template.content
        output = output.replacingOccurrences(of: "{{fileName}}", with: context.fileName)
        output = output.replacingOccurrences(of: "{{date}}", with: formattedDate(context.createdAt))
        output = output.replacingOccurrences(of: "{{isoDate}}", with: isoDate(context.createdAt))
        output = output.replacingOccurrences(of: "{{year}}", with: year(context.createdAt))
        return output
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func year(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        return String(calendar.component(.year, from: date))
    }
}
