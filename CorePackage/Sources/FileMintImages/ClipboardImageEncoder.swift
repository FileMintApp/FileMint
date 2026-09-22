import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ClipboardImage: Sendable {
    public let png: Data
    public let preview: Data
    public let width: Int
    public let height: Int
}

public enum ClipboardImageError: Error {
    case unsupported, tooLarge, encodingFailed
}

public enum ClipboardImageEncoder {
    public static func encode(_ data: Data) throws -> ClipboardImage {
        guard data.count <= 64 * 1024 * 1024 else { throw ClipboardImageError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?,
              [UTType.png.identifier, UTType.tiff.identifier].contains(type),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { throw ClipboardImageError.unsupported }
        guard width <= 16_384, height <= 16_384, width * height <= 16_000_000 else {
            throw ClipboardImageError.tooLarge
        }
        // Image I/O applies EXIF orientation; max-size equals the source's longest
        // edge so no image pixels are lost to preview downsampling.
        func image(maximum: Int) -> CGImage? {
            CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximum,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary)
        }
        func png(_ image: CGImage) throws -> Data {
            let output = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
                throw ClipboardImageError.encodingFailed
            }
            CGImageDestinationAddImage(destination, image, nil)
            guard CGImageDestinationFinalize(destination) else { throw ClipboardImageError.encodingFailed }
            return output as Data
        }
        guard let full = image(maximum: max(width, height)), let preview = image(maximum: 512) else {
            throw ClipboardImageError.unsupported
        }
        return try ClipboardImage(png: png(full), preview: png(preview), width: full.width, height: full.height)
    }
}
