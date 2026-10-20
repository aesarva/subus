import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageNormalizer {
    public enum Failure: Error, Equatable, Sendable { case undecodable, encodeFailed, tooLarge }
    private static let maxSide = 8192
    private static let maxPixels = 40_000_000

    public static func pngThumbnail(from data: Data, side: Int = 128) throws -> Data {
        guard side > 0, let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Failure.undecodable }
        var best: (index: Int, width: Int, height: Int)?
        for index in 0..<CGImageSourceGetCount(source) {
            guard let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
                  let w = props[kCGImagePropertyPixelWidth] as? Int,
                  let h = props[kCGImagePropertyPixelHeight] as? Int, w > 0, h > 0 else { continue }
            if best == nil || w * h > best!.width * best!.height { best = (index, w, h) }
        }
        guard let best else { throw Failure.undecodable }
        guard best.width <= maxSide, best.height <= maxSide, best.width * best.height <= maxPixels else {
            throw Failure.tooLarge
        }
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(side * 2, 256),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, best.index, options as CFDictionary),
              image.width > 0, image.height > 0 else { throw Failure.undecodable }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw Failure.encodeFailed }
        ctx.interpolationQuality = .high
        let scale = max(CGFloat(side) / CGFloat(image.width), CGFloat(side) / CGFloat(image.height))
        let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
        ctx.draw(image, in: CGRect(x: (CGFloat(side) - w) / 2, y: (CGFloat(side) - h) / 2, width: w, height: h))
        guard let result = ctx.makeImage() else { throw Failure.encodeFailed }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.encodeFailed
        }
        CGImageDestinationAddImage(dest, result, nil)
        guard CGImageDestinationFinalize(dest) else { throw Failure.encodeFailed }
        return out as Data
    }
}
