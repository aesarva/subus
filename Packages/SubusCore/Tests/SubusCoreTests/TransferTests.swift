import Foundation
import Testing
@testable import SubusCore

private let png = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func library() -> (Library, Subscription) {
    var lib = Library.initial(categoryNames: ["Music", "Work"])
    lib.paymentMethods = [PaymentMethod(label: "Visa", colorIndex: 2)]
    var s = Subscription(name: "Spotify", price: usd(Decimal(string: "9.99")!), cycle: .monthly, startDate: d("2026-01-15"))
    s.categoryID = lib.categories[0].id
    s.paymentMethodID = lib.paymentMethods[0].id
    s.logo = .image(fileName: "\(s.id).png")
    s.changePrice(to: usd(Decimal(string: "11.99")!), effectiveFrom: d("2026-06-01"))
    lib.subscriptions = [s]
    return (lib, s)
}

struct TransferTests {
    @Test func jsonRoundTrip() throws {
        let (l, s) = library()
        let data = try Transfer.exportJSON(l, logos: ["\(s.id).png": png])
        let p = try Transfer.parseJSON(data)
        #expect(p.library == l)
        #expect(p.logos == ["\(s.id).png": png])
        #expect(p.errors == [])
    }

    @Test func jsonDropsUnsafeAndInvalidLogos() throws {
        let (l, s) = library()
        let data = try Transfer.exportJSON(l, logos: ["../x.png": png, "bad.png": png, "\(s.id).png": png])
        var text = String(decoding: data, as: UTF8.self)
        text = text.replacingOccurrences(of: "\"bad.png\" : \"\(png.base64EncodedString())\"", with: "\"bad.png\" : \"!!!\"")
        let p = try Transfer.parseJSON(Data(text.utf8))
        #expect(p.logos == ["\(s.id).png": png])
    }

    @Test func jsonThrowsOnGarbageAndNewerSchema() {
        #expect(throws: (any Error).self) { try Transfer.parseJSON(Data("nope".utf8)) }
        #expect(throws: TransferError.newerSchema(9)) { try Transfer.parseJSON(Data(#"{"schemaVersion":9}"#.utf8)) }
    }

    @Test func csvRoundTrip() throws {
        var lib = Library.initial(categoryNames: ["Music"])
        lib.paymentMethods = [PaymentMethod(label: "Visa", colorIndex: 0)]
        var s = Subscription(name: "Foo, \"Bar\"", price: eur(Decimal(string: "1199.99")!), cycle: BillingCycle(3, .week),
                             startDate: d("2026-01-01"), trialEndDate: d("2026-01-10"), endDate: d("2027-01-01"))
        s.isActive = false
        s.categoryID = lib.categories[0].id
        s.paymentMethodID = lib.paymentMethods[0].id
        s.websiteURL = URL(string: "https://example.com/a?b=1")
        s.manageURL = URL(string: "https://example.com/manage")
        s.notes = "line1\nline2; \"q\""
        lib.subscriptions = [s]

        let csv = Transfer.exportCSV(lib)
        #expect(csv.hasPrefix("\u{FEFF}name,price"))
        #expect(csv.contains("\r\n"))
        let p = Transfer.parseCSV(csv, now: now)
        #expect(p.errors == [])
        let t = try #require(p.library.subscriptions.first)
        #expect(p.library.subscriptions.count == 1)
        #expect(t.name == s.name && t.price == s.price && t.cycle == s.cycle)
        #expect(t.startDate == s.startDate && t.endDate == s.endDate && t.trialEndDate == s.trialEndDate)
        #expect(t.isActive == false && t.websiteURL == s.websiteURL && t.manageURL == s.manageURL && t.notes == s.notes)
        #expect(p.library.categories.first { $0.id == t.categoryID }?.name == "Music")
        #expect(p.library.paymentMethods.first { $0.id == t.paymentMethodID }?.label == "Visa")
        #expect(t.notificationsEnabled)
        #expect(t.priceHistory.count == 1)
        #expect(t.logo == .monogram(colorIndex: nil))
    }

    @Test func csvRejectsZeroCycle() {
        let text = "name,price,currency,cycle_count,cycle_unit,start_date\nA,1,USD,0,month,2026-01-01\nB,1,USD,-1,month,2026-01-01\nC,1,USD,1.5,month,2026-01-01\nD,1,USD,1000,month,2026-01-01"
        let p = Transfer.parseCSV(text, now: now)
        #expect(p.library.subscriptions.isEmpty)
        #expect(p.errors == [2, 3, 4, 5].map { ImportRowError(line: $0, field: "cycle_count") })
    }

    @Test func csvSemicolonAndErrors() {
        let text = "name;price;currency;cycle_count;cycle_unit;start_date\nA;9,99;USD;1;month;2026-01-01\nB;abc;USD;1;month;2026-01-01\nC;5;USD;1;fortnight;2026-01-01"
        let p = Transfer.parseCSV(text, now: now)
        #expect(p.library.subscriptions.map(\.name) == ["A"])
        #expect(p.library.subscriptions[0].price.amount == Decimal(string: "9.99")!)
        #expect(p.errors == [ImportRowError(line: 3, field: "price"), ImportRowError(line: 4, field: "cycle_unit")])
    }

    @Test func csvPriceValidation() {
        for bad in ["1,234.56", "9.9.9", "0", "-5", "9abc", ""] {
            let p = Transfer.parseCSV("name,price,currency,cycle_count,cycle_unit,start_date\nA,\"\(bad)\",USD,1,month,2026-01-01\nB,1,USD,1,month,2026-01-01", now: now)
            #expect(p.errors.first?.field == "price" || bad == "", "\(bad)")
        }
    }

    @Test func csvMissingRequiredColumnAndLineNumbers() {
        let text = "\u{FEFF}Name,PRICE,currency,cycle_unit,start_date,extra\r\n\"A\nB\",1,USD,month,2026-01-01,x\r\n\r\nC,1,USD,month,2026-01-01,x\r\n"
        let p = Transfer.parseCSV(text, now: now)
        #expect(p.library.subscriptions.isEmpty)
        #expect(p.errors == [ImportRowError(line: 2, field: "cycle_count"), ImportRowError(line: 5, field: "cycle_count")])
    }

    @Test func csvCreatesCategories() {
        let text = "name,price,currency,cycle_count,cycle_unit,start_date,category\nA,1,USD,1,month,2026-01-01,Музыка\nB,1,USD,1,month,2026-01-01,музыка\n"
        let p = Transfer.parseCSV(text, now: now)
        #expect(p.library.categories.count == 1)
        #expect(p.library.subscriptions.count == 2)
        #expect(Set(p.library.subscriptions.map(\.categoryID)) == [p.library.categories[0].id])
    }

    @Test func importAddingTwiceDoesNotCollideIDs() throws {
        let (l, s) = library()
        let p = try Transfer.parseJSON(Transfer.exportJSON(l, logos: ["\(s.id).png": png]))
        let r = Transfer.apply(p, to: l, mode: .add)
        #expect(r.library.subscriptions.count == 2)
        #expect(Set(r.library.subscriptions.map(\.id)).count == 2)
        #expect(r.library.categories.count == l.categories.count)
        #expect(r.library.paymentMethods.count == 1)
        let copy = try #require(r.library.subscriptions.first { $0.id != s.id })
        #expect(copy.logo == .image(fileName: "\(copy.id).png"))
        #expect(r.logos["\(copy.id).png"] == png)
        #expect(copy.categoryID == l.categories[0].id)
    }

    @Test func addMatchesCategoryByNameAndAppendsNew() {
        let (l, _) = library()
        let text = "name,price,currency,cycle_count,cycle_unit,start_date,category\nA,1,USD,1,month,2026-01-01,music\nB,1,USD,1,month,2026-01-01,Games\n"
        let r = Transfer.apply(Transfer.parseCSV(text, now: now), to: l, mode: .add)
        #expect(r.library.categories.map(\.name) == ["Music", "Work", "Games"])
        let a = r.library.subscriptions.first { $0.name == "A" }
        #expect(a?.categoryID == l.categories[0].id)
    }

    @Test func replaceMode() {
        let (l, _) = library()
        let p = Transfer.parseCSV("name,price,currency,cycle_count,cycle_unit,start_date\nA,1,USD,1,month,2026-01-01", now: now)
        #expect(Transfer.apply(p, to: l, mode: .replace).library == p.library)
    }
}
