import Foundation
import Testing
@testable import SubusCore

private func sub(_ name: String = "X", id: UUID = UUID()) -> Subscription {
    Subscription(id: id, name: name, price: rub(100), cycle: .monthly, startDate: d("2026-01-10"))
}

@Test func initRecordsFirstPrice() {
    let s = Subscription(name: "X", price: rub(100), cycle: .monthly, startDate: d("2026-01-10"), trialEndDate: d("2026-01-24"))
    #expect(s.priceHistory == [PriceChange(effectiveFrom: d("2026-01-24"), price: rub(100))])
    #expect(s.anchor == d("2026-01-24"))
}

@Test func priceOnDate() {
    var s = sub()
    s.changePrice(to: rub(150), effectiveFrom: d("2026-06-01"))
    #expect(s.price(on: d("2026-05-31")) == rub(100))
    #expect(s.price(on: d("2026-06-01")) == rub(150))
    #expect(s.price == rub(150))
    s.changePrice(to: rub(160), effectiveFrom: d("2026-06-01"))
    #expect(s.priceHistory.count == 2)
    #expect(s.price == rub(160))
}

@Test func changeBeforeAnchorApplies() {
    var s = Subscription(name: "X", price: rub(100), cycle: .monthly, startDate: d("2026-11-01"))
    s.changePrice(to: rub(150), effectiveFrom: d("2026-10-20"))
    #expect(s.price(on: d("2026-11-01")) == rub(150))
    #expect(s.price == rub(150))
}

@Test func changeOverridesLaterScheduledChange() {
    var s = Subscription(name: "X", price: rub(100), cycle: .monthly, startDate: d("2026-01-01"))
    s.changePrice(to: rub(150), effectiveFrom: d("2026-06-01"))
    s.changePrice(to: rub(120), effectiveFrom: d("2026-03-01"))
    #expect(s.priceHistory == [PriceChange(effectiveFrom: d("2026-01-01"), price: rub(100)),
                               PriceChange(effectiveFrom: d("2026-03-01"), price: rub(120))])
    #expect(s.price(on: d("2026-07-01")) == rub(120))
}

@Test func endedAndLive() {
    var s = sub()
    s.endDate = d("2026-10-19")
    #expect(s.isEnded(today: d("2026-10-20")))
    #expect(!s.isLive(today: d("2026-10-20")))
    s.endDate = d("2026-10-20")
    #expect(!s.isEnded(today: d("2026-10-20")))
    #expect(s.isLive(today: d("2026-10-20")))
    s.isActive = false
    #expect(!s.isLive(today: d("2026-10-20")))
}

@Test func removingCategoryClearsReferences() {
    let c = Category(id: UUID(), name: "C", colorIndex: 0), dd = Category(id: UUID(), name: "D", colorIndex: 1)
    let p = PaymentMethod(id: UUID(), label: "Card", colorIndex: 0)
    var a = sub("a"), b = sub("b"), e = sub("e")
    a.categoryID = c.id; b.categoryID = c.id; e.categoryID = dd.id
    a.paymentMethodID = p.id; e.paymentMethodID = p.id
    var lib = Library(schemaVersion: 1, subscriptions: [a, b, e], categories: [c, dd], paymentMethods: [p])
    lib.removeCategory(c.id)
    #expect(lib.subscriptions.map(\.categoryID) == [nil, nil, dd.id])
    #expect(lib.categories == [dd])
    lib.removePaymentMethod(p.id)
    #expect(lib.subscriptions.allSatisfy { $0.paymentMethodID == nil })
    #expect(lib.paymentMethods.isEmpty)
}

@Test func tolerantDecoding() throws {
    let id = UUID()
    let json = """
    {"id":"\(id.uuidString)","name":"X","price":{"amount":"100","currency":"rub"},
     "cycle":{"count":1,"unit":"month"},"startDate":"2026-01-10","bogus":1}
    """
    let s = try JSONDecoder().decode(Subscription.self, from: Data(json.utf8))
    #expect(s.isActive)
    #expect(s.notificationsEnabled)
    #expect(s.notes == "")
    #expect(s.priceHistory.isEmpty)
    #expect(s.price == rub(100))
}

@Test func libraryRoundTrip() throws {
    let cat = Category(id: UUID(), name: "Media", colorIndex: 2)
    let pm = PaymentMethod(id: UUID(), label: "Visa", colorIndex: 3)
    var s = sub("Full")
    s.logo = .image(fileName: "3F2A-9C.png")
    s.endDate = d("2027-01-01"); s.trialEndDate = d("2026-01-20")
    s.isActive = false; s.categoryID = cat.id; s.paymentMethodID = pm.id
    s.websiteURL = URL(string: "https://example.com"); s.manageURL = URL(string: "https://example.com/manage")
    s.notificationsEnabled = false; s.notes = "note"
    s.changePrice(to: usd(5), effectiveFrom: d("2026-08-01"))
    let lib = Library(schemaVersion: 1, subscriptions: [s], categories: [cat], paymentMethods: [pm])
    let back = try JSONDecoder().decode(Library.self, from: try JSONEncoder().encode(lib))
    #expect(back == lib)
}

@Test func priceBeforeHistoryFallsBackToPrice() {
    var s = sub()
    s.priceHistory = [PriceChange(effectiveFrom: d("2026-06-01"), price: rub(150))]
    s.price = rub(150)
    #expect(s.price(on: d("2026-01-01")) == rub(150))
}

@Test func sanitizedFixesInvariants() {
    let shared = UUID()
    var a = sub("a", id: shared), b = sub("b", id: shared)
    a.categoryID = UUID()
    b.logo = .image(fileName: "../../etc/x.png")
    let c1 = Category(id: shared, name: "c1", colorIndex: 12), c2 = Category(id: shared, name: "c2", colorIndex: -3)
    let lib = Library(schemaVersion: 1, subscriptions: [a, b], categories: [c1, c2],
                      paymentMethods: [PaymentMethod(id: UUID(), label: "p", colorIndex: 99)]).sanitized()
    #expect(lib.subscriptions[0].id == shared)
    #expect(lib.subscriptions[1].id != shared)
    #expect(lib.subscriptions[0].categoryID == nil)
    #expect(lib.subscriptions[1].logo == .monogram(colorIndex: nil))
    #expect(lib.categories[0].id == shared && lib.categories[1].id != shared)
    #expect(lib.categories.allSatisfy { (0..<Category.paletteCount).contains($0.colorIndex) })
    #expect(lib.paymentMethods.allSatisfy { (0..<Category.paletteCount).contains($0.colorIndex) })
    #expect(Logo.isSafeFileName("3F2A1B7C-0000-4000-8000-123456789A9C.png"))
    #expect(!Logo.isSafeFileName("a/b.png"))
    #expect(!Logo.isSafeFileName(".png"))
    #expect(!Logo.isSafeFileName("x.jpg"))
}

@Test func sanitizedSortsHistoryAndSetsPrice() {
    var s = sub()
    s.priceHistory = [PriceChange(effectiveFrom: d("2026-06-01"), price: rub(150)),
                      PriceChange(effectiveFrom: d("2026-01-01"), price: rub(100))]
    s.price = rub(100)
    let out = Library(schemaVersion: 1, subscriptions: [s], categories: [], paymentMethods: []).sanitized()
    #expect(out.subscriptions[0].priceHistory.map(\.effectiveFrom) == [d("2026-01-01"), d("2026-06-01")])
    #expect(out.subscriptions[0].price == rub(150))
}

@Test func initialAndEmpty() {
    let lib = Library.initial(categoryNames: (0..<10).map { "c\($0)" })
    #expect(lib.categories.map(\.colorIndex) == [0, 1, 2, 3, 4, 5, 6, 7, 0, 1])
    #expect(lib.schemaVersion == 1)
    #expect(Library.empty == Library(schemaVersion: 1, subscriptions: [], categories: [], paymentMethods: []))
}
