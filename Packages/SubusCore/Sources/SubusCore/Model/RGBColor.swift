import Foundation

/// An 8-bit sRGB colour, stored in JSON as "#RRGGBB".
public struct RGBColor: Hashable, Codable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Accepts "#RRGGBB" or "RRGGBB" in either case, nothing else.
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else { return nil }
        self.init(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
    }

    public var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let color = RGBColor(hex: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a #RRGGBB colour"))
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(hex)
    }
}

/// How a category's line is coloured: one of the palette presets, or a colour the user picked.
public enum CategoryColor: Hashable, Sendable {
    case preset(Int)
    case custom(RGBColor)
}
