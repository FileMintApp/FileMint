import Darwin
import Foundation
import FileMintCore
import Testing

@Suite("File information and streaming checksums")
struct FileInfoTests {
    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("file-info-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }
    private let abc = [
        "900150983cd24fb0d6963f7d28e17f72",
        "a9993e364706816aba3e25717850c26c9cd0d89d",
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
    ]
    private let empty = [
        "d41d8cd98f00b204e9800998ecf8427e",
        "da39a3ee5e6b4b0d3255bfef95601890afd80709",
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    ]

    @Test("empty and abc known vectors, exact copy format and every algorithm choice")
    func knownVectors() throws {
        try fixture { root in
            let file = root.appendingPathComponent("校验 🪴.txt")
            for (data, expected) in [(Data(), empty), (Data("abc".utf8), abc)] {
                try data.write(to: file)
                let selection = try FileInfoSelection.capture([file])
                let info = try FileDigestService.inspect(selection)
                #expect(info.kind == .file && info.logicalSize == Int64(data.count))
                for choice in FileDigestChoice.allCases {
                    let result = try FileDigestService.calculate(selection, choice: choice)
                    #expect(result.values.map(\.algorithm) == choice.algorithms)
                    #expect(result.bytesRead == Int64(data.count))
                    #expect(result.metadata == info)
                    for value in result.values {
                        let index = try #require(FileDigestAlgorithm.allCases.firstIndex(of: value.algorithm))
                        #expect(value.hexadecimal == expected[index])
                    }
                    if choice == .all {
                        #expect(result.clipboardText == zip(FileDigestAlgorithm.allCases, expected)
                            .map { "\($0.rawValue): \($1)" }.joined(separator: "\n"))
                        #expect(!result.clipboardText.hasSuffix("\n"))
                    }
                }
                #expect(try Data(contentsOf: file) == data)
            }
        }
    }

    @Test("binary block boundaries and sparse logical bytes match independent system tools")
    func independentTools() throws {
        try fixture { root in
            let file = root.appendingPathComponent("binary.dat")
            var generator = SystemRandomNumberGenerator()
            let block = Data((0..<4096).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
            for size in [1, FileDigestService.chunkSize - 1, FileDigestService.chunkSize,
                         FileDigestService.chunkSize + 1, 2 * FileDigestService.chunkSize + 11] {
                var data = Data()
                while data.count < size { data.append(block.prefix(size - data.count)) }
                try data.write(to: file)
                try compareTools(file)
                #expect(try Data(contentsOf: file) == data)
            }
            let handle = try FileHandle(forWritingTo: file)
            try handle.truncate(atOffset: 16 * 1_048_576 + 17)
            try handle.close()
            try compareTools(file)
        }
    }

    private func compareTools(_ file: URL) throws {
        let result = try FileDigestService.calculate(FileInfoSelection.capture([file]), choice: .all)
        for value in result.values {
            let process = Process(), pipe = Pipe()
            process.standardOutput = pipe
            if value.algorithm == .md5 {
                process.executableURL = URL(fileURLWithPath: "/sbin/md5")
                process.arguments = ["-q", file.path]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
                let bits = value.algorithm == .sha1 ? "1" : value.algorithm == .sha256 ? "256" : "512"
                process.arguments = ["-a", bits, file.path]
            }
            try process.run()
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            #expect(process.terminationStatus == 0)
            let independent = String(decoding: output, as: UTF8.self).split(whereSeparator: \.isWhitespace).first
            #expect(independent.map(String.init) == value.hexadecimal)
        }
    }

    @Test("comparison trims only edges and rejects wrong length, non-ASCII and embedded whitespace")
    func comparison() throws {
        try fixture { root in
            let file = root.appendingPathComponent("a")
            try Data("abc".utf8).write(to: file)
            let selection = try FileInfoSelection.capture([file])
            for choice in FileDigestChoice.allCases where choice != .all {
                let result = try FileDigestService.calculate(selection, choice: choice)
                let hex = try #require(result.values.first?.hexadecimal)
                #expect(FileInfoPolicy.compare(" \n\(hex.uppercased())\t", choice: choice, result: result) == .match)
                #expect(FileInfoPolicy.compare(String(repeating: "0", count: hex.count), choice: choice, result: result) == .mismatch)
                for bad in [hex + "0", String(hex.dropLast()), " " + hex + " 0", "z" + hex.dropFirst(), "０" + hex.dropFirst(),
                            String(hex.prefix(8)) + "\n" + hex.dropFirst(8)] {
                    #expect(FileInfoPolicy.compare(bad, choice: choice, result: result) == .invalid)
                }
                #expect(FileInfoPolicy.compare(hex, choice: choice, result: nil) == .unavailable)
                let different: FileDigestChoice = choice == .md5 ? .sha1 : .md5
                #expect(FileInfoPolicy.compare(String(repeating: "a", count: different.algorithms[0].hexadecimalLength),
                    choice: different, result: result) == .unavailable)
            }
            #expect(FileInfoPolicy.compare("\n ", choice: .sha256, result: nil) == .empty)
            #expect(FileInfoPolicy.compare(abc[0], choice: .all, result: nil) == .chooseSingleAlgorithm)
        }
    }

    @Test("directories, packages, aliases, symbolic links and special files never calculate")
    func unsupported() throws {
        try fixture { root in
            let file = root.appendingPathComponent("target")
            try Data("abc".utf8).write(to: file)
            let folder = root.appendingPathComponent("folder", isDirectory: true)
            let package = root.appendingPathComponent("Example.app", isDirectory: true)
            for url in [folder, package] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false) }
            let link = root.appendingPathComponent("link")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
            let alias = root.appendingPathComponent("alias")
            let bookmark = try file.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
            try URL.writeBookmarkData(bookmark, to: alias)
            let fifo = root.appendingPathComponent("fifo")
            #expect(mkfifo(fifo.path, 0o600) == 0)
            let folderInfo = try FileDigestService.inspect(FileInfoSelection.capture([folder]))
            #expect(folderInfo.kind == .directory && folderInfo.logicalSize == nil && !folderInfo.canCalculate)
            for item in [folder, package, link, alias, fifo] {
                let selection = try FileInfoSelection.capture([item])
                let info = try FileDigestService.inspect(selection)
                if item != folder { #expect(info.kind == .unsupported) }
                #expect(throws: FileInfoError.unsupported) { try FileDigestService.calculate(selection, choice: .all) }
            }
            #expect(try Data(contentsOf: file) == Data("abc".utf8))
        }
    }

    @Test("replacement at the same path and replaced parents cannot reuse captured authority")
    func replacement() throws {
        try fixture { root in
            let parent = root.appendingPathComponent("parent", isDirectory: true)
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
            let file = parent.appendingPathComponent("a")
            try Data("abc".utf8).write(to: file)
            let selection = try FileInfoSelection.capture([file])
            try FileManager.default.moveItem(at: file, to: parent.appendingPathComponent("old"))
            try Data("replacement".utf8).write(to: file)
            #expect(throws: FileInfoError.changed) { try FileDigestService.inspect(selection) }
            let fresh = try FileInfoSelection.capture([file])
            try FileManager.default.moveItem(at: parent, to: root.appendingPathComponent("old-parent"))
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
            try Data("different parent".utf8).write(to: file)
            #expect(throws: FileInfoError.changed) { try FileDigestService.calculate(fresh, choice: .all) }
        }
    }

    @Test("cancellation and concurrent truncate/growth/rewrite/replacement discard all digests")
    func cancellationAndChanges() throws {
        try fixture { root in
            for mutation in 0..<5 {
                let file = root.appendingPathComponent("input-\(mutation)")
                let original = Data(repeating: 0x61, count: 3 * FileDigestService.chunkSize)
                try original.write(to: file)
                let selection = try FileInfoSelection.capture([file])
                let token = FileDigestCancellation()
                let expected: FileInfoError = mutation == 0 ? .cancelled : .changed
                #expect(throws: expected) {
                    try FileDigestService.calculate(selection, choice: .all, cancellation: token) { value in
                        guard value.bytesRead == 0 else { return }
                        // The production service has opened and verified its handle.
                        // Mutate from this explicit synchronization point, without sleeps.
                        do {
                            if mutation == 0 { token.cancel() }
                            if mutation == 1 {
                                let handle = try FileHandle(forWritingTo: file)
                                try handle.truncate(atOffset: 1); try handle.close()
                            }
                            if mutation == 2 {
                                let handle = try FileHandle(forWritingTo: file)
                                try handle.seekToEnd(); try handle.write(contentsOf: Data([0])); try handle.close()
                            }
                            if mutation == 3 {
                                let handle = try FileHandle(forWritingTo: file)
                                try handle.write(contentsOf: Data([0x62])); try handle.close()
                            }
                            if mutation == 4 {
                                try FileManager.default.moveItem(at: file, to: root.appendingPathComponent("replaced"))
                                try Data("new object".utf8).write(to: file)
                            }
                        } catch { Issue.record(error) }
                    }
                }
                if mutation == 0 { #expect(try Data(contentsOf: file) == original) }
            }
        }
    }

    @Test("new preferences fail closed independently and menus are single-selection only")
    func menusAndPreferences() throws {
        for json in [#"{}"#, #"{"fileInfo":"invalid","copyNames":false,"move":true}"#] {
            let value = try JSONDecoder().decode(FileToolsPreferences.self, from: Data(json.utf8))
            #expect(!value.fileInfo)
            #expect(value.move)
        }
        var prefs = FileMintPreferences.default
        let root = URL(fileURLWithPath: "/missing/file-info-scope", isDirectory: true)
        prefs.monitoredFolderURLs = [root]
        prefs.fileTools.isEnabled = true; prefs.fileTools.fileInfo = true
        let item = root.appendingPathComponent("item")
        #expect(FileToolsPolicy.availableTools(selection: [item], isItemMenu: true, preferences: prefs).contains(.fileInfo))
        #expect(!FileToolsPolicy.availableTools(selection: [item, item], isItemMenu: true, preferences: prefs).contains(.fileInfo))
        #expect(!FileToolsPolicy.availableTools(selection: [item], isItemMenu: false, preferences: prefs).contains(.fileInfo))
        #expect(!FileToolsPolicy.availableTools(target: .directory(root), preferences: prefs).contains(.fileInfo))
        prefs.fileTools.mainMenuTools = [.fileInfo]
        let layout = FileToolsMenuLayout(tools: [.fileInfo], hasMoveDestination: false, preferences: prefs.fileTools)
        #expect(layout.main == [.fileInfo] && layout.submenu.isEmpty)
        prefs.fileTools.isEnabled = false
        let saved = try JSONDecoder().decode(FileMintPreferences.self, from: JSONEncoder().encode(prefs))
        #expect(saved.fileTools.fileInfo && saved.fileTools.mainMenuTools.contains(.fileInfo))
        #expect(!saved.fileTools.allows(.fileInfo))
        #expect(!FileInfoPolicy.canSelect([URL(string: "file://remote/item")!]))
        #expect(!FileInfoPolicy.canSelect([URL(fileURLWithPath: "/")]))
    }

    @Test("private file-info tickets are single use, expiring and cannot cross routes")
    func tickets() throws {
        try fixture { root in
            let file = root.appendingPathComponent("a")
            try Data("abc".utf8).write(to: file)
            let selected = try FileInfoSelection.capture([file])
            let store = FileOperationTicketStore(directory: root.appendingPathComponent("tickets"))
            let now = Date(timeIntervalSince1970: 1_000)
            let url = try store.enqueue(.fileInfo(selected), now: now)
            #expect(FileOperationTicketStore.isFileInfoURL(url))
            #expect(try store.consume(url, now: now) == .fileInfo(selected))
            #expect(try store.consume(url, now: now) == nil)
            let expired = try store.enqueue(.fileInfo(selected), now: now)
            #expect(try store.consume(expired, now: now.addingTimeInterval(61)) == nil)
            let future = try store.enqueue(.fileInfo(selected), now: now)
            #expect(try store.consume(future, now: now.addingTimeInterval(-1)) == nil)
            let crossed = try store.enqueue(.fileInfo(selected), now: now)
            #expect(try store.consume(URL(string: crossed.absoluteString.replacingOccurrences(of: "file-info", with: "move"))!, now: now) == nil)
            let wrongPayload = try store.enqueue(.airDrop([file]), now: now)
            #expect(try store.consume(URL(string: wrongPayload.absoluteString.replacingOccurrences(of: "move", with: "file-info"))!, now: now) == nil)
        }
    }
}
