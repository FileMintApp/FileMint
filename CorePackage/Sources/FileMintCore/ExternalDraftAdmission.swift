import CryptoKit
import Foundation

public enum ExternalDraftAdmissionResult: Equatable, Sendable {
    case accepted(UUID)
    case alreadyPresented(UUID)
    case existingDraft, busy, conflictingRequestID, alreadyHandled
}

/// A synchronous value owned by the main actor at the native admission boundary.
/// Finished entries retain only bounded ID/digest/state/monotonic-time metadata.
public struct ExternalDraftAdmission: Sendable {
    private enum State: Sendable { case preparing, presented, handled(TimeInterval) }
    private struct Entry: Sendable {
        var digest: Data
        var session: UUID
        var state: State
        let admittedAt: TimeInterval
    }
    private var entries: [UUID: Entry] = [:]
    private var active: (session: UUID, requestID: UUID?, presented: Bool)?
    public var activeSessionID: UUID? { active?.session }

    public init() {}

    public mutating func admit(_ request: ExternalDraftRequest, now: TimeInterval,
                               hasDraft: Bool, isBusy: Bool) -> ExternalDraftAdmissionResult {
        entries = entries.filter { _, entry in
            if case .handled(let finished) = entry.state { return now - finished < 600 }
            return true
        }
        guard !isBusy, active?.presented != false else { return .busy }
        let digest = fingerprint(request)
        if let id = request.requestID, let entry = entries[id] {
            guard entry.digest == digest else { return .conflictingRequestID }
            switch entry.state {
            case .preparing: return .busy
            case .presented: return .alreadyPresented(entry.session)
            case .handled: return .alreadyHandled
            }
        }
        guard !hasDraft, active == nil else { return .existingDraft }
        let session = UUID()
        active = (session, request.requestID, false)
        if let id = request.requestID {
            if entries.count >= 512, let oldest = entries.min(by: {
                $0.value.admittedAt == $1.value.admittedAt ? $0.key.uuidString < $1.key.uuidString
                    : $0.value.admittedAt < $1.value.admittedAt
            })?.key { entries.removeValue(forKey: oldest) }
            entries[id] = Entry(digest: digest, session: session, state: .preparing, admittedAt: now)
        }
        return .accepted(session)
    }

    public mutating func markPresented(_ session: UUID) {
        guard active?.session == session else { return }
        active?.presented = true
        if let id = active?.requestID { entries[id]?.state = .presented }
    }

    public mutating func finish(_ session: UUID, now: TimeInterval) {
        guard let current = active, current.session == session else { return }
        if let id = current.requestID {
            if current.presented { entries[id]?.state = .handled(now) }
            else { entries.removeValue(forKey: id) }
        }
        active = nil
    }

    private func fingerprint(_ request: ExternalDraftRequest) -> Data {
        var hasher = SHA256()
        func append(_ value: String?) {
            guard let value else { hasher.update(data: Data([0])); return }
            let bytes = Data(value.utf8)
            hasher.update(data: Data([1]))
            hasher.update(data: Data(String(bytes.count).utf8))
            hasher.update(data: Data([0]))
            hasher.update(data: bytes)
        }
        append(request.name)
        append(request.templateID)
        switch request.content {
        case .templateDefault: append(nil)
        case .verbatim(let text): append(text)
        }
        switch request.destination {
        case .defaultLocation: append("default")
        case .ask: append("ask")
        case .directory(let path): append("directory"); append(path)
        case .favorite(let id): append("favorite"); append(id.uuidString)
        }
        return Data(hasher.finalize())
    }
}
