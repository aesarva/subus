import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SubusCore

private func samplePNG(width: Int, height: Int) throws -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    ctx.setFillColor(CGColor(red: 0.9, green: 0.1, blue: 0.2, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try #require(ctx.makeImage())
    let out = NSMutableData()
    let dest = try #require(CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(dest, image, nil)
    #expect(CGImageDestinationFinalize(dest))
    return out as Data
}

private func pixelSize(_ data: Data) throws -> (Int, Int) {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return (image.width, image.height)
}

private func rgba(_ png: Data, x: Int, y: Int) throws -> [UInt8] {
    let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = try #require(CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                     space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    ctx.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
    return px
}

private func encode(_ images: [CGImage], type: UTType) throws -> Data {
    let out = NSMutableData()
    let dest = try #require(CGImageDestinationCreateWithData(out, type.identifier as CFString, images.count, nil))
    for image in images { CGImageDestinationAddImage(dest, image, nil) }
    #expect(CGImageDestinationFinalize(dest))
    return out as Data
}

private func image(width: Int, height: Int, draw: (CGContext) -> Void) throws -> CGImage {
    let ctx = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    draw(ctx)
    return try #require(ctx.makeImage())
}

private func fill(_ ctx: CGContext, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ rect: CGRect) {
    ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
    ctx.fill(rect)
}

@Suite struct LogoTests {
    @Test func parserIsLinearOnHostileInput() {
        let html = String(repeating: "<link rel=icon ", count: 100_000)
        let start = ContinuousClock.now
        let urls = IconHTMLParser.candidates(html: html, baseURL: URL(string: "https://ex.com/")!)
        #expect(ContinuousClock.now - start < .seconds(1))
        #expect(urls.map(\.absoluteString) == ["https://ex.com/favicon.ico"])
    }

    @Test func parserSkipsCommentsAndSelfClose() {
        let html = #"<!-- <link rel="icon" href="/no.png"> --><link rel=icon href=/yes.png/>"#
        let urls = IconHTMLParser.candidates(html: html, baseURL: URL(string: "https://ex.com/")!)
        #expect(urls.map(\.absoluteString) == ["https://ex.com/yes.png", "https://ex.com/favicon.ico"])
    }

    @Test func cyrillicColorPinned() {
        #expect(Monogram.colorIndex(for: "Яндекс Плюс", paletteCount: 8) == 2)
        #expect(Monogram.colorIndex(for: "x", paletteCount: 0) == 0)
    }

    @Test func rejectsOversizedDimensions() throws {
        let wide = try image(width: 9000, height: 10) { fill($0, 1, 0, 0, CGRect(x: 0, y: 0, width: 9000, height: 10)) }
        let data = try encode([wide], type: .png)
        #expect(throws: (any Error).self) { try ImageNormalizer.pngThumbnail(from: data) }
    }

    @Test func thumbnailCropsCentre() throws {
        let src = try image(width: 300, height: 100) {
            fill($0, 1, 0, 0, CGRect(x: 0, y: 0, width: 100, height: 100))
            fill($0, 0, 1, 0, CGRect(x: 100, y: 0, width: 100, height: 100))
            fill($0, 0, 0, 1, CGRect(x: 200, y: 0, width: 100, height: 100))
        }
        let out = try ImageNormalizer.pngThumbnail(from: encode([src], type: .png))
        for (x, y) in [(64, 64), (2, 64), (125, 64)] {
            let p = try rgba(out, x: x, y: y)
            #expect(p[1] > 200 && p[0] < 40 && p[2] < 40)
        }
    }

    @Test func thumbnailKeepsAlpha() throws {
        let src = try image(width: 64, height: 64) { fill($0, 0, 0, 1, CGRect(x: 16, y: 16, width: 32, height: 32)) }
        let out = try ImageNormalizer.pngThumbnail(from: encode([src], type: .png))
        #expect(try rgba(out, x: 0, y: 0)[3] == 0)
        #expect(try rgba(out, x: 127, y: 127)[3] == 0)
        #expect(try rgba(out, x: 64, y: 64)[3] == 255)
    }

    @Test func icoPicksLargestFrame() throws {
        let small = try image(width: 16, height: 16) { fill($0, 1, 0, 0, CGRect(x: 0, y: 0, width: 16, height: 16)) }
        let large = try image(width: 64, height: 64) { fill($0, 0, 1, 0, CGRect(x: 0, y: 0, width: 64, height: 64)) }
        let data = try encode([small, large], type: .ico)
        let p = try rgba(ImageNormalizer.pngThumbnail(from: data), x: 64, y: 64)
        #expect(p[1] > 200 && p[0] < 40)
    }

    @Test func letters() {
        #expect(Monogram.letter(for: "netflix") == "N")
        #expect(Monogram.letter(for: "  spotify") == "S")
        #expect(Monogram.letter(for: "яндекс плюс") == "Я")
        #expect(Monogram.letter(for: "🎵 Music") == "🎵")
        #expect(Monogram.letter(for: "") == "?")
    }

    @Test func stableColor() {
        #expect(Monogram.colorIndex(for: "Netflix", paletteCount: 8) == Monogram.colorIndex(for: " netflix ", paletteCount: 8))
        #expect((0..<8).contains(Monogram.colorIndex(for: "Spotify", paletteCount: 8)))
        #expect(Monogram.colorIndex(for: "Netflix", paletteCount: 8) == 3)
    }

    @Test func parserPrefersLargestTouchIcon() {
        let html = """
        <html><head>
        <link rel="icon" sizes="32x32" href="/i32.png">
        <LINK REL='apple-touch-icon' SIZES='180x180' HREF='/touch.png'>
        <link rel="icon" type="image/svg+xml" href="/i.svg">
        </head></html>
        """
        let urls = IconHTMLParser.candidates(html: html, baseURL: URL(string: "https://ex.com/app/")!)
        #expect(urls.map(\.absoluteString) == ["https://ex.com/touch.png", "https://ex.com/i32.png", "https://ex.com/favicon.ico"])
    }

    @Test func parserRelativeAndShortcut() {
        let html = #"<link rel="shortcut icon" href=img/f.png>"#
        let urls = IconHTMLParser.candidates(html: html, baseURL: URL(string: "https://ex.com/app/")!)
        #expect(urls.first?.absoluteString == "https://ex.com/app/img/f.png")
    }

    @Test func parserFallback() {
        let urls = IconHTMLParser.candidates(html: "<html></html>", baseURL: URL(string: "https://ex.com/app/")!)
        #expect(urls.map(\.absoluteString) == ["https://ex.com/favicon.ico"])
    }

    @Test func parserSizesListAndDedupe() {
        let html = """
        <link rel="icon" sizes="16x16 48x48" href="/a.png">
        <link rel="icon" sizes="any" href="/b.png">
        <link rel="icon" href="/b.png">
        <link rel="icon" href="/favicon.ico">
        """
        let urls = IconHTMLParser.candidates(html: html, baseURL: URL(string: "https://ex.com:8443/")!)
        #expect(urls.map(\.absoluteString) == ["https://ex.com:8443/a.png", "https://ex.com:8443/b.png", "https://ex.com:8443/favicon.ico"])
    }

    @Test func thumbnailIs128() throws {
        let out = try ImageNormalizer.pngThumbnail(from: samplePNG(width: 300, height: 200))
        let (w, h) = try pixelSize(out)
        #expect(w == 128 && h == 128)
    }

    @Test func thumbnailRejectsGarbage() {
        #expect(throws: (any Error).self) { try ImageNormalizer.pngThumbnail(from: Data([1, 2, 3])) }
    }

    @Test func fetcherFallsBack() async throws {
        let site = URL(string: "https://ex.com/")!
        let html = #"<link rel="apple-touch-icon" href="/touch.png">"#
        let http = FakeHTTP(responses: [
            site: Data(html.utf8),
            URL(string: "https://ex.com/touch.png")!: Data([0, 1, 2, 3]),
            URL(string: "https://ex.com/favicon.ico")!: try samplePNG(width: 64, height: 64),
        ])
        let out = try await SiteIconFetcher(http: http).fetch(site: site)
        let (w, h) = try pixelSize(out)
        #expect(w == 128 && h == 128)
    }

    @Test func fetcherRejectsHTTP() async {
        let fetcher = SiteIconFetcher(http: FakeHTTP(responses: [:]))
        await #expect(throws: HTTPError.insecureRedirect) { try await fetcher.fetch(site: URL(string: "http://ex.com/")!) }
    }
}
