import Foundation

public struct HarnessDiagnostic: Error, Encodable, Equatable, Sendable {
    public let code: String
    public let path: String
    public let message: String

    static func operationError(_ error: any Error) -> String {
        let value = error as NSError
        // NSError userInfo/localizedDescription can contain filesystem paths.
        return "\(String(value.domain.prefix(80)).debugDescription), code \(value.code)"
    }

    static func decoding(_ error: any Error) -> HarnessDiagnostic {
        if let issue = error as? HarnessDiagnostic { return issue }
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            return HarnessDiagnostic(code: "missingField", path: harnessPath(context.codingPath + [key]), message: "Required field is missing")
        case DecodingError.typeMismatch(_, let context):
            return HarnessDiagnostic(code: "fieldType", path: harnessPath(context.codingPath), message: "Value has the wrong type")
        case DecodingError.valueNotFound(_, let context):
            return HarnessDiagnostic(code: "nullField", path: harnessPath(context.codingPath), message: "Required value cannot be null")
        case DecodingError.dataCorrupted(let context):
            return HarnessDiagnostic(code: "invalidJSON", path: harnessPath(context.codingPath), message: "Invalid JSON value")
        default:
            return HarnessDiagnostic(code: "input", path: "$", message: "Cannot load suite input")
        }
    }
}

public struct HarnessAssertion: Encodable, Sendable {
    public let path: String
    public let passed: Bool
    public let expected: String
    public let actual: String

    static func bytes(path: String, expected: Data, actual: Data) -> HarnessAssertion {
        let equal = expected == actual
        let difference = zip(expected, actual).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
            ?? min(expected.count, actual.count)
        return HarnessAssertion(path: path, passed: equal, expected: byteSummary(expected),
                                actual: byteSummary(actual) + (equal ? "" : "; first difference at byte \(difference)"))
    }

    static func byteSummary(_ data: Data) -> String {
        // Slice bytes before decoding so diagnostics remain bounded for large values.
        let prefix = String(decoding: data.prefix(160), as: UTF8.self).debugDescription
        return "\(data.count) bytes: \(prefix)\(data.count > 160 ? "…" : "")"
    }

    static func text(_ value: String) -> String {
        String(value.prefix(160)).debugDescription + (value.count > 160 ? "…" : "")
    }
}

public enum HarnessStatus: String, Encodable, Sendable {
    case passed, failed, error
}

public struct HarnessCaseReport: Encodable, Sendable {
    public let id: String
    public let name: String
    public let assertions: [HarnessAssertion]
    public let errors: [HarnessDiagnostic]
    public let status: HarnessStatus

    init(id: String, name: String, assertions: [HarnessAssertion], errors: [HarnessDiagnostic] = []) {
        self.id = id
        self.name = name
        self.assertions = assertions
        self.errors = errors
        status = !errors.isEmpty ? .error : (!assertions.isEmpty && assertions.allSatisfy(\.passed) ? .passed : .failed)
    }
}

public struct HarnessReport: Encodable, Sendable {
    public let declaredCases: Int
    public let cases: [HarnessCaseReport]
    public let errors: [HarnessDiagnostic]
    private let usage: Bool

    init(declaredCases: Int, cases: [HarnessCaseReport], errors: [HarnessDiagnostic] = [], usage: Bool = false) {
        self.declaredCases = declaredCases
        self.cases = cases
        self.errors = errors
        self.usage = usage
    }

    public var status: HarnessStatus {
        if !errors.isEmpty || declaredCases == 0 || cases.count != declaredCases || cases.contains(where: { $0.status == .error }) { return .error }
        return cases.contains(where: { $0.status == .failed }) ? .failed : .passed
    }

    public var exitCode: Int32 {
        if usage { return 64 }
        switch status {
        case .passed: return 0
        case .failed: return 1
        case .error: return 2
        }
    }

    public static func inputError(_ error: any Error) -> HarnessReport {
        HarnessReport(declaredCases: 0, cases: [], errors: [.decoding(error)])
    }

    public static func usageError() -> HarnessReport {
        HarnessReport(declaredCases: 0, cases: [], errors: [
            HarnessDiagnostic(code: "usage", path: "$", message: "Usage: filemint-harness <suite.json> [--format text|json]")
        ], usage: true)
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public func text() -> String {
        var lines: [String] = []
        for item in cases {
            lines.append("\(item.status.rawValue.uppercased()) \(HarnessAssertion.text(item.id)) assertions=\(item.assertions.count)")
            for check in item.assertions where !check.passed {
                lines.append("  \(HarnessAssertion.text(check.path)): expected \(check.expected); actual \(check.actual)")
            }
            lines += item.errors.map { "  ERROR \($0.code) \(HarnessAssertion.text($0.path)): \($0.message)" }
        }
        lines += errors.map { "ERROR \($0.code) \(HarnessAssertion.text($0.path)): \($0.message)" }
        lines.append("\(status.rawValue.uppercased()) suite: \(cases.count)/\(declaredCases) cases executed, " +
                     "\(cases.filter { $0.status == .passed }.count) passed, \(cases.filter { $0.status == .failed }.count) failed, " +
                     "\(cases.filter { $0.status == .error }.count) case errors, \(errors.count) suite errors")
        return lines.joined(separator: "\n")
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, status, exitCode, summary, cases, errors }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(1, forKey: .schemaVersion)
        try c.encode(status, forKey: .status)
        try c.encode(exitCode, forKey: .exitCode)
        try c.encode([
            "declaredCases": declaredCases, "executedCases": cases.count,
            "passedCases": cases.filter { $0.status == .passed }.count,
            "failedCases": cases.filter { $0.status == .failed }.count,
            "errorCases": cases.filter { $0.status == .error }.count,
            "suiteErrors": errors.count,
            "assertionsEvaluated": cases.reduce(0) { $0 + $1.assertions.count }
        ], forKey: .summary)
        try c.encode(cases, forKey: .cases)
        try c.encode(errors, forKey: .errors)
    }
}
