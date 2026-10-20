import AppKit
import SubusCore
import SwiftUI

/// The subscription's own image or site icon when its file exists, otherwise a monogram tile.
struct LogoView: View {
    let subscription: Subscription
    let size: CGFloat
    let logosDirectory: URL

    init(subscription: Subscription, size: CGFloat, logosDirectory: URL) {
        self.subscription = subscription
        self.size = size
        self.logosDirectory = logosDirectory
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
        Group {
            if let image = Self.image(for: subscription.logo, in: logosDirectory) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinePalette.tile(monogramIndex)
                    Text(verbatim: Monogram.letter(for: subscription.name))
                        .font(.system(size: size * 0.52, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityHidden(true)
    }

    private var monogramIndex: Int {
        if case .monogram(let index?) = subscription.logo { return index }
        return Monogram.colorIndex(for: subscription.name, paletteCount: LinePalette.count)
    }

    /// Keyed by path and modification date, so a replaced file is read again.
    @MainActor private static let cache = NSCache<NSString, NSImage>()

    @MainActor private static func image(for logo: Logo, in directory: URL) -> NSImage? {
        let name: String
        switch logo {
        case .image(let fileName), .siteIcon(let fileName): name = fileName
        case .monogram: return nil
        }
        guard Logo.isSafeFileName(name) else { return nil }
        let url = directory.appendingPathComponent(name)
        guard let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return nil }
        let key = "\(url.path)|\(modified.timeIntervalSinceReferenceDate)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
