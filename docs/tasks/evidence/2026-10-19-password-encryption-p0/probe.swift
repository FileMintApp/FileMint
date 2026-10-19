import Foundation
import AppleArchive
import System
import Darwin

struct Request: Decodable {
    var action: String
    var input: String?
    var output: String?
    var password: String
    var newPassword: String?
    var fields: String?
    var stopAfterBytes: Int?
}
enum ProbeError: Error { case missingInput, missingOutput, stream(String), injectedStop }
var stage = "request"
var copied = 0
func source(_ path: String?) throws -> ArchiveByteStream {
    guard let path else { throw ProbeError.missingInput }
    guard let s = ArchiveByteStream.fileStream(path: FilePath(path), mode: .readOnly, options: [], permissions: []) else { throw ProbeError.stream("source") }
    return s
}
func destination(_ path: String?) throws -> ArchiveByteStream {
    guard let path else { throw ProbeError.missingOutput }
    let fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
    guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    guard let s = ArchiveByteStream.fileStream(fd: FileDescriptor(rawValue: fd), automaticClose: true) else { close(fd); throw ProbeError.stream("destination") }
    return s
}
func context(_ password: String) throws -> ArchiveEncryptionContext {
    let c = ArchiveEncryptionContext(profile: .hkdf_sha256_aesctr_hmac__scrypt__none, compressionAlgorithm: .lzfse)
    stage = "setPassword"
    try c.setPassword(password)
    return c
}
func decryptor(_ input: ArchiveByteStream, _ password: String) throws -> ArchiveByteStream {
    stage = "readContext"
    guard let c = ArchiveEncryptionContext(from: input) else { throw ProbeError.stream("context") }
    guard c.profile == .hkdf_sha256_aesctr_hmac__scrypt__none else { throw ProbeError.stream("unexpectedProfile") }
    stage = "setDecryptionPassword"; try c.setPassword(password)
    stage = "openDecryptionStream"
    guard let s = ArchiveByteStream.decryptionStream(readingFrom: input, encryptionContext: c, threadCount: 2) else { throw ProbeError.stream("decryption") }
    return s
}
func copy(_ input: ArchiveByteStream, _ output: ArchiveByteStream, stop: Int? = nil) throws {
    var buffer = [UInt8](repeating: 0, count: 1_048_576)
    while true {
        stage = "readBlock"
        let n = try buffer.withUnsafeMutableBytes { try input.read(into: $0) }
        if n == 0 { break }
        stage = "writeBlock"
        try buffer.withUnsafeBytes { bytes in
            var offset = 0
            while offset < n {
                let written = try output.write(from: UnsafeRawBufferPointer(rebasing: bytes[offset..<n]))
                guard written > 0 else { throw ProbeError.stream("shortWrite") }
                offset += written
            }
        }
        copied += n
        if let stop, copied >= stop { throw ProbeError.injectedStop }
    }
}
let start = Date()
do {
    let requestData = FileHandle.standardInput.readDataToEndOfFile()
    let r = try JSONDecoder().decode(Request.self, from: requestData)
    switch r.action {
    case "inspect":
        let input = try source(r.input); defer { try? input.close() }
        guard let c = ArchiveEncryptionContext(from: input) else { throw ProbeError.stream("context") }
        let before = c.containerSize
        try c.setPassword(r.password)
        let valid = c.decryptAttributes()
        let extra: [String: Any] = ["case": "attributes", "authenticated": valid, "containerBefore": before, "containerAfter": c.containerSize, "rawSize": c.rawSize, "paddingSize": c.paddingSize, "profile": c.profile.rawValue]
        print(String(data: try JSONSerialization.data(withJSONObject: extra, options: [.sortedKeys]), encoding: .utf8)!)
    case "validatePassword":
        _ = try context(r.password)
    case "encrypt", "pack":
        let c = try context(r.password)
        stage = "destination"; let out = try destination(r.output); defer { try? out.close() }
        stage = "openEncryptionStream"
        guard let crypt = ArchiveByteStream.encryptionStream(writingTo: out, encryptionContext: c, threadCount: 2) else { throw ProbeError.stream("encryption") }
        defer { try? crypt.close() }
        if r.action == "pack" {
            stage = "encodeStream"
            guard let encoder = ArchiveStream.encodeStream(writingTo: crypt, threadCount: 2), let fields = ArchiveHeader.FieldKeySet(r.fields ?? "TYP,PAT,DAT,MOD,MTM,XAT") else { throw ProbeError.stream("encoder") }
            defer { try? encoder.close() }
            stage = "writeDirectoryContents"
            guard let input = r.input else { throw ProbeError.missingInput }
            try encoder.writeDirectoryContents(archiveFrom: FilePath(input), keySet: fields, threadCount: 2)
            stage = "closeEncoder"; try encoder.close()
        } else {
            let input = try source(r.input); defer { try? input.close() }
            try copy(input, crypt, stop: r.stopAfterBytes)
        }
        stage = "sealEncryption"; try crypt.close()
        stage = "closeDestination"; try out.close()
    case "decrypt", "extract", "rekey":
        let input = try source(r.input); defer { try? input.close() }
        let plain = try decryptor(input, r.password); defer { try? plain.close() }
        if r.action == "extract" {
            guard let path = r.output else { throw ProbeError.missingOutput }
            stage = "createOutputDirectory"
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            guard let decoder = ArchiveStream.decodeStream(readingFrom: plain, threadCount: 2), let extractor = ArchiveStream.extractStream(extractingTo: FilePath(path), threadCount: 2) else { throw ProbeError.stream("extractor") }
            defer { try? decoder.close(); try? extractor.close() }
            stage = "extractProcess"
            copied = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor, threadCount: 2)
            stage = "closeExtractor"; try extractor.close(); try decoder.close()
        } else if r.action == "rekey" {
            guard let next = r.newPassword else { throw ProbeError.stream("missingNewPassword") }
            let c = try context(next)
            let out = try destination(r.output); defer { try? out.close() }
            stage = "openMigrationEncryption"
            guard let crypt = ArchiveByteStream.encryptionStream(writingTo: out, encryptionContext: c, threadCount: 2) else { throw ProbeError.stream("migrationEncryption") }
            defer { try? crypt.close() }
            try copy(plain, crypt, stop: r.stopAfterBytes)
            stage = "closeOldDecryption"; try plain.close()
            stage = "sealMigration"; try crypt.close(); try out.close()
        } else {
            let out = try destination(r.output); defer { try? out.close() }
            try copy(plain, out, stop: r.stopAfterBytes)
            stage = "closePlainOutput"; try out.close()
        }
        stage = "closeDecryption"; try plain.close(); try input.close()
    default: throw ProbeError.stream("unknownAction")
    }
    let result: [String: Any] = ["ok": true, "stage": stage, "unitsProcessed": copied, "elapsedMS": Int(Date().timeIntervalSince(start)*1000)]
    print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
} catch {
    let result: [String: Any] = ["ok": false, "stage": stage, "unitsProcessed": copied, "error": String(describing: error), "elapsedMS": Int(Date().timeIntervalSince(start)*1000)]
    print(String(data: try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
    exit(1)
}
