import Foundation

/// Fits a user-picked line colour to a minimum WCAG contrast against a ground, moving only its OKLCH lightness.
public enum LineContrast {
    /// The reference grounds every line ratio is measured against (DESIGN.md).
    public static let lightGround = SRGBColor(red: 0xF6, green: 0xF6, blue: 0xF3)
    public static let darkGround = SRGBColor(red: 0x1C, green: 0x1C, blue: 0x1E)

    /// WCAG 2.x contrast ratio, 1…21.
    public static func ratio(_ a: SRGBColor, _ b: SRGBColor) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// The colour moved in OKLCH lightness only, the hue kept, until it reaches `minimum` against `ground`.
    /// Chroma drops only where the colour would leave sRGB. When even the extreme misses, black or white.
    public static func adjusted(_ color: SRGBColor, against ground: SRGBColor, minimum: Double = 3.0) -> SRGBColor {
        if ratio(color, ground) >= minimum { return color }
        let darker = luminance(ground) > 0.18
        let extreme = darker ? SRGBColor(red: 0, green: 0, blue: 0) : SRGBColor(red: 255, green: 255, blue: 255)
        guard ratio(extreme, ground) >= minimum else { return extreme }

        let start = OKLCH.from(color)
        func candidate(_ l: Double) -> SRGBColor { OKLCH.fitted(l: l, c: start.c, h: start.h) }
        // `lo` misses the minimum, `hi` reaches it; the search closes in on the smallest move.
        var lo = start.l, hi = darker ? 0.0 : 1.0
        var best = extreme
        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            let rgb = candidate(mid)
            if ratio(rgb, ground) >= minimum {
                hi = mid
                best = rgb
            } else {
                lo = mid
            }
        }
        return best
    }

    private static func luminance(_ c: SRGBColor) -> Double {
        let (r, g, b) = OKLCH.linear(c)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

/// sRGB ⇄ OKLCH (Björn Ottosson's OKLab in polar form); hue in degrees.
enum OKLCH {
    static func from(_ c: SRGBColor) -> (l: Double, c: Double, h: Double) {
        let (r, g, b) = linear(c)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        var h = atan2(B, A) * 180 / .pi
        if h < 0 { h += 360 }
        return (L, (A * A + B * B).squareRoot(), h)
    }

    /// nil when the colour lies outside sRGB.
    static func rgb(l: Double, c: Double, h: Double) -> SRGBColor? {
        let (r, g, b) = linearRGB(l: l, c: c, h: h)
        let tolerance = 1e-4
        guard [r, g, b].allSatisfy({ $0 >= -tolerance && $0 <= 1 + tolerance }) else { return nil }
        return SRGBColor(red: byte(r), green: byte(g), blue: byte(b))
    }

    /// The colour at this lightness and hue, its chroma cut by 5 % steps until it fits sRGB.
    static func fitted(l: Double, c: Double, h: Double) -> SRGBColor {
        var chroma = c
        while chroma > 1e-4 {
            if let rgb = rgb(l: l, c: chroma, h: h) { return rgb }
            chroma *= 0.95
        }
        return rgb(l: l, c: 0, h: h) ?? SRGBColor(red: byte(l), green: byte(l), blue: byte(l))
    }

    static func linear(_ c: SRGBColor) -> (Double, Double, Double) {
        func f(_ v: UInt8) -> Double {
            let x = Double(v) / 255
            return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return (f(c.red), f(c.green), f(c.blue))
    }

    private static func linearRGB(l: Double, c: Double, h: Double) -> (Double, Double, Double) {
        let a = c * cos(h * .pi / 180), b = c * sin(h * .pi / 180)
        let l3 = pow(l + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m3 = pow(l - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s3 = pow(l - 0.0894841775 * a - 1.2914855480 * b, 3)
        return (4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
                -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
                -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
    }

    private static func byte(_ linear: Double) -> UInt8 {
        let x = min(max(linear, 0), 1)
        let encoded = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        return UInt8((min(max(encoded, 0), 1) * 255).rounded())
    }
}
