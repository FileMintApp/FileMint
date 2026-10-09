import CoreGraphics
import Foundation
import ImageIO
import FileMintCore
import FileMintCompression

public struct ImageCompressionResult: Sendable {
    public let source: URL
    public let output: URL
    public let originalBytes: Int64
    public let outputBytes: Int64
    /// Positive means larger, negative means smaller. Never controls publication.
    public var changeFraction: Double { Double(outputBytes - originalBytes) / Double(originalBytes) }
}

/// Only the compress action reaches this engine. System decoding enforces the
/// same frame/depth/pixel rules as the other tools before handing over pixels.
enum ImageCompressionEngine {
    static func compress(_ input: ImageInput, quality: Double, in directory: URL,
                         canContinue: @Sendable () -> Bool) throws -> ImageCompressionResult {
        let source = try input.source()
        guard let type = CGImageSourceGetType(source) as String?,
              let format = ImageOutputFormat.conversions.first(where: { $0.identifier == type }) else {
            throw ResourceError.unsupportedOutput
        }
        let image = try ImageInput.decode(source, longestEdge: nil)
        let dimensions = ImageDimensions(width: image.width, height: image.height)
        var outputBytes: Int64 = 0
        let output = try ImageOutput.publish(in: directory,
            stem: input.url.deletingPathExtension().lastPathComponent + "-compress",
            suffix: format.suffix, inputs: [input], canContinue: canContinue) { staged in
                try encode(image, format: format, quality: quality, to: staged)
                try Task.checkCancellation()
                // Check real encoder output, not the requested filename alone.
                guard let encoded = CGImageSourceCreateWithURL(staged as CFURL,
                    [kCGImageSourceShouldCache: false] as CFDictionary),
                      CGImageSourceGetType(encoded) as String? == format.identifier,
                      CGImageSourceGetCount(encoded) == 1,
                      try ImageInput.dimensions(encoded) == dimensions else {
                    throw ResourceError.encodingFailed
                }
                let attributes = try staged.resourceValues(forKeys: [.fileSizeKey])
                guard let size = attributes.fileSize, size > 0 else { throw ResourceError.encodingFailed }
                outputBytes = Int64(size)
            }
        return ImageCompressionResult(source: input.url, output: output,
            originalBytes: input.encodedByteCount, outputBytes: outputBytes)
    }

    static func encode(_ image: CGImage, format: ImageOutputFormat, quality: Double, to url: URL) throws {
        guard quality.isFinite, (0...1).contains(quality) else { throw ResourceError.invalidOptions }
        if format == .heic {
            try ImageOutput.encode(image, format: .heic, quality: quality, to: url)
            return
        }
        let encoder: Int32
        switch format {
        case .jpeg: encoder = Int32(FMCompressionJPEG.rawValue)
        case .png: encoder = Int32(FMCompressionPNG.rawValue)
        case .tiff: encoder = Int32(FMCompressionTIFF.rawValue)
        default: throw ResourceError.unsupportedOutput
        }
        try Task.checkCancellation()
        // Match the native output pipeline, including its sRGB conversion and
        // white JPEG background. The C call borrows this storage synchronously.
        let context = try ImageOutput.context(width: image.width, height: image.height, white: format == .jpeg)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let bytes = context.data else { throw ResourceError.encodingFailed }
        let encodedQuality = Int32(max(1, (quality * 100).rounded()))
        let status = url.withUnsafeFileSystemRepresentation { path in
            fm_compression_encode(bytes.assumingMemoryBound(to: UInt8.self),
                context.bytesPerRow * context.height, Int32(context.width), Int32(context.height),
                encoder, encodedQuality, path)
        }
        guard status == 0 else { throw ResourceError.encodingFailed }
        try Task.checkCancellation()
    }
}
