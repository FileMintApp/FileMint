import CoreGraphics
import Foundation
import ImageIO
import Testing
import zlib
import FileMintCore
@testable import FileMintImages

@Suite("Dedicated image compression", .serialized)
struct ImageCompressionTests {
    private func workspace(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMintCompression-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func image(width: Int = 160, height: Int = 80, alpha: Bool = false) throws -> CGImage {
        let context = try ImageOutput.context(width: width, height: height)
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let opacity = alpha ? ((x % 3) * 127) : 255
                pixels[offset] = UInt8(((x * 11 + y * 3) % 256) * opacity / 255)
                pixels[offset + 1] = UInt8(((x * 2 + y * 13) % 256) * opacity / 255)
                pixels[offset + 2] = UInt8(((x * 7 + y * 5) % 256) * opacity / 255)
                pixels[offset + 3] = UInt8(opacity)
            }
        }
        return try #require(context.makeImage())
    }

    private func write(_ image: CGImage, to url: URL, type: String, orientation: Int = 1) throws {
        let writer = try #require(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, 1, nil))
        CGImageDestinationAddImage(writer, image, [kCGImagePropertyOrientation: orientation,
            kCGImageDestinationLossyCompressionQuality: 1] as CFDictionary)
        #expect(CGImageDestinationFinalize(writer))
    }

    private func read(_ url: URL) throws -> (CGImage, [CFString: Any]) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return (try #require(CGImageSourceCreateImageAtIndex(source, 0, nil)),
                try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]))
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let context = try ImageOutput.context(width: image.width, height: image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: data, count: image.width * image.height * 4))
    }

    private func run(_ files: [URL], quality: Double = 0.8,
                     canContinue: @Sendable () -> Bool = { true }) throws -> ImageJobResult {
        var options = ImageJobOptions()
        options.quality = quality
        options.format = .png // Compression must use actual source encoding.
        options.longestEdge = 1 // Compression must not inherit a resize parameter.
        return ImageProcessor.run(tool: .compress, inputs: try ImageProcessor.capture(files),
            options: options, destination: nil, canContinue: canContinue)
    }

    @Test("JPEG uses the progressive encoder, selected quality and original dimensions")
    func jpeg() throws {
        try workspace { root in
            let source = root.appendingPathComponent("source.jpg")
            try write(image(), to: source, type: "public.jpeg", orientation: 6)
            let original = try Data(contentsOf: source)
            let high = try run([source], quality: 0.95)
            let low = try run([source], quality: 0.1)
            #expect(high.failure == nil && low.failure == nil)
            let highURL = try #require(high.outputs.first), lowURL = try #require(low.outputs.first)
            #expect(highURL.pathExtension == "jpg" && highURL != lowURL)
            let (decoded, metadata) = try read(highURL)
            #expect(decoded.width == 80 && decoded.height == 160)
            let jfif = try #require(metadata[kCGImagePropertyJFIFDictionary] as? [CFString: Any])
            #expect(jfif[kCGImagePropertyJFIFIsProgressive] as? Bool == true)
            #expect(try Data(contentsOf: lowURL).count < Data(contentsOf: highURL).count)
            #expect(try Data(contentsOf: source) == original)
            #expect(high.compressions.first?.originalBytes == Int64(original.count))
            #expect(high.compressions.first?.outputBytes == Int64(try Data(contentsOf: highURL).count))
        }
    }

    @Test("PNG and TIFF compression preserve normalized pixels and alpha without resizing")
    func lossless() throws {
        try workspace { root in
            for (suffix, type) in [("png", "public.png"), ("tiff", "public.tiff")] {
                let source = root.appendingPathComponent("alpha.\(suffix)")
                try write(image(alpha: true), to: source, type: type, orientation: 8)
                let input = try #require(ImageProcessor.capture([source]).first)
                let expected = try pixels(input.decode())
                let result = try run([source])
                #expect(result.failure == nil && result.completed == 1)
                let (output, properties) = try read(#require(result.outputs.first))
                #expect(output.width == 80 && output.height == 160)
                let actual = try pixels(output)
                #expect(actual.count == expected.count)
                #expect(zip(actual, expected).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
                #expect(stride(from: 3, to: actual.count, by: 4).allSatisfy { actual[$0] == expected[$0] })
                if suffix == "tiff" {
                    let tiff = try #require(properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any])
                    #expect((tiff[kCGImagePropertyTIFFCompression] as? NSNumber)?.intValue == 8)
                }
            }
        }
    }

    // Alter only optional PNG metadata to obtain equal, smaller and larger
    // candidates from the real encoder, without mocking a byte-size decision.
    private func withoutICC(_ png: Data) throws -> Data {
        var result = png.prefix(8), offset = 8
        while offset + 12 <= png.count {
            let count = png[offset..<offset + 4].reduce(0) { ($0 << 8) | Int($1) }
            let end = offset + 12 + count
            guard end <= png.count else { throw ResourceError.encodingFailed }
            if png[offset + 4..<offset + 8] != Data("iCCP".utf8) { result.append(png[offset..<end]) }
            offset = end
        }
        return Data(result)
    }

    private func withComment(_ png: Data) -> Data {
        let payload = Data("Comment\0".utf8) + Data(repeating: 65, count: 8192)
        let body = Data("tEXt".utf8) + payload
        let checksum = body.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(body.count)) }
        func bigEndian(_ number: UInt32) -> Data {
            Data([UInt8(truncatingIfNeeded: number >> 24), UInt8(truncatingIfNeeded: number >> 16),
                  UInt8(truncatingIfNeeded: number >> 8), UInt8(truncatingIfNeeded: number)])
        }
        return png.dropLast(12) + bigEndian(UInt32(payload.count)) + body + bigEndian(UInt32(checksum)) + png.suffix(12)
    }

    @Test("successful smaller, equal and larger compression results are all published")
    func allSizesPublish() throws {
        try workspace { root in
            let seed = root.appendingPathComponent("seed.png")
            let context = try ImageOutput.context(width: 32, height: 16)
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 16))
            try ImageCompressionEngine.encode(#require(context.makeImage()), format: .png, quality: 1, to: seed)
            let canonical = try Data(contentsOf: seed)
            let cases = [("equal", canonical, 0), ("larger", try withoutICC(canonical), 1),
                         ("smaller", withComment(canonical), -1)]
            var files: [URL] = []
            for (name, data, _) in cases {
                let file = root.appendingPathComponent(name + ".png")
                try data.write(to: file)
                files.append(file)
            }
            let result = try run(files)
            #expect(result.failure == nil && result.completed == 3 && result.outputs.count == 3)
            #expect(result.compressions.count == 3)
            for (index, compression) in result.compressions.enumerated() {
                let difference = compression.outputBytes - compression.originalBytes
                #expect(difference.signum() == Int64(cases[index].2))
                #expect(compression.outputBytes == Int64(try Data(contentsOf: compression.output).count))
                #expect(try Data(contentsOf: files[index]) == cases[index].1)
                #expect(try read(compression.output).0.width == 32)
            }
        }
    }

    @Test("HEIC retains the system adapter and reports the actual encoded size")
    func heic() throws {
        guard ImageProcessor.writableFormats.contains(.heic) else { return }
        try workspace { root in
            let source = root.appendingPathComponent("source.heic")
            try write(image(), to: source, type: "public.heic")
            let result = try run([source])
            #expect(result.failure == nil && result.completed == 1)
            let compression = try #require(result.compressions.first)
            #expect(compression.output.pathExtension == "heic")
            #expect(compression.outputBytes == Int64(try Data(contentsOf: compression.output).count))
            #expect(try read(compression.output).0.width == 160)
        }
    }

    @Test("Display P3 input is converted through the same native sRGB color path")
    func colorProfile() throws {
        try workspace { root in
            let space = try #require(CGColorSpace(name: CGColorSpace.displayP3))
            let context = try #require(CGContext(data: nil, width: 40, height: 20, bitsPerComponent: 8,
                bytesPerRow: 160, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(try #require(CGColor(colorSpace: space, components: [0.3, 0.6, 0.8, 1])))
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
            let source = root.appendingPathComponent("p3.png")
            try write(#require(context.makeImage()), to: source, type: "public.png")
            let expected = try pixels(read(source).0)
            let result = try run([source])
            #expect(result.failure == nil)
            let (decoded, properties) = try read(#require(result.outputs.first))
            #expect(properties[kCGImagePropertyProfileName] as? String == "sRGB")
            #expect(zip(try pixels(decoded), expected).allSatisfy { abs(Int($0) - Int($1)) <= 1 })
        }
    }

    @Test("partial compression retains results and collisions do not overwrite links")
    func partialBatch() throws {
        try workspace { root in
            let good = root.appendingPathComponent("good.png"), bad = root.appendingPathComponent("bad.png")
            try write(image(), to: good, type: "public.png")
            try Data("invalid".utf8).write(to: bad)
            let link = root.appendingPathComponent("good-compress.png")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("missing"))
            let result = try run([good, bad])
            #expect(result.completed == 1 && result.outputs.count == 1 && result.compressions.count == 1)
            #expect(result.failure == .unsupportedImage)
            #expect(result.outputs.first?.lastPathComponent == "good-compress 2.png")
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path).hasSuffix("missing"))
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".FileMint-image-") })
        }
    }

    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0
        func allows() -> Bool {
            lock.lock(); defer { lock.unlock() }
            calls += 1
            return calls <= 2 // Run and item checks succeed; publication is revoked.
        }
    }

    @Test("revocation after encoding and replaced sources publish no output")
    func revokedAndReplaced() throws {
        try workspace { root in
            let file = root.appendingPathComponent("input.png")
            try write(image(), to: file, type: "public.png")
            let gate = Gate()
            let denied = try run([file], canContinue: gate.allows)
            #expect(denied.failure == .disabled && denied.outputs.isEmpty && denied.compressions.isEmpty)
            let inputs = try ImageProcessor.capture([file])
            try Data("replaced".utf8).write(to: file, options: .atomic)
            let changed = ImageProcessor.run(tool: .compress, inputs: inputs, options: ImageJobOptions(), destination: nil)
            #expect(changed.failure == .sourceChanged && changed.outputs.isEmpty)
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["input.png"])
        }
    }

    @Test("cancelled compression never publishes a file")
    func cancellation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("input.png")
        try write(image(), to: file, type: "public.png")
        let inputs = try ImageProcessor.capture([file])
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return ImageProcessor.run(tool: .compress, inputs: inputs, options: ImageJobOptions(), destination: nil)
        }
        let result = await task.value
        #expect(result.cancelled && result.outputs.isEmpty && result.compressions.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["input.png"])
    }
}
