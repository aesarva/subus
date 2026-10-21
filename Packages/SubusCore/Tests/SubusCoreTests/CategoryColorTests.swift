import Foundation
import Testing
@testable import SubusCore

private let teal = SRGBColor(red: 0x2A, green: 0x9D, blue: 0x8F)

private func libraryJSON(_ l: Library) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: Transfer.exportJSON(l, logos: [:])) as? [String: Any])
}

@Suite struct CategoryColorTests {
    @Test func rgbHexRoundTrip() {
        #expect(SRGBColor(hex: "#2a9d8f")?.hex == "#2A9D8F")
        #expect(SRGBColor(hex: "2A9D8F") == teal)
        #expect(SRGBColor(hex: "#GGHHII") == nil)
        #expect(SRGBColor(hex: "#FFF") == nil)
        #expect(SRGBColor(hex: "") == nil)
    }

    @Test func v1CategoryDecodes() throws {
        let json = #"{"id":"6A1C8A57-7F4E-4C0E-9D7E-2B1B6E0B9C11","name":"Music","colorIndex":2}"#
        let c = try JSONDecoder().decode(Category.self, from: Data(json.utf8))
        #expect(c.customColor == nil)
        #expect(c.color == .preset(2))
    }

    @Test func customColorRoundTrips() throws {
        let c = Category(name: "Work", colorIndex: 4, customColor: teal)
        let data = try JSONEncoder().encode(c)
        #expect(String(decoding: data, as: UTF8.self).contains(##""customColor":"#2A9D8F""##))
        let back = try JSONDecoder().decode(Category.self, from: data)
        #expect(back.color == .custom(teal))
        #expect(back.colorIndex == 4)
    }

    @Test func badCustomColorFallsBackToPreset() throws {
        var l = Library()
        l.categories = [Category(name: "A", colorIndex: 1), Category(name: "B", colorIndex: 3)]
        l.subscriptions = [Subscription(name: "Netflix", price: rub(799), cycle: BillingCycle(1, .month), startDate: d("2026-01-15"))]
        var json = try libraryJSON(l)
        var categories = try #require(json["categories"] as? [[String: Any]])
        categories[0]["customColor"] = 42
        categories[1]["customColor"] = "#GGHHII"
        json["categories"] = categories
        let p = try Transfer.parseJSON(JSONSerialization.data(withJSONObject: json))
        #expect(p.library.categories.map(\.customColor) == [nil, nil])
        #expect(p.library.categories.map(\.color) == [.preset(1), .preset(3)])
        #expect(p.library.subscriptions.map(\.name) == ["Netflix"])
    }

    @Test func setColorPresetClearsCustom() {
        var c = Category(name: "Work", colorIndex: 4, customColor: teal)
        c.setColor(.preset(6))
        #expect(c.customColor == nil)
        #expect(c.colorIndex == 6)
        #expect(c.color == .preset(6))
    }

    @Test func setColorCustomKeepsIndex() {
        var c = Category(name: "Work", colorIndex: 4)
        c.setColor(.custom(teal))
        #expect(c.colorIndex == 4)
        #expect(c.color == .custom(teal))
    }

    @Test func addCategoryReusesNamesake() {
        var l = Library()
        l.categories = [Category(name: "Music", colorIndex: 2)]
        let id = l.addCategory(name: " music ", color: .preset(5))
        #expect(id == l.categories[0].id)
        #expect(l.categories.count == 1)
        #expect(l.categories[0].colorIndex == 2)
    }

    @Test func addCategoryAppendsWithColor() {
        var l = Library()
        l.categories = [Category(name: "Music", colorIndex: 2)]
        let id = l.addCategory(name: " Work ", color: .custom(teal))
        let added = try? #require(l.categories.first { $0.id == id })
        #expect(added?.name == "Work")
        #expect(added?.color == .custom(teal))
        #expect(added?.colorIndex == 1)
        let preset = l.addCategory(name: "Games", color: .preset(7))
        #expect(l.categories.first { $0.id == preset }?.color == .preset(7))
    }

    @Test func addPaymentMethodReusesNamesake() {
        var l = Library()
        l.paymentMethods = [PaymentMethod(label: "Т-Банк •• 4242", colorIndex: 0)]
        let id = l.addPaymentMethod(label: "т-банк •• 4242 ")
        #expect(id == l.paymentMethods[0].id)
        #expect(l.paymentMethods.count == 1)
        let other = l.addPaymentMethod(label: "Revolut •• 0815")
        #expect(other != id)
        #expect(l.paymentMethods.last?.label == "Revolut •• 0815")
        #expect(l.paymentMethods.last?.colorIndex == 1)
    }

    private func importPair() -> (local: Library, preview: ImportPreview) {
        var local = Library()
        local.categories = [Category(name: "Music", colorIndex: 2, customColor: SRGBColor(hex: "#112233"))]
        var incoming = Library()
        incoming.categories = [Category(name: "Music", colorIndex: 2, customColor: SRGBColor(hex: "#445566"))]
        return (local, ImportPreview(library: incoming))
    }

    @Test func addImportKeepsLocalColor() {
        let (local, preview) = importPair()
        let r = Transfer.apply(preview, to: local, mode: .add)
        #expect(r.library.categories.count == 1)
        #expect(r.library.categories[0].customColor == SRGBColor(hex: "#112233"))
    }

    @Test func replaceImportTakesFileColor() {
        let (local, preview) = importPair()
        let r = Transfer.apply(preview, to: local, mode: .replace)
        #expect(r.library.categories.map(\.customColor) == [SRGBColor(hex: "#445566")])
    }

    @Test func jsonExportKeepsCustomColor() throws {
        var l = Library()
        l.categories = [Category(name: "Work", colorIndex: 4, customColor: teal)]
        let p = try Transfer.parseJSON(Transfer.exportJSON(l, logos: [:]))
        #expect(p.library.categories.first?.color == .custom(teal))
    }
}
