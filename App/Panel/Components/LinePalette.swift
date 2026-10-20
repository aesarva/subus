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

    /// Rails and stations behind a lifted station recede by thinning, never by fading: the colour stays opaque,
    /// so it keeps its 3:1 against the ground.
    static func recededStroke(_ contrast: ColorSchemeContrast) -> CGFloat { contrast == .increased ? 2 : 1.5 }

    static let accent = Color(nsColor: Brand.accent)
    /// The accent for text, ≥ 4.5:1 in each theme.
    static let accentText = Color(nsColor: Brand.accentText)

    private static func wrap(_ i: Int) -> Int { ((i % count) + count) % count }
}

/// How a station shows: at rest, receded behind a lifted one, or lifted (hovered or selected).
enum StationState {
    case rest, receded, lifted

    init(lifted: Bool, anyLifted: Bool) {
        self = lifted ? .lifted : anyLifted ? .receded : .rest
    }

    var diameter: CGFloat {
        switch self {
        case .rest: 13
        case .receded: 9
        case .lifted: 16
        }
    }

    func stroke(_ contrast: ColorSchemeContrast) -> CGFloat {
        self == .receded ? LinePalette.recededStroke(contrast) : LinePalette.stroke(contrast)
    }
}

extension GraphicsContext {
    /// A hollow station ring in its line colour; it clears what is under it, so the rail stops at its edge.
    /// A lifted station also gets a 1 pt ring in the label colour around it.
    mutating func drawStation(at center: CGPoint, color: Color, _ state: StationState, contrast: ColorSchemeContrast) {
        let stroke = state.stroke(contrast)
        let outer = state.diameter / 2 + (state == .lifted ? 2 : 0)
        func circle(_ r: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        }
        blendMode = .clear
        fill(circle(outer), with: .color(.black))
        blendMode = .normal
        self.stroke(circle(state.diameter / 2 - stroke / 2), with: .color(color), lineWidth: stroke)
        if state == .lifted {
            self.stroke(circle(outer - 0.5), with: .color(Color(nsColor: .labelColor)), lineWidth: 1)
        }
    }
}

extension Color {
    init(hex: Int) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
