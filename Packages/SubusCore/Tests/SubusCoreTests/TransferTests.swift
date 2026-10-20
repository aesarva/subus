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

    @Test func csvRejectsContradictoryDates() {
        let head = "name,price,currency,cycle_count,cycle_unit,start_date,end_date,trial_end_date\n"
        let text = head + "A,1,USD,1,month,2026-03-01,,2026-02-01\nB,1,USD,1,month,2026-01-01,2026-02-01,2026-03-01\nC,1,USD,1,month,2026-01-01,2025-12-01,\nD,1,USD,1,month,2026-01-01,2026-03-01,2026-02-01"
        let p = Transfer.parseCSV(text, now: now)
        #expect(p.library.subscriptions.map(\.name) == ["D"])
        #expect(p.errors == [ImportRowError(line: 2, field: "trial_end_date"), ImportRowError(line: 3, field: "end_date"),
                             ImportRowError(line: 4, field: "end_date")])
    }

    @Test func duplicateIDsInImportGetDistinctLogos() {
        let (_, s) = library()
        var dup = s
        dup.name = "Dup"
        var same = s
        same.name = "Same ID"
        dup.id = UUID()
        var incoming = Library()
        incoming.subscriptions = [s, dup, same]
        let r = Transfer.apply(ImportPreview(library: incoming, logos: ["\(s.id).png": png]), to: Library(), mode: .add)
        let names = r.library.subscriptions.map { sub -> String? in
            if case .image(let n) = sub.logo { n } else { nil }
        }
        #expect(r.library.subscriptions.count == 3)
        #expect(Set(names).count == 3)
        #expect(names.allSatisfy { $0 != nil && r.logos[$0!] == png })
        #expect(r.logos.count == 3)
    }

    @Test func parseJSONRejectsNullSubscriptions() {
        #expect(throws: TransferError.notSubusFile) { try Transfer.parseJSON(Data(#"{"subscriptions":null}"#.utf8)) }
    }

    @Test func replaceModeGivesDistinctLogos() {
        let (_, s) = library()
        var other = s
        other.id = UUID()
        other.name = "Other"
        var bare = s
        bare.id = UUID()
        bare.name = "No bytes"
        bare.logo = .image(fileName: "missing.png")
        var twin = bare
        twin.id = UUID()
        var incoming = Library()
        incoming.subscriptions = [s, other, bare, twin]
        let shared = "\(s.id).png"
        for i in [0, 1] { incoming.subscriptions[i].logo = .image(fileName: shared) }
        let r = Transfer.apply(ImportPreview(library: incoming, logos: [shared: png]), to: Library(), mode: .replace)
        let names = r.library.subscriptions.compactMap { sub -> String? in
            if case .image(let n) = sub.logo { n } else { nil }
        }
        #expect(r.library.subscriptions.count == 4)
        #expect(names.count == 2)
        #expect(Set(names).count == 2)
        #expect(names.allSatisfy { r.logos[$0] == png })
        #expect(r.logos.count == 2)
        #expect(r.library.subscriptions[2...].allSatisfy { $0.logo == .monogram(colorIndex: nil) })
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
            #expect(p.errors.first?.field == "price", "\(bad)")
        }
    }

    @Test func csvMissingRequiredColumnAndLineNumbers() {
        let text = "\u{FEFF}Name,PRICE,currency,cycle_unit,start_date,extra\r\n\"A\nB\",1,USD,month,2026-01-01,x\r\n\r\nC,1,USD,month,2026-01-01,x\r\n"
        let p = Transfer.parseCSV(text, now: now)
        #expect(p.library.subscriptions.isEmpty)
        #expect(p.errors == [ImportRowError(line: 2, field: "cycle_count"), ImportRowError(line: 5, field: "cycle_count")])
    }

    @Test func jsonRejectsNonSubusObjectAndBadLogoEntry() throws {
        #expect(throws: TransferError.notSubusFile) { try Transfer.parseJSON(Data(#"{"hello":1}"#.utf8)) }
        #expect(throws: TransferError.newerSchema(9)) { try Transfer.parseJSON(Data(#"{"schemaVersion":9,"subscriptions":"junk"}"#.utf8)) }
        let p = try Transfer.parseJSON(Data(("{\"subscriptions\":[],\"logos\":{\"a.png\":\"" + png.base64EncodedString() + "\",\"b.png\":5}}").utf8))
        #expect(p.logos == ["a.png": png])
    }

    @Test func csvUnterminatedQuoteIsRowError() {
        let text = "name,price,currency,cycle_count,cycle_unit,start_date\nA,1,USD,1,month,2026-01-01\n\"B,1,USD,1,month,2026-01-01\nC,1,USD,1,month,2026-01-01"
        let p = Transfer.parseCSV(text, now: now)
        #expect(p.library.subscriptions.map(\.name) == ["A"])
        #expect(p.errors == [ImportRowError(line: 3, field: "csv")])
    }

    @Test func addFallsBackToMonogramWithoutLogoData() throws {
        let (l, s) = library()
        let p = try Transfer.parseJSON(Transfer.exportJSON(l, logos: [:]))
        let r = Transfer.apply(p, to: l, mode: .add)
        #expect(r.library.subscriptions.first { $0.id != s.id }?.logo == .monogram(colorIndex: nil))
        #expect(r.logos.isEmpty)
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
