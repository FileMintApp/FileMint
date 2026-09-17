import Foundation

public enum AutomaticUpdatePolicy {
    public static let interval: TimeInterval = 7 * 24 * 60 * 60
    public static let startupDelay: TimeInterval = 60

    /// A future attempt is treated as a clock rollback. The caller persists the
    /// corrected attempt time so subsequent launches don't keep moving it out.
    public static func normalizedAttempt(_ attempt: Date?, now: Date) -> Date? {
        attempt.map { min($0, now) }
    }

    public static func nextCheckDate(enabled: Bool, lastAttempt: Date?, now: Date) -> Date? {
        guard enabled else { return nil }
        guard let lastAttempt = normalizedAttempt(lastAttempt, now: now) else { return now }
        return max(now, lastAttempt.addingTimeInterval(interval))
    }
}
