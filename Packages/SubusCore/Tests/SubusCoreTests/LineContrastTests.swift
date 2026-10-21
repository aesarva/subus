import Foundation
import Testing
@testable import SubusCore

private func c(_ hex: String) -> RGBColor { RGBColor(hex: hex)! }

private func hueDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(d, 360 - d)
}

@Suite struct LineContrastTests {
    @Test func ratioMatchesWCAG() {
        #expect(abs(LineContrast.ratio(c("#FFFFFF"), c("#000000")) - 21) < 0.01)
        #expect(abs(LineContrast.ratio(c("#E8590C"), c("#F6F6F3")) - 3.31) < 0.01)
    }

    @Test func enoughContrastUnchanged() {
        #expect(LineContrast.adjusted(c("#005A94"), against: LineContrast.lightGround) == c("#005A94"))
    }

    @Test func yellowDarkensOnLightGround() {
        let input = c("#F2C200")
        let out = LineContrast.adjusted(input, against: LineContrast.lightGround)
        #expect(LineContrast.ratio(out, LineContrast.lightGround) >= 3.0)
        #expect(OKLCH.from(out).l < OKLCH.from(input).l)
        #expect(hueDistance(OKLCH.from(out).h, OKLCH.from(input).h) <= 2)
    }

    @Test func navyLightensOnDarkGround() {
        let input = c("#1A237E")
        let out = LineContrast.adjusted(input, against: LineContrast.darkGround)
        #expect(LineContrast.ratio(out, LineContrast.darkGround) >= 3.0)
        #expect(OKLCH.from(out).l > OKLCH.from(input).l)
        #expect(hueDistance(OKLCH.from(out).h, OKLCH.from(input).h) <= 2)
    }

    @Test func whiteDarkensOnLightGround() {
        let out = LineContrast.adjusted(c("#FFFFFF"), against: LineContrast.lightGround)
        #expect(LineContrast.ratio(out, LineContrast.lightGround) >= 3.0)
    }

    @Test func blackLightensOnDarkGround() {
        let out = LineContrast.adjusted(c("#000000"), against: LineContrast.darkGround)
        #expect(LineContrast.ratio(out, LineContrast.darkGround) >= 3.0)
    }

    @Test func unreachableMinimumGivesExtreme() {
        #expect(LineContrast.adjusted(c("#2A9D8F"), against: LineContrast.lightGround, minimum: 25) == c("#000000"))
        #expect(LineContrast.adjusted(c("#2A9D8F"), against: LineContrast.darkGround, minimum: 25) == c("#FFFFFF"))
    }

    @Test func fitIsMinimal() {
        let out = LineContrast.adjusted(c("#F2C200"), against: LineContrast.lightGround)
        #expect(LineContrast.ratio(out, LineContrast.lightGround) < 3.15)
    }

    @Test func oklchRoundTrips() {
        for hex in ["#2A9D8F", "#E8590C", "#1A237E", "#F2C200"] {
            let o = OKLCH.from(c(hex))
            #expect(OKLCH.rgb(l: o.l, c: o.c, h: o.h) == c(hex))
        }
    }
}
