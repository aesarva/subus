import SwiftUI

/// Metro line colours (8 indices), monogram tiles and the resting rail.
/// Light uses the tile set for lines; dark uses the bright set. Each line stroke reaches ≥ 3:1 on its ground.
enum LinePalette {
    static let count = 8

    /// Monogram tiles: a white letter on each reaches ≥ 4.5:1.
    static let tiles: [Color] = [0xB3261E, 0x2E7D32, 0x005A94, 0xA85600, 0x7B3A96, 0x0A6F99, 0x7A4E26, 0x7D6300].map(Color.init(hex:))
    static let bright: [Color] = [0xFF6B5E, 0x3FA34D, 0x3D9BE9, 0xED9121, 0xB57BD6, 0x1EBCEF, 0xC08A55, 0xF2C200].map(Color.init(hex:))

    static let violet = 4

    static func tile(_ index: Int) -> Color { tiles[wrap(index)] }

    /// The line colour of a category index; no category rides the rail colour.
    static func line(_ index: Int?, _ scheme: ColorScheme) -> Color {
        guard let index else { return rail(scheme) }
        return scheme == .dark ? bright[wrap(index)] : tiles[wrap(index)]
    }

    static func rail(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x75757A) : Color(hex: 0x8A8A83)
    }

    /// Rails and strokes thicken from 3 to 4 pt under Increase Contrast.
    static func stroke(_ contrast: ColorSchemeContrast) -> CGFloat { contrast == .increased ? 4 : 3 }

    static let accent = Color(nsColor: Brand.accent)

    /// The one opacity for rails and stations that recede behind a lifted station. Never applied to text.
    static let recede = 0.45

    private static func wrap(_ i: Int) -> Int { ((i % count) + count) % count }
}

extension Color {
    init(hex: Int) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
