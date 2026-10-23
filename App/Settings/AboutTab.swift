import AppKit
import SwiftUI

struct AboutTab: View {
    private static let repository = URL(string: "https://github.com/aesarva/subus")!

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: AppIconImage.load())
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
            Text(verbatim: "Subus").font(.title2.bold())
            Text("Version \(version)").foregroundStyle(.secondary).monospacedDigit()
            Text("License: GPL-3.0").foregroundStyle(.secondary)
            Link(Self.repository.absoluteString, destination: Self.repository)
            Text("Subus connects only to cbr.ru for exchange rates, to GitHub once a day to check for updates (unless you turn it off in General), and — when you click Fetch icon — to the subscription's website and the HTTPS addresses it points to for its icon.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

/// The app icon from the asset catalog, which works however the binary was launched; `NSApp.applicationIconImage`
/// is only the generic placeholder when it was not started through LaunchServices.
@MainActor
enum AppIconImage {
    static func load() -> NSImage {
        if let icon = NSImage(named: "AppIcon"), icon.size.width > 0, icon.size.height > 0 { return icon }
        let icon = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        if icon.isValid, icon.size.width > 0, icon.size.height > 0 { return icon }
        return NSApp.applicationIconImage
    }
}
