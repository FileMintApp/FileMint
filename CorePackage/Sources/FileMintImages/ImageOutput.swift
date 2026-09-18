import Foundation
import Darwin
import ImageIO
import CoreGraphics
import FileMintCore

enum ImageOutput {
    static func context(width: Int, height: Int, white: Bool = false) throws -> CGContext {
        try ImageDimensions(width: width, height: height).validate()
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ResourceError.encodingFailed }
        context.interpolationQuality = .high
        if white {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return context
    }

    static func encode(_ image: CGImage, format: ImageOutputFormat, quality: Double, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.identifier as CFString, 1, nil) else {
            throw ResourceError.unsupportedOutput
        }
        let context = try context(width: image.width, height: image.height, white: format == .jpeg)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let normalized = context.makeImage() else { throw ResourceError.encodingFailed }
        var properties: [CFString: Any] = [kCGImagePropertyOrientation: 1]
        if format.isLossy { properties[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(destination, normalized, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ResourceError.encodingFailed }
    }

    /// Encoders only see a private staging path. Publish atomically with exclusive
    /// rename, including folder-of-PNG exports and dangling-link collisions.
    static func publish(in directory: URL, stem: String, suffix: String, inputs: [ImageInput],
                        canContinue: @Sendable () -> Bool, writer: (URL) throws -> Void) throws -> URL {
        let parent = try FileMoveItem.capture(directory)
        guard parent.isDirectory,
              (try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isPackageKey])).isSymbolicLink != true,
              (try directory.resourceValues(forKeys: [.isPackageKey])).isPackage != true else { throw ResourceError.accessDenied }
        var pattern = Array(directory.appendingPathComponent(".FileMint-image-XXXXXX").path.utf8CString)
        guard mkdtemp(&pattern) != nil else { throw ResourceError.accessDenied }
        let staging = URL(fileURLWithPath: String(decoding: pattern.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self), isDirectory: true)
        let identity = try FileMoveItem.capture(staging)
        defer {
            if (try? identity.validateIdentity()) != nil { try? FileManager.default.removeItem(at: staging) }
        }
        let temporary = staging.appendingPathComponent("output")
        try writer(temporary)
        try Task.checkCancellation()
        for input in inputs { try input.validate() }
        for number in 1...10_000 {
            try parent.validateIdentity()
            try Task.checkCancellation()
            guard canContinue() else { throw ResourceError.disabled }
            let name = ResourceToolsPolicy.outputName(stem: stem, suffix: suffix, number: number)
            let output = directory.appendingPathComponent(name)
            let result = temporary.withUnsafeFileSystemRepresentation { sourcePath in
                output.withUnsafeFileSystemRepresentation { targetPath in renamex_np(sourcePath!, targetPath!, UInt32(RENAME_EXCL)) }
            }
            if result == 0 { return output }
            guard errno == EEXIST else { throw ResourceError.accessDenied }
        }
        throw ResourceError.encodingFailed
    }
}
