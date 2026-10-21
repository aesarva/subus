import Foundation
import Testing
@testable import SubusCore

private let today = d("2026-10-21")
private let rates = RateTable(date: today, rubPerUnit: ["RUB": 1, "USD": 81.6], fetchedAt: .now)
private let conv = CurrencyConverter(table: rates)

private func sub(_ name: String = "X", _ price: Money = rub(399), _ cycle: BillingCycle = .monthly,
                 start: String = "2026-01-12", active: Bool = true, end: String? = nil) -> Subscription {
    var s = Subscription(name: name, price: price, cycle: cycle, startDate: d(start), endDate: end.map(d))
    s.isActive = active
    return s
}

private func year(_ s: Subscription) -> SubscriptionYear {
    .build(s, today: today, baseCurrency: "RUB", converter: conv)
}

private func rows(_ subs: [Subscription], showInactive: Bool = false, sort: YearSort) -> [YearSubscriptionRow] {
    var f = YearFilter()
    f.showInactive = showInactive
    return YearPlan.subscriptionRows(library: Library(subscriptions: subs), filter: f, today: today,
                                     baseCurrency: "RUB", converter: conv, sort: sort)
}

@Test func monthlyYear() {
    let y = year(sub())
    #expect(y.charges.count == 12)
    #expect(y.total.amount == rub(4788))
    #expect(y.next?.date == d("2026-11-12"))
}

@Test func nextBeyondRange() {
    let y = year(sub("Y", rub(1000), .yearly, start: "2027-11-01"))
    #expect(y.charges.isEmpty)
    #expect(y.next?.date == d("2027-11-01"))
}

@Test func inactiveNoNext() {
    let y = year(sub(active: false))
    #expect(y.charges.isEmpty)
    #expect(y.next == nil)
}

@Test func firstAtNewPrice() {
    var s = sub("X", rub(299))
    s.changePrice(to: rub(399), effectiveFrom: d("2027-01-05"))
    #expect(year(s).firstAtNewPrice == [d("2027-01-12")])
}

@Test func firstAtNewPriceBeforeFirstChargeInRange() {
    var s = sub("X", rub(299), start: "2026-01-26")
    s.changePrice(to: rub(399), effectiveFrom: d("2026-10-22"))
    #expect(year(s).firstAtNewPrice == [d("2026-10-26")])
}

@Test func firstAtNewPriceNotMarkedForOldChange() {
    var s = sub("X", rub(299))
    s.changePrice(to: rub(399), effectiveFrom: d("2026-08-12"))
    #expect(year(s).firstAtNewPrice.isEmpty)
}

@Test func firstAtNewPriceNotMarkedForTrial() {
    let s = Subscription(name: "T", price: rub(399), cycle: .monthly, startDate: d("2026-10-01"),
                         trialEndDate: d("2026-11-01"))
    #expect(year(s).firstAtNewPrice.isEmpty)
}

@Test func priceStepsPercent() throws {
    var s = sub("X", rub(299))
    s.changePrice(to: rub(399), effectiveFrom: d("2027-01-05"))
    let step = try #require(SubscriptionYear.priceSteps(s).first)
    #expect(step.on == d("2027-01-05"))
    let percent = try #require(step.percent)
    #expect(abs(Double(truncating: percent as NSDecimalNumber) - 33.44) < 0.01)

    var mixed = sub("M", usd(10))
    mixed.changePrice(to: rub(900), effectiveFrom: d("2027-01-05"))
    #expect(SubscriptionYear.priceSteps(mixed).first?.percent == nil)

    var zero = sub("Z", rub(0))
    zero.changePrice(to: rub(5), effectiveFrom: d("2027-01-05"))
    #expect(SubscriptionYear.priceSteps(zero).first?.percent == nil)
}

@Test func rowsInactiveOnlyWhenShown() {
    let live = sub("Live"), off = sub("Off", active: false), done = sub("Done", end: "2026-09-01")
    #expect(rows([live, off, done], sort: .name).map(\.subscription.name) == ["Live"])
    let all = rows([live, off, done], showInactive: true, sort: .name)
    #expect(all.map(\.subscription.name) == ["Done", "Live", "Off"])
    #expect(all.map(\.isLive) == [false, true, false])
}

@Test func sortTotalDashLast() {
    let big = sub("B", rub(500)), small = sub("A", rub(100))
    let tieA = sub("TieA", rub(100)), noRate = sub("Z", Money(5, "JPY"))
    let r = rows([noRate, small, big, tieA], sort: .total).map(\.subscription.name)
    #expect(r == ["B", "A", "TieA", "Z"])
}

@Test func sortNextDateNilLast() {
    let soon = sub("Soon", start: "2026-01-22"), later = sub("Later", start: "2026-01-30")
    let off = sub("Off", active: false)
    let r = rows([off, later, soon], showInactive: true, sort: .nextDate).map(\.subscription.name)
    #expect(r == ["Soon", "Later", "Off"])
}

@Test func sortName() {
    let r = rows([sub("Яндекс"), sub("JetBrains"), sub("iCloud+")], sort: .name).map(\.subscription.name)
    #expect(r == ["iCloud+", "JetBrains", "Яндекс"])
}
