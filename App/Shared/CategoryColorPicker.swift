import AppKit
import SubusCore
import SwiftUI

/// The eight presets and the system colour panel. A custom pick is kept as 8-bit sRGB, so what the
/// preview shows is exactly what is saved.
struct CategoryColorPicker: View {
    @Binding var color: CategoryColor
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<Category.paletteCount, id: \.self) { i in
                Button { color = .preset(i) } label: {
                    Circle().fill(LinePalette.line(.preset(i), scheme)).frame(width: 20, height: 20)
                        .overlay {
                            if color == .preset(i) { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
                        }
                }
                .buttonStyle(.plain)
                .help(CategoryColor.preset(i).displayName)
                .accessibilityLabel(Text(CategoryColor.preset(i).displayName))
            }
            ColorPicker(selection: custom, supportsOpacity: false) { Text("Other color…") }
                .help(String(localized: "Other color…"))
        }
    }

    private var custom: Binding<Color> {
        Binding {
            if case .custom(let rgb) = color { Color(rgb) } else { LinePalette.line(color, scheme) }
        } set: { picked in
            if let rgb = SRGBColor(picked) { color = .custom(rgb) }
        }
    }
}

extension CategoryColor {
    var displayName: String {
        switch self {
        case .custom: String(localized: "Custom color")
        case .preset(let i):
            [String(localized: "Magenta"), String(localized: "Green"), String(localized: "Blue"), String(localized: "Red"),
             String(localized: "Violet"), String(localized: "Cyan"), String(localized: "Brown"),
             String(localized: "Yellow")][((i % Category.paletteCount) + Category.paletteCount) % Category.paletteCount]
        }
    }
}

extension SRGBColor {
    /// The picked colour in sRGB, clamped and rounded to 8 bits; nil when it has no sRGB form.
    init?(_ color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        func byte(_ v: CGFloat) -> UInt8 { UInt8((min(max(v, 0), 1) * 255).rounded()) }
        self.init(red: byte(srgb.redComponent), green: byte(srgb.greenComponent), blue: byte(srgb.blueComponent))
    }
}

extension Color {
    init(_ rgb: SRGBColor) {
        self.init(.sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255)
    }
}
