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
    private static let tokenPattern = try! NSRegularExpression(pattern: #"\{\{(fileName|date|isoDate|year)\}\}"#)

    public static func render(_ template: FileTemplate, context: TemplateContext) -> String {
        guard template.content.contains("{{") else { return template.content }
        let source = template.content as NSString
        let matches = tokenPattern.matches(in: template.content, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return template.content }
        let output = NSMutableString(string: template.content)
        var replacements: [String: String] = [:]
        for match in matches.reversed() {
            let token = source.substring(with: match.range(at: 1))
            let replacement: String
            if let cached = replacements[token] { replacement = cached }
            else {
                switch token {
                case "fileName": replacement = context.fileName
                case "date": replacement = formattedDate(context.createdAt)
                case "isoDate": replacement = isoDate(context.createdAt)
                default: replacement = year(context.createdAt)
                }
                replacements[token] = replacement
            }
            output.replaceCharacters(in: match.range, with: replacement)
        }
        return output as String
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
