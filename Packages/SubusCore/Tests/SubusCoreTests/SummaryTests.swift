import Foundation
import Testing
@testable import SubusCore

struct SummaryTests {
    let today = d("2026-10-20")
    let table = RateTable(date: d("2026-10-17"), rubPerUnit: ["RUB": 1, "USD": 80, "EUR": 90],
                          fetchedAt: Date(timeIntervalSince1970: 0))

    func sub(_ name: String, _ price: Money, _ cycle: BillingCycle = .monthly, trialEnd: LocalDate? = nil,
             category: UUID? = nil, method: UUID? = nil) -> Subscription {
        var s = Subscription(name: name, price: price, cycle: cycle, startDate: d("2026-01-01"), trialEndDate: trialEnd)
        s.categoryID = category
        s.paymentMethodID = method
        return s
    }

    func build(_ subs: [Subscription], table: RateTable? = nil, ratesDate: LocalDate? = nil) -> SpendingSummary {
        SummaryBuilder.build(library: Library(subscriptions: subs), baseCurrency: "RUB",
                             converter: CurrencyConverter(table: table), ratesDate: ratesDate, today: today)
    }

    @Test func mixedCurrencies() {
        let s = build([sub("A", rub(1200), .yearly), sub("B", usd(10))], table: table, ratesDate: table.date)
        #expect(s.monthly == rub(900))
        #expect(s.yearly == rub(10800))
        #expect(s.ratesDate == d("2026-10-17"))
        #expect(s.excludedCount == 0)
    }

    @Test func onlyBaseCurrencyNoRatesDate() {
        let s = build([sub("A", rub(100)), sub("B", rub(200))], table: table, ratesDate: table.date)
        #expect(s.monthly == rub(300))
        #expect(s.ratesDate == nil)
    }

    @Test func unknownCurrencyExcluded() {
        let s = build([sub("A", rub(100)), sub("B", usd(10)), sub("C", Money(5, "XXX"))], table: table, ratesDate: table.date)
        #expect(s.monthly == rub(900))
        #expect(s.excludedCount == 1)
        let noTable = build([sub("A", rub(100)), sub("B", usd(10))])
        #expect(noTable.monthly == rub(100))
        #expect(noTable.excludedCount == 1)
        #expect(noTable.ratesDate == nil)
    }

    @Test func inactiveAndEndedIgnored() {
        var off = sub("Off", usd(10)); off.isActive = false
        var ended = sub("Ended", Money(5, "XXX")); ended.endDate = d("2026-10-01")
        let s = build([sub("A", rub(100)), off, ended], table: table, ratesDate: table.date)
        #expect(s.monthly == rub(100))
        #expect(s.excludedCount == 0)
    }

    @Test func trialCountsFuturePrice() {
        var trial = sub("T", rub(0), trialEnd: d("2026-11-01"))
        trial.changePrice(to: rub(500), effectiveFrom: d("2026-11-01"))
        let s = build([trial])
        #expect(s.monthly == rub(500))
        #expect(s.trialCount == 1)

        var past = sub("P", rub(0), trialEnd: d("2026-10-01"))
        past.changePrice(to: rub(500), effectiveFrom: d("2026-10-01"))
        let p = build([past])
        #expect(p.monthly == rub(500))
        #expect(p.trialCount == 0)
    }

    @Test func slices() {
        let k = UUID(), m = UUID()
        let s = build([sub("A", rub(100), category: k, method: m), sub("B", rub(200), category: k, method: m),
                       sub("C", rub(50))])
        #expect(s.byCategory == [Slice(id: k, monthly: rub(300)), Slice(id: nil, monthly: rub(50))])
        #expect(s.byPaymentMethod == [Slice(id: m, monthly: rub(300)), Slice(id: nil, monthly: rub(50))])
    }

    @Test func slicesSkipUnconvertibleAndBreakTies() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let s = build([sub("B", rub(100), category: b), sub("A", rub(100), category: a),
                       sub("X", Money(9, "XXX"), category: UUID())])
        #expect(s.byCategory == [Slice(id: a, monthly: rub(100)), Slice(id: b, monthly: rub(100))])
    }

    @Test func increasesWithinYear() {
        var s = sub("S", rub(100))
        s.changePrice(to: rub(150), effectiveFrom: d("2026-03-01"))
        let inc = SummaryBuilder.priceIncreases(library: Library(subscriptions: [s]), today: today)
        #expect(inc == [PriceIncrease(subscriptionID: s.id, from: rub(100), to: rub(150), on: d("2026-03-01"))])

        var old = sub("Old", rub(100)); old.changePrice(to: rub(150), effectiveFrom: d("2025-09-01"))
        var cut = sub("Cut", rub(100)); cut.changePrice(to: rub(80), effectiveFrom: d("2026-03-01"))
        #expect(SummaryBuilder.priceIncreases(library: Library(subscriptions: [old, cut]), today: today).isEmpty)
    }

    @Test func increaseWindowBoundariesAndOrder() {
        func early(_ name: String) -> Subscription {
            var s = sub(name, rub(100)); s.priceHistory = [PriceChange(effectiveFrom: d("2024-01-01"), price: rub(100))]
            return s
        }
        var edge = early("Edge"); edge.changePrice(to: rub(110), effectiveFrom: today.adding(days: -365))
        var inside = early("In"); inside.changePrice(to: rub(110), effectiveFrom: today.adding(days: -364))
        var future = early("Fut"); future.changePrice(to: rub(110), effectiveFrom: today.adding(days: 1))
        var newest = early("New"); newest.changePrice(to: rub(110), effectiveFrom: d("2026-09-01"))
        let inc = SummaryBuilder.priceIncreases(library: Library(subscriptions: [edge, inside, future, newest]), today: today)
        #expect(inc.map(\.subscriptionID) == [newest.id, inside.id])
    }

    @Test func currencyChangeIsNotAnIncrease() {
        var s = sub("S", usd(10))
        s.changePrice(to: eur(9), effectiveFrom: d("2026-06-01"))
        #expect(SummaryBuilder.priceIncreases(library: Library(subscriptions: [s]), today: today) == [])
        let summary = build([s], table: table, ratesDate: table.date)
        #expect(summary.monthly == rub(810))
    }
}
