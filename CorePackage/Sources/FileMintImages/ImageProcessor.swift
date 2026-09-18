import Foundation
import CoreGraphics
import ImageIO
import Vision
import FileMintCore

public struct ImageJobResult: Sendable {
    public var outputs: [URL] = []
    public var texts: [String] = []
    public var completed = 0
    public var failure: ResourceError?
    public var cancelled = false
    public init() {}
}

public struct ImagePreview: Sendable {
    public let data: Data
    public let dimensions: ImageDimensions
}

public enum ImageProcessor {
    public static var writableFormats: [ImageOutputFormat] {
        let identifiers = Set(CGImageDestinationCopyTypeIdentifiers() as! [String])
        return ImageOutputFormat.allCases.filter { identifiers.contains($0.identifier) }
    }

    public static func capture(_ urls: [URL]) throws -> [ImageInput] {
        guard (1...ResourceToolsPolicy.maximumItems).contains(urls.count),
              Set(urls.map(\.standardizedFileURL)).count == urls.count else { throw ResourceError.invalidSelection }
        return try urls.map(ImageInput.capture)
    }

    public static func preview(_ input: ImageInput) throws -> Data {
        try previewInfo(input).data
    }

    public static func previewInfo(_ input: ImageInput) throws -> ImagePreview {
        try autoreleasepool {
            let source = try input.source()
            let dimensions = try ImageInput.dimensions(source)
            let image = try ImageInput.decode(source, longestEdge: 512)
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
                throw ResourceError.encodingFailed
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw ResourceError.encodingFailed }
            return ImagePreview(data: data as Data, dimensions: dimensions)
        }
    }

    public static func run(tool: ResourceTool, inputs: [ImageInput], options: ImageJobOptions,
                           destination: URL?, canContinue: @Sendable () -> Bool = { true },
                           progress: @Sendable (Int) -> Void = { _ in }) -> ImageJobResult {
        var result = ImageJobResult()
        do {
            try options.validate(for: tool)
            guard (1...ResourceToolsPolicy.maximumItems).contains(inputs.count) else { throw ResourceError.invalidSelection }
            try Task.checkCancellation()
            guard canContinue() else { throw ResourceError.disabled }
            if tool == .stitch {
                let output = try autoreleasepool {
                    try stitch(inputs, options: options, destination: destination ?? inputs[0].url.deletingLastPathComponent(),
                               canContinue: canContinue)
                }
                result.outputs = [output]
                result.completed = inputs.count
                progress(result.completed)
                return result
            }
            var totalTextBytes = 0
            for input in inputs {
                try Task.checkCancellation()
                guard canContinue() else { throw ResourceError.disabled }
                try autoreleasepool {
                    if tool == .ocr {
                        let text = try recognize(input)
                        guard text.utf8.count <= 1_048_576, totalTextBytes + text.utf8.count <= 4_194_304 else {
                            throw ResourceError.textTooLarge
                        }
                        try Task.checkCancellation()
                        guard canContinue() else { throw ResourceError.disabled }
                        try input.validate()
                        totalTextBytes += text.utf8.count
                        result.texts.append(text)
                    } else {
                        let directory = destination ?? input.url.deletingLastPathComponent()
                        let output = try process(input, tool: tool, options: options, directory: directory, canContinue: canContinue)
                        result.outputs.append(output)
                    }
                }
                result.completed += 1
                progress(result.completed)
            }
        } catch is CancellationError {
            result.cancelled = true
        } catch {
            result.failure = (error as? ResourceError) ?? (error is FileMoveError ? .sourceChanged : .failed)
        }
        return result
    }

    public static func saveText(_ text: String, in directory: URL, stem: String = "Recognized Text") throws -> URL {
        guard text.utf8.count <= 4_194_304 else { throw ResourceError.textTooLarge }
        return try ImageOutput.publish(in: directory, stem: stem, suffix: "txt", inputs: [], canContinue: { true }) {
            try Data(text.utf8).write(to: $0, options: .withoutOverwriting)
        }
    }

    private static func process(_ input: ImageInput, tool: ResourceTool, options: ImageJobOptions,
                                directory: URL, canContinue: @Sendable () -> Bool) throws -> URL {
        var format = options.format
        if tool == .compress {
            format = try autoreleasepool {
                let source = try input.source()
                guard let format = ImageOutputFormat.conversions.first(where: { $0.identifier == CGImageSourceGetType(source) as String? }) else {
                    throw ResourceError.unsupportedOutput
                }
                return format
            }
        }
        guard writableFormats.contains(format) else { throw ResourceError.unsupportedOutput }
        let edge: Int? = tool == .resize ? options.longestEdge : tool == .icons ? 1024 : nil
        let image = try input.decode(longestEdge: edge)
        let stem = input.url.deletingPathExtension().lastPathComponent + "-" + tool.rawValue
        return try ImageOutput.publish(in: directory, stem: stem,
            suffix: format == .pngSet ? "icons" : format.suffix, inputs: [input], canContinue: canContinue) { url in
                if tool == .icons { try icons(image, format: format, to: url) }
                else { try ImageOutput.encode(image, format: format, quality: options.quality, to: url) }
            }
    }

    private static func icons(_ image: CGImage, format: ImageOutputFormat, to url: URL) throws {
        let sizes = format.iconSizes
        var destination: CGImageDestination?
        if format == .pngSet {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        } else {
            destination = CGImageDestinationCreateWithURL(url as CFURL, format.identifier as CFString, sizes.count, nil)
            guard destination != nil else { throw ResourceError.unsupportedOutput }
        }
        for size in sizes {
            try Task.checkCancellation()
            try autoreleasepool {
                let context = try ImageOutput.context(width: size, height: size)
                let scale = Double(size) / Double(max(image.width, image.height))
                let w = Double(image.width) * scale, h = Double(image.height) * scale
                context.draw(image, in: CGRect(x: (Double(size) - w) / 2, y: (Double(size) - h) / 2, width: w, height: h))
                guard let icon = context.makeImage() else { throw ResourceError.encodingFailed }
                if let destination {
                    // ICNS represents 64/1024 px as 32/512 point Retina images.
                    let dpi = format == .icns && (size == 64 || size == 1024) ? 144 : 72
                    CGImageDestinationAddImage(destination, icon,
                        [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary)
                }
                else { try ImageOutput.encode(icon, format: .png, quality: 1, to: url.appendingPathComponent("icon_\(size)x\(size).png")) }
            }
        }
        if let destination, !CGImageDestinationFinalize(destination) { throw ResourceError.encodingFailed }
    }

    private static func stitch(_ inputs: [ImageInput], options: ImageJobOptions, destination: URL,
                               canContinue: @Sendable () -> Bool) throws -> URL {
        let dimensions = try inputs.map { input in
            try Task.checkCancellation()
            return try autoreleasepool { try ImageInput.dimensions(input.source()) }
        }
        let layout = try ImageStitchLayout(inputs: dimensions, edge: options.stitchEdge, horizontal: options.horizontal)
        let context = try ImageOutput.context(width: layout.canvas.width, height: layout.canvas.height)
        var offset = 0
        for (index, input) in inputs.enumerated() {
            try Task.checkCancellation()
            guard canContinue() else { throw ResourceError.disabled }
            try autoreleasepool {
                let size = layout.sizes[index]
                let image = try input.decode(longestEdge: max(size.width, size.height))
                let x = options.horizontal ? offset : 0
                let y = options.horizontal ? 0 : layout.canvas.height - offset - size.height
                context.draw(image, in: CGRect(x: x, y: y, width: size.width, height: size.height))
                offset += options.horizontal ? size.width : size.height
            }
        }
        guard let image = context.makeImage() else { throw ResourceError.encodingFailed }
        return try ImageOutput.publish(in: destination, stem: "Stitched", suffix: "png", inputs: inputs, canContinue: canContinue) {
            try ImageOutput.encode(image, format: .png, quality: 1, to: $0)
        }
    }

    private static func recognize(_ input: ImageInput) throws -> String {
        let image = try input.decode(longestEdge: 4096)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.preferBackgroundProcessing = true
        request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        let languages = ["zh-Hans", "en-US"].filter { supported.contains($0) }
        if !languages.isEmpty { request.recognitionLanguages = languages }
        try VNImageRequestHandler(cgImage: image).perform([request])
        try Task.checkCancellation()
        // Stable top-to-bottom ordering; left-to-right for approximately aligned lines.
        let rows = (request.results ?? []).sorted {
            let leftRow = Int(($0.boundingBox.midY * 100).rounded())
            let rightRow = Int(($1.boundingBox.midY * 100).rounded())
            if leftRow != rightRow { return leftRow > rightRow }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        return rows.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
