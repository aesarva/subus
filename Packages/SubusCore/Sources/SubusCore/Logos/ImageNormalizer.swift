import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageNormalizer {
    public enum Failure: Error, Equatable, Sendable { case undecodable, encodeFailed }

    public static func pngThumbnail(from data: Data, side: Int = 128) throws -> Data {
        guard side > 0, let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Failure.undecodable }
        let frames = (0..<CGImageSourceGetCount(source)).compactMap { CGImageSourceCreateImageAtIndex(source, $0, nil) }
        guard let image = frames.max(by: { $0.width < $1.width }), image.width > 0, image.height > 0 else {
            throw Failure.undecodable
        }
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
