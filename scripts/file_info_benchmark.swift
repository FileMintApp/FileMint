// Compile with the FileMintCore library. Each invocation owns and removes one
// sparse local fixture; throughput here is logical-byte hashing, not SSD speed.
import Darwin
import FileMintCore
import Foundation

private final class CancellationClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time: Double?
    func set() { lock.lock(); if time == nil { time = ProcessInfo.processInfo.systemUptime }; lock.unlock() }
    var value: Double? { lock.lock(); defer { lock.unlock() }; return time }
}

@main struct FileInfoBenchmark {
    static func main() async throws {
        guard CommandLine.arguments.count == 4, let bytes = Int64(CommandLine.arguments[1]), bytes > 0,
              let choice = FileDigestChoice(rawValue: CommandLine.arguments[2]) else {
            fatalError("Usage: benchmark BYTES sha256|sha512|sha1|md5|all full|cancel")
        }
        let cancelling = CommandLine.arguments[3] == "cancel"
        try await Task.detached(priority: .userInitiated) {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("file-info-bench-\(UUID())", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: root) }
            let file = root.appendingPathComponent("sparse.bin")
            guard FileManager.default.createFile(atPath: file.path, contents: nil) else { throw FileInfoError.unavailable }
            let handle = try FileHandle(forWritingTo: file)
            try handle.truncate(atOffset: UInt64(bytes)); try handle.close()
            let selected = try FileInfoSelection.capture([file])
            _ = try FileDigestService.inspect(selected)
            var before = rusage(); getrusage(RUSAGE_SELF, &before)
            let started = ProcessInfo.processInfo.systemUptime
            let token = FileDigestCancellation(), clock = CancellationClock()
            var status = "completed"
            var digests: [String: String] = [:]
            do {
                let result = try FileDigestService.calculate(selected, choice: choice, cancellation: token) { progress in
                    if cancelling && progress.bytesRead > 0 { clock.set(); token.cancel() }
                }
                guard result.bytesRead == bytes else { throw FileInfoError.unavailable }
                digests = Dictionary(uniqueKeysWithValues: result.values.map { ($0.algorithm.rawValue, $0.hexadecimal) })
            } catch FileInfoError.cancelled {
                guard cancelling else { throw FileInfoError.cancelled }
                status = "cancelled"
            }
            let ended = ProcessInfo.processInfo.systemUptime
            var after = rusage(); getrusage(RUSAGE_SELF, &after)
            let record: [String: Any] = ["fixture": "local sparse logical bytes", "bytes": bytes,
                "choice": choice.rawValue, "status": status, "seconds": ended - started,
                "MiBPerSecond": cancelling ? NSNull() : Double(bytes) / 1_048_576 / (ended - started) as Any,
                "baselinePeakRSSBytes": before.ru_maxrss, "peakRSSBytes": after.ru_maxrss,
                "extraPeakRSSBytes": max(0, after.ru_maxrss - before.ru_maxrss),
                "cancellationMilliseconds": clock.value.map { (ended - $0) * 1000 } ?? NSNull(), "digests": digests]
            print(String(decoding: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), as: UTF8.self))
        }.value
    }
}
