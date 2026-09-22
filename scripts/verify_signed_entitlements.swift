import Foundation
import Security

// Security reads the actual embedded DER/XML entitlements. Do not parse the
// human-readable output of codesign; newer macOS releases use DER-only blobs.
func signedEntitlements(_ bundle: URL) throws -> [String: Any] {
    var code: SecStaticCode?
    let creation = SecStaticCodeCreateWithPath(bundle as CFURL, [], &code)
    guard creation == errSecSuccess, let code else { throw CheckError.failed("Cannot read signed bundle: \(creation)") }
    var signingInfo: CFDictionary?
    let status = SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo)
    guard status == errSecSuccess, let info = signingInfo as? [String: Any],
          let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] else {
        throw CheckError.failed("Missing embedded sandbox entitlements: \(status)")
    }
    return entitlements
}

enum CheckError: Error { case failed(String) }

func hasBuildVariable(_ value: Any) -> Bool {
    if let string = value as? String { return string.contains("$(") || string.contains("${") }
    if let array = value as? [Any] { return array.contains(where: hasBuildVariable) }
    if let dictionary = value as? [String: Any] {
        return dictionary.contains { hasBuildVariable($0.key) || hasBuildVariable($0.value) }
    }
    return false
}

func verify(_ app: URL) throws {
    let extensionURL = app.appendingPathComponent("Contents/PlugIns/FileMintFinderSync.appex")
    let appEntitlements = try signedEntitlements(app)
    let extensionEntitlements = try signedEntitlements(extensionURL)
    for entitlements in [appEntitlements, extensionEntitlements] {
        guard entitlements["com.apple.security.app-sandbox"] as? Bool == true else {
            throw CheckError.failed("App and Finder extension must remain sandboxed")
        }
        guard !hasBuildVariable(entitlements) else {
            throw CheckError.failed("Unresolved build variable in signed entitlements")
        }
    }
    guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
          let identifier = info["CFBundleIdentifier"] as? String, !identifier.isEmpty else {
        throw CheckError.failed("Missing app bundle identifier")
    }
    guard info["SUEnableInstallerLauncherService"] as? Bool == true else {
        throw CheckError.failed("Sandboxed app must enable Sparkle's installer launcher service")
    }
    let key = "com.apple.security.temporary-exception.mach-lookup.global-name"
    guard let services = appEntitlements[key] as? [String], services.count == 2,
          Set(services) == Set([identifier + "-spks", identifier + "-spki"]) else {
        throw CheckError.failed("Missing or incorrect Sparkle installer Mach service entitlements")
    }
    guard appEntitlements["com.apple.security.network.client"] as? Bool == true else {
        throw CheckError.failed("Main app update networking entitlement is missing")
    }
    guard extensionEntitlements[key] == nil,
          extensionEntitlements["com.apple.security.network.client"] as? Bool != true else {
        throw CheckError.failed("Finder extension must not gain installer or networking privileges")
    }
}

do {
    guard CommandLine.arguments.count == 2 else { throw CheckError.failed("Usage: verify_signed_entitlements.swift APP") }
    try verify(URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))
    print("PASS embedded app/Finder sandbox entitlements and resolved Sparkle service names")
} catch {
    fputs("FAIL signed entitlements: \(error)\n", stderr)
    exit(1)
}
