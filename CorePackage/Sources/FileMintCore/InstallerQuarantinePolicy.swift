import Foundation

/// This is a download preflight, not an assertion of Apple signing or trust.
/// The sandbox no-user-consent bit blocks execution before normal Gatekeeper
/// approval. Keep internet quarantine present and never rewrite these flags.
public enum InstallerQuarantinePolicy {
    public static func allowsGatekeeperAssessment(_ attribute: String?) -> Bool {
        guard let attribute,
              let prefix = attribute.split(separator: ";", omittingEmptySubsequences: false).first,
              let flags = UInt32(prefix, radix: 16) else { return false }
        return flags & 0x01 != 0 && flags & 0x04 == 0
    }
}
