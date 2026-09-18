import Foundation
import Darwin
import ImageIO
import FileMintCore

/// A regular local file selected and authorized by the user. No image is decoded
/// while constructing Finder menus or capturing this identity.
public struct ImageInput: Sendable {
    public let item: FileMoveItem
    private let length: Int64
    private let modifiedSeconds: Int
    private let modifiedNanos: Int
    public var url: URL { item.source }

    public static func capture(_ url: URL) throws -> Self {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              values.isUbiquitousItem != true || values.ubiquitousItemDownloadingStatus == .current ||
                values.ubiquitousItemDownloadingStatus == .downloaded else { throw ResourceError.invalidSelection }
        let item = try FileMoveItem.capture(url)
        var info = stat()
        guard url.withUnsafeFileSystemRepresentation({ lstat($0!, &info) }) == 0,
              info.st_mode & S_IFMT == S_IFREG, info.st_flags & UInt32(SF_DATALESS) == 0 else {
            throw ResourceError.invalidSelection
        }
        guard info.st_size > 0, info.st_size <= ResourceToolsPolicy.maximumInputBytes else { throw ResourceError.inputTooLarge }
        return Self(item: item, length: info.st_size,
                    modifiedSeconds: info.st_mtimespec.tv_sec, modifiedNanos: info.st_mtimespec.tv_nsec)
    }

    public func validate() throws {
        try item.validateIdentity()
        let fresh = try Self.capture(url)
        guard fresh.length == length, fresh.modifiedSeconds == modifiedSeconds,
              fresh.modifiedNanos == modifiedNanos else { throw ResourceError.sourceChanged }
    }

    func source() throws -> CGImageSource {
        try Task.checkCancellation()
        try validate()
        let descriptor = url.withUnsafeFileSystemRepresentation { open($0!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC) }
        guard descriptor >= 0 else { throw ResourceError.accessDenied }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_flags & UInt32(SF_DATALESS) == 0,
              UInt64(info.st_ino) == item.inode, UInt64(info.st_dev) == item.device,
              info.st_size == length else { throw ResourceError.sourceChanged }
        guard let data = try handle.read(upToCount: ResourceToolsPolicy.maximumInputBytes + 1),
              data.count == length else { throw ResourceError.sourceChanged }
        try validate()
        guard let source = CGImageSourceCreateWithData(data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary) else { throw ResourceError.unsupportedImage }
        let allowed: Set<String> = ["public.jpeg", "public.png", "public.heic", "public.heif", "public.tiff", "com.microsoft.bmp", "com.compuserve.gif"]
        guard let type = CGImageSourceGetType(source) as String?, allowed.contains(type) else {
            throw ResourceError.unsupportedImage
        }
        guard CGImageSourceGetCount(source) == 1 else { throw ResourceError.multipleFrames }
        let properties = try Self.properties(source)
        guard ((properties[kCGImagePropertyDepth] as? NSNumber)?.intValue ?? 8) <= 8,
              (properties[kCGImagePropertyIsFloat] as? Bool) != true else { throw ResourceError.unsupportedImage }
        guard CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeHDRGainMap) == nil else {
            throw ResourceError.unsupportedImage
        }
        if #available(macOS 15, *), CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeISOGainMap) != nil {
            throw ResourceError.unsupportedImage
        }
        try Self.dimensions(source).validate(source: true)
        return source
    }

    static func properties(_ source: CGImageSource) throws -> [CFString: Any] {
        guard let values = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw ResourceError.unsupportedImage
        }
        return values
    }

    static func dimensions(_ source: CGImageSource) throws -> ImageDimensions {
        let values = try properties(source)
        guard let width = values[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = values[kCGImagePropertyPixelHeight] as? NSNumber else { throw ResourceError.unsupportedImage }
        let orientation = (values[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return (5...8).contains(orientation)
            ? ImageDimensions(width: height.intValue, height: width.intValue)
            : ImageDimensions(width: width.intValue, height: height.intValue)
    }

    func decode(longestEdge: Int? = nil) throws -> CGImage {
        let source = try source()
        return try Self.decode(source, longestEdge: longestEdge)
    }

    static func decode(_ source: CGImageSource, longestEdge: Int?) throws -> CGImage {
        let original = try Self.dimensions(source)
        let target = try longestEdge.map { try original.fitting(longestEdge: $0) } ?? original
        try target.validate()
        try Task.checkCancellation()
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(target.width, target.height),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ResourceError.unsupportedImage
        }
        try ImageDimensions(width: image.width, height: image.height).validate()
        try Task.checkCancellation()
        return image
    }
}
