import Foundation
import CoreGraphics
import CoreText
import ImageIO
import Testing
import FileMintCore
@testable import FileMintImages

@Suite("Native offline image processing", .serialized)
struct ImageProcessorTests {
    @Test("preview is bounded and reports real oriented source dimensions")
    func boundedPreview() throws {
        try workspace { root in
            let file = root.appendingPathComponent("preview.png")
            try fixture(file, width: 1600, height: 800, orientation: 6)
            let input = try #require(ImageProcessor.capture([file]).first)
            let preview = try ImageProcessor.previewInfo(input)
            #expect(preview.dimensions == ImageDimensions(width: 800, height: 1600))
            let source = try #require(CGImageSourceCreateWithData(preview.data as CFData, nil))
            let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
            #expect(image.width == 256 && image.height == 512)
        }
    }

    private func workspace(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileMintImages-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func fixture(_ url: URL, width: Int = 80, height: Int = 40, color: CGColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1),
                         orientation: Int = 1, text: Bool = false, frames: Int = 1) throws {
        let context = try ImageOutput.context(width: width, height: height, white: text)
        if text {
            let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 60, nil)
            let value = NSAttributedString(string: "FILEMINT 12345", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ])
            context.textPosition = CGPoint(x: 30, y: 90)
            CTLineDraw(CTLineCreateWithAttributedString(value), context)
        } else {
            context.setFillColor(color)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let image = try #require(context.makeImage())
        let type = frames > 1 ? "com.compuserve.gif" : "public.png"
        let output = try #require(CGImageDestinationCreateWithURL(url as CFURL, type as CFString, frames, nil))
        for _ in 0..<frames {
            CGImageDestinationAddImage(output, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        }
        #expect(CGImageDestinationFinalize(output))
    }

    private func decode(_ url: URL) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let context = try ImageOutput.context(width: image.width, height: image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(context.data)
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4))
    }

    @Test("convert/resize/compress create decodable copies without altering the input")
    func conversion() throws {
        try workspace { root in
            let original = root.appendingPathComponent("input.png")
            try fixture(original)
            let bytes = try Data(contentsOf: original)
            let input = try ImageProcessor.capture([original])
            var options = ImageJobOptions()
            for format in ImageOutputFormat.conversions where ImageProcessor.writableFormats.contains(format) {
                options.format = format
                let result = ImageProcessor.run(tool: .convert, inputs: input, options: options, destination: nil)
                #expect(result.failure == nil)
                let output = try #require(result.outputs.first)
                let image = try decode(output)
                #expect(image.width == 80 && image.height == 40)
            }
            options.format = .png
            options.longestEdge = 20
            let resized = ImageProcessor.run(tool: .resize, inputs: input, options: options, destination: nil)
            let image = try decode(#require(resized.outputs.first))
            #expect(image.width == 20 && image.height == 10)
            let compressed = ImageProcessor.run(tool: .compress, inputs: input, options: options, destination: nil)
            #expect(compressed.failure == nil && compressed.outputs.first?.pathExtension == "png")
            #expect(try Data(contentsOf: original) == bytes)
        }
    }

    @Test("transparent PNG survives; JPEG uses white and orientation is applied")
    func alphaAndOrientation() throws {
        try workspace { root in
            let file = root.appendingPathComponent("clear.png")
            try fixture(file, color: CGColor(gray: 0, alpha: 0))
            let inputs = try ImageProcessor.capture([file])
            var options = ImageJobOptions()
            let png = ImageProcessor.run(tool: .convert, inputs: inputs, options: options, destination: nil)
            #expect(try pixels(decode(#require(png.outputs.first)))[3] == 0)
            options.format = .jpeg
            let jpg = ImageProcessor.run(tool: .convert, inputs: inputs, options: options, destination: nil)
            let values = try pixels(decode(#require(jpg.outputs.first)))
            #expect(values[0] > 245 && values[1] > 245 && values[2] > 245)
            let rotated = root.appendingPathComponent("rotated.png")
            try fixture(rotated, orientation: 6)
            options.format = .png
            let rotation = ImageProcessor.run(tool: .convert, inputs: try ImageProcessor.capture([rotated]), options: options, destination: nil)
            let image = try decode(#require(rotation.outputs.first))
            #expect(image.width == 40 && image.height == 80)
        }
    }

    @Test("collisions include dangling links and disabled output leaves no staging")
    func collisions() throws {
        try workspace { root in
            let file = root.appendingPathComponent("a.png")
            try fixture(file)
            let input = try ImageProcessor.capture([file])
            let link = root.appendingPathComponent("a-convert.png")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root.appendingPathComponent("missing"))
            let result = ImageProcessor.run(tool: .convert, inputs: input, options: ImageJobOptions(), destination: nil)
            #expect(result.outputs.first?.lastPathComponent == "a-convert 2.png")
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path).hasSuffix("missing"))
            let denied = ImageProcessor.run(tool: .convert, inputs: input, options: ImageJobOptions(), destination: nil, canContinue: { false })
            #expect(denied.failure == .disabled && denied.outputs.isEmpty)
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).allSatisfy { !$0.hasPrefix(".FileMint-image-") })
        }
    }

    @Test("source identity, non-images, links and animation are rejected")
    func rejectedInputs() throws {
        try workspace { root in
            let file = root.appendingPathComponent("a.png")
            try fixture(file)
            let old = try ImageProcessor.capture([file])
            try Data("replaced".utf8).write(to: file, options: .atomic)
            let result = ImageProcessor.run(tool: .convert, inputs: old, options: ImageJobOptions(), destination: nil)
            #expect(result.failure == .sourceChanged && result.outputs.isEmpty)
            let link = root.appendingPathComponent("link.png")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
            #expect(throws: ResourceError.invalidSelection) { try ImageProcessor.capture([link]) }
            let invalid = ImageProcessor.run(tool: .convert, inputs: try ImageProcessor.capture([file]), options: ImageJobOptions(), destination: nil)
            #expect(invalid.failure == .unsupportedImage)
            let gif = root.appendingPathComponent("animated.gif")
            try fixture(gif, frames: 2)
            let animated = ImageProcessor.run(tool: .convert, inputs: try ImageProcessor.capture([gif]), options: ImageJobOptions(), destination: nil)
            #expect(animated.failure == .multipleFrames && animated.outputs.isEmpty)
        }
    }

    @Test("stitch preserves selected order and validates output canvas")
    func stitch() throws {
        try workspace { root in
            let a = root.appendingPathComponent("a.png"), b = root.appendingPathComponent("b.png")
            try fixture(a, width: 100, height: 100)
            try fixture(b, width: 100, height: 100, color: CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            var options = ImageJobOptions()
            options.stitchEdge = 100
            let inputs = try ImageProcessor.capture([a, b])
            let vertical = ImageProcessor.run(tool: .stitch, inputs: inputs, options: options, destination: nil)
            let image = try decode(#require(vertical.outputs.first))
            #expect(image.width == 100 && image.height == 200)
            let data = try pixels(image)
            // CGBitmapContext memory begins at the top scanline after drawing.
            #expect(data[0] > 240 && data[2] < 10)
            let bottom = (199 * 100) * 4
            #expect(data[bottom] < 10 && data[bottom + 2] > 240)
            options.horizontal = true
            let horizontal = ImageProcessor.run(tool: .stitch, inputs: inputs.reversed(), options: options, destination: nil)
            let row = try decode(#require(horizontal.outputs.first))
            #expect(row.width == 200 && row.height == 100)
            let rowData = try pixels(row)
            #expect(rowData[2] > 240 && rowData[199 * 4] > 240)
            options.stitchEdge = 4000
            let large = ImageProcessor.run(tool: .stitch, inputs: inputs, options: options, destination: nil)
            #expect(large.failure == .dimensionsTooLarge && large.outputs.isEmpty)
        }
    }

    @Test("icon formats contain expected image sizes or a complete PNG size set")
    func icons() throws {
        try workspace { root in
            let file = root.appendingPathComponent("wide.png")
            try fixture(file)
            let inputs = try ImageProcessor.capture([file])
            for format in ImageOutputFormat.icons where ImageProcessor.writableFormats.contains(format) {
                var options = ImageJobOptions()
                options.format = format
                let result = ImageProcessor.run(tool: .icons, inputs: inputs, options: options, destination: nil)
                #expect(result.failure == nil)
                let output = try #require(result.outputs.first)
                if format == .pngSet {
                    for size in format.iconSizes {
                        let image = try decode(output.appendingPathComponent("icon_\(size)x\(size).png"))
                        #expect(image.width == size && image.height == size)
                        #expect(try pixels(image)[3] == 0)
                    }
                } else {
                    let source = try #require(CGImageSourceCreateWithURL(output as CFURL, nil))
                    var sizes = Set<Int>()
                    for index in 0..<CGImageSourceGetCount(source) {
                        let image = try #require(CGImageSourceCreateImageAtIndex(source, index, nil))
                        #expect(image.width == image.height)
                        sizes.insert(image.width)
                    }
                    #expect(sizes == Set(format.iconSizes))
                }
            }
        }
    }

    @Test("OCR recognizes a synthetic image and TXT export does not overwrite")
    func ocr() throws {
        try workspace { root in
            let file = root.appendingPathComponent("text.png")
            try fixture(file, width: 800, height: 220, text: true)
            let result = ImageProcessor.run(tool: .ocr, inputs: try ImageProcessor.capture([file]), options: ImageJobOptions(), destination: nil)
            #expect(result.failure == nil)
            #expect(result.texts.first?.contains("FILEMINT") == true)
            #expect(result.texts.first?.contains("12345") == true)
            #expect(result.outputs.isEmpty)
            let first = try ImageProcessor.saveText("文字\nFILEMINT", in: root)
            let second = try ImageProcessor.saveText("Second", in: root)
            #expect(first != second)
            #expect(try String(contentsOf: first, encoding: .utf8) == "文字\nFILEMINT")
        }
    }

    @Test("cancellation before processing creates no output")
    func cancellation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("image.png")
        try fixture(file)
        let inputs = try ImageProcessor.capture([file])
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return ImageProcessor.run(tool: .convert, inputs: inputs, options: ImageJobOptions(), destination: nil)
        }
        let result = await task.value
        #expect(result.cancelled && result.outputs.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["image.png"])
    }

    @Test("writer failure and permission changes remove only owned staging")
    func stagingCleanup() throws {
        try workspace { root in
            let sentinel = root.appendingPathComponent("keep.png")
            try Data("keep".utf8).write(to: sentinel)
            #expect(throws: ResourceError.encodingFailed) {
                try ImageOutput.publish(in: root, stem: "failed", suffix: "png", inputs: [], canContinue: { true }) {
                    try Data("partial".utf8).write(to: $0)
                    throw ResourceError.encodingFailed
                }
            }
            #expect(throws: ResourceError.disabled) {
                try ImageOutput.publish(in: root, stem: "disabled", suffix: "png", inputs: [], canContinue: { false }) {
                    try Data("complete but unpublished".utf8).write(to: $0)
                }
            }
            #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["keep.png"])
            #expect(try Data(contentsOf: sentinel) == Data("keep".utf8))
        }
    }

    @Test("partial batches report completed outputs; empty OCR is not failure")
    func partialAndEmpty() throws {
        try workspace { root in
            let a = root.appendingPathComponent("a.png"), b = root.appendingPathComponent("b.png")
            try fixture(a, color: CGColor(gray: 1, alpha: 1))
            try Data("not an image".utf8).write(to: b)
            let partial = ImageProcessor.run(tool: .convert, inputs: try ImageProcessor.capture([a, b]), options: ImageJobOptions(), destination: nil)
            #expect(partial.completed == 1 && partial.outputs.count == 1 && partial.failure == .unsupportedImage)
            let empty = ImageProcessor.run(tool: .ocr, inputs: try ImageProcessor.capture([a]), options: ImageJobOptions(), destination: nil)
            #expect(empty.failure == nil && empty.texts == [""] && empty.completed == 1)
        }
    }

    @Test("encoded byte limit rejects a sparse oversized input without reading its contents")
    func sizeLimit() throws {
        try workspace { root in
            let file = root.appendingPathComponent("large.png")
            try Data([0]).write(to: file)
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.truncate(atOffset: UInt64(ResourceToolsPolicy.maximumInputBytes) + 1)
            #expect(throws: ResourceError.inputTooLarge) { try ImageProcessor.capture([file]) }
        }
    }
}
