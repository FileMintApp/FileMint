import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Narrow internal seams let tests inject real failures without process-wide hooks.
struct HarnessOperations {
    var writeFixture: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .withoutOverwriting) }
    var createFile: (FileCreationRequest, Date) throws -> FileCreationResult = { try FileCreationService().createFile($0, now: $1) }
    var cleanup: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
}

public enum HarnessRunner {
    public static func run(_ suite: HarnessSuite, temporaryDirectory: URL = FileManager.default.temporaryDirectory) -> HarnessReport {
        run(suite, temporaryDirectory: temporaryDirectory, operations: HarnessOperations())
    }

    static func run(_ suite: HarnessSuite, temporaryDirectory: URL, operations: HarnessOperations) -> HarnessReport {
        let workspace: URL
        do {
            workspace = try makeWorkspace(in: temporaryDirectory)
        } catch {
            return HarnessReport(declaredCases: suite.caseCount, cases: [], errors: [
                HarnessDiagnostic(code: "workspace", path: "$", message: "Cannot create a private temporary workspace: \(HarnessDiagnostic.operationError(error))")
            ])
        }
        let results = suite.cases.enumerated().map { index, testCase in
            execute(testCase, root: workspace.appendingPathComponent("case-\(index)", isDirectory: true), operations: operations)
        }
        var errors: [HarnessDiagnostic] = []
        do { try operations.cleanup(workspace) }
        catch { errors.append(HarnessDiagnostic(code: "cleanup", path: "$", message: "Failed to remove this run's temporary workspace: \(HarnessDiagnostic.operationError(error))")) }
        return HarnessReport(declaredCases: suite.caseCount, cases: results, errors: errors)
    }

    private static func makeWorkspace(in parent: URL) throws -> URL {
        guard parent.isFileURL else { throw CocoaError(.fileWriteInvalidFileName) }
        var path = Array(parent.resolvingSymlinksInPath().appendingPathComponent("FileMintHarness-XXXXXX").path.utf8CString)
        let success = path.withUnsafeMutableBufferPointer { mkdtemp($0.baseAddress!) != nil }
        guard success else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        let name = String(decoding: path.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return URL(fileURLWithPath: name, isDirectory: true)
    }

    private static func execute(_ item: HarnessCase, root: URL, operations: HarnessOperations) -> HarnessCaseReport {
        var setupPath = "workspace"
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            for (index, file) in item.existingFiles.enumerated() {
                setupPath = "existingFiles[\(index)]"
                let url = root.appendingPathComponent(file.name)
                let expected = Data(file.content.utf8)
                try operations.writeFixture(expected, url)
                guard try readRegularFile(url) == expected else { throw CocoaError(.fileWriteUnknown) }
            }
        } catch {
            return HarnessCaseReport(id: item.id, name: item.name, assertions: [], errors: [
                HarnessDiagnostic(code: "setup", path: setupPath, message: "Fixture preparation failed (\(HarnessDiagnostic.operationError(error))); product creation was not called")
            ])
        }
        // The immutable suite has already checked catalog membership before any I/O.
        guard let template = TemplateCatalog.template(withID: item.templateID) else {
            return HarnessCaseReport(id: item.id, name: item.name, assertions: [], errors: [
                HarnessDiagnostic(code: "template", path: "templateID", message: "Validated template is no longer available")
            ])
        }
        let result: FileCreationResult
        do {
            result = try operations.createFile(FileCreationRequest(
                destinationDirectory: root, template: template, requestedFileName: item.requestedFileName,
                collisionStrategy: .increment
            ), Date(timeIntervalSince1970: 1_704_067_200))
        } catch {
            return HarnessCaseReport(id: item.id, name: item.name, assertions: [
                HarnessAssertion(path: "creation", passed: false, expected: "successful file creation", actual: "product call failed: \(HarnessDiagnostic.operationError(error))")
            ])
        }
        let url = result.createdURL
        guard url.isFileURL,
              url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath() == root.standardizedFileURL else {
            return HarnessCaseReport(id: item.id, name: item.name, assertions: [
                HarnessAssertion(path: "output.location", passed: false, expected: "file directly inside the case workspace", actual: "outside workspace; not read")
            ])
        }
        var assertions = [HarnessAssertion(path: "expect.fileName", passed: url.lastPathComponent == item.expect.fileName,
                                           expected: HarnessAssertion.text(item.expect.fileName), actual: HarnessAssertion.text(url.lastPathComponent))]
        do {
            let content = try readRegularFile(url)
            switch item.expect.content {
            case .exact(let value):
                assertions.append(.bytes(path: "expect.content.exact", expected: Data(value.utf8), actual: content))
            case .contains(let values):
                for (index, fragment) in values.enumerated() {
                    let bytes = Data(fragment.utf8)
                    assertions.append(HarnessAssertion(path: "expect.content.contains[\(index)]", passed: content.range(of: bytes) != nil,
                                                       expected: HarnessAssertion.byteSummary(bytes), actual: HarnessAssertion.byteSummary(content)))
                }
            }
        } catch {
            assertions.append(HarnessAssertion(path: "expect.content", passed: false, expected: "readable regular output file", actual: "missing, unreadable or non-regular file; no symlink followed (\(HarnessDiagnostic.operationError(error)))"))
        }
        for (index, file) in item.existingFiles.enumerated() {
            do {
                let content = try readRegularFile(root.appendingPathComponent(file.name))
                assertions.append(.bytes(path: "existingFiles[\(index)].unchanged", expected: Data(file.content.utf8), actual: content))
            } catch {
                assertions.append(HarnessAssertion(path: "existingFiles[\(index)].unchanged", passed: false,
                                                   expected: "unchanged regular fixture", actual: "missing, unreadable or non-regular file"))
            }
        }
        let expectedNames = Set(item.existingFiles.map(\.name) + [url.lastPathComponent])
        do {
            let names = Set(try FileManager.default.contentsOfDirectory(atPath: root.path))
            assertions.append(HarnessAssertion(path: "directory.entries", passed: names == expectedNames,
                                               expected: HarnessAssertion.text(expectedNames.sorted().joined(separator: ", ")),
                                               actual: HarnessAssertion.text(names.sorted().joined(separator: ", "))))
        } catch {
            assertions.append(HarnessAssertion(path: "directory.entries", passed: false, expected: "fixtures plus the created file", actual: "cannot inspect case directory"))
        }
        return HarnessCaseReport(id: item.id, name: item.name, assertions: assertions)
    }

    private static func readRegularFile(_ url: URL) throws -> Data {
        // Check the opened descriptor, not a path that could change between stat
        // and read. O_NONBLOCK also keeps a non-regular fixture from hanging.
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            path.map { open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK) } ?? -1
        }
        guard descriptor >= 0 else { throw CocoaError(.fileReadUnknown) }
        defer { close(descriptor) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        return try FileHandle(fileDescriptor: descriptor, closeOnDealloc: false).readToEnd() ?? Data()
    }
}
