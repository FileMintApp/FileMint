import Foundation
import ImageIO
import FileMintCore

/// Rebuilds an image from decoded pixels. Source metadata and ancillary payloads
/// are never passed to the encoder; only a normalized orientation is written.
enum ImageMetadataCleaner {
    static func clean(_ input: ImageInput, in directory: URL,
                      canContinue: @Sendable () -> Bool) throws -> URL {
        let source = try input.source()
        guard let sourceType = CGImageSourceGetType(source) as String?,
              let format = ImageOutputFormat.conversions.first(where: { $0.identifier == sourceType }),
              ResourceToolsPolicy.metadataExtensions.contains(input.url.pathExtension.lowercased()) else {
            throw ResourceError.metadataFormatUnavailable
        }
        guard ImageProcessor.writableFormats.contains(format) else { throw ResourceError.metadataFormatUnavailable }
        let sourceDimensions = try ImageInput.dimensions(source)
        let image: CGImage
        do { image = try ImageInput.decode(source, longestEdge: nil) }
        catch ResourceError.dimensionsTooLarge { throw ResourceError.metadataTooLarge }
        let stem = input.url.deletingPathExtension().lastPathComponent + "-clean"
        return try ImageOutput.publish(in: directory, stem: stem,
            suffix: input.url.pathExtension.lowercased(), inputs: [input], canContinue: canContinue) { staged in
            do { try ImageOutput.encode(image, format: format, quality: 1, to: staged) }
            catch ResourceError.unsupportedOutput { throw ResourceError.metadataFormatUnavailable }
            try validate(staged, type: sourceType, expected: sourceDimensions)
        }
    }

    static func validate(_ url: URL, type: String, expected: ImageDimensions) throws {
        guard let output = CGImageSourceCreateWithURL(url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(output) == 1,
              (CGImageSourceGetType(output) as String?) == type,
              try ImageInput.dimensions(output) == expected,
              let properties = CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [String: Any] else {
            throw ResourceError.privateMetadataRemains
        }
        var allowedTop: Set<String> = ["ColorModel", "Depth", "Orientation", "PixelHeight", "PixelWidth",
            "ProfileName", "HasAlpha", "DPIWidth", "DPIHeight", "{JFIF}", "{Exif}", "{TIFF}", "{PNG}"]
        if type == "public.heic" {
            allowedTop.formUnion(["ContentLightLevelInfo", "Headroom", "PrimaryImage"])
        }
        guard Set(properties.keys).isSubset(of: allowedTop) else { throw ResourceError.privateMetadataRemains }
        let allowedNested: [String: Set<String>] = [
            "{JFIF}": ["DensityUnit", "JFIFVersion", "XDensity", "YDensity"],
            "{Exif}": ["ColorSpace", "PixelXDimension", "PixelYDimension"],
            "{TIFF}": ["Orientation", "Compression", "PhotometricInterpretation", "ResolutionUnit",
                "XResolution", "YResolution", "SamplesPerPixel", "BitsPerSample", "PlanarConfiguration",
                "TileLength", "TileWidth"],
            "{PNG}": ["Chromaticities", "Gamma", "InterlaceType", "sRGBIntent", "XPixelsPerMeter", "YPixelsPerMeter"]
        ]
        if let lighting = properties["ContentLightLevelInfo"] {
            guard let values = lighting as? [String: Any],
                  Set(values.keys).isSubset(of: ["MaxContentLightLevel", "MaxPicAverageLightLevel"]) else {
                throw ResourceError.privateMetadataRemains
            }
        }
        for (key, allowed) in allowedNested {
            guard let value = properties[key] else { continue }
            guard let dictionary = value as? [String: Any],
                  Set(dictionary.keys).isSubset(of: allowed) else {
                throw ResourceError.privateMetadataRemains
            }
        }
    }
}
