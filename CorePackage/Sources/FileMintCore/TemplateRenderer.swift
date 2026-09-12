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
        if output.contains("{{date}}") { output = output.replacingOccurrences(of: "{{date}}", with: formattedDate(context.createdAt)) }
        if output.contains("{{isoDate}}") { output = output.replacingOccurrences(of: "{{isoDate}}", with: isoDate(context.createdAt)) }
        if output.contains("{{year}}") { output = output.replacingOccurrences(of: "{{year}}", with: year(context.createdAt)) }
        return output
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func year(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return String(calendar.component(.year, from: date))
    }
}
