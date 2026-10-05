import Foundation
import Security

/// A bundle's declared identifier alone cannot establish an editing profile.
/// Validate the chosen publisher's signed code on the worker before dispatch.
enum CreationEditorIdentity {
    static func validate(identifier: String, at url: URL) throws {
        let rule: String
        switch identifier {
        case "com.apple.TextEdit":
            rule = "identifier \"com.apple.TextEdit\" and anchor apple"
        case "com.microsoft.VSCode":
            rule = "identifier \"com.microsoft.VSCode\" and anchor apple generic and certificate leaf[subject.OU] = \"UBF8T346G9\""
        default: throw PostCreationActionExecutor.Failure.editorRequired
        }
        var code: SecStaticCode?, requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &code) == errSecSuccess,
              SecRequirementCreateWithString(rule as CFString, SecCSFlags(), &requirement) == errSecSuccess,
              let code, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
            throw PostCreationActionExecutor.Failure.editorRequired
        }
    }
}
