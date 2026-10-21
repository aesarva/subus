import Foundation
import Testing
@testable import SubusCore

private let mondayFirst: Calendar = {
    var c = msk
    c.firstWeekday = 2
    return c
}()

private let sundayFirst: Calendar = {
    var c = msk
    c.firstWeekday = 1
    return c
}()

private extension BillingCycle {
    static let d1 = BillingCycle(1, .day)
    static let w1 = BillingCycle(1, .week)
}

private let today = d("2026-10-21")
private let rates = RateTable(date: today, rubPerUnit: ["RUB": 1, "USD": 81.6, "EUR": 94.3], fetchedAt: .now)
private let converter = CurrencyConverter(table: rates)

private func sub(_ name: String = "X", _ price: Money = rub(100), _ cycle: BillingCycle = .monthly,
                 start: String = "2026-01-05", trialEnd: String? = nil, end: String? = nil) -> Subscription {
    Subscription(name: name, price: price, cycle: cycle, startDate: d(start),
                 trialEndDate: trialEnd.map(d), endDate: end.map(d))
}

private func plan(_ subs: [Subscription], filter: YearFilter = YearFilter(), today: LocalDate = today,
                  calendar: Calendar = mondayFirst, base: String = "RUB",
                  converter: CurrencyConverter = converter, categories: [SubusCore.Category] = []) -> YearPlan {
    YearPlan.build(library: Library(subscriptions: subs, categories: categories), filter: filter, today: today,
                   calendar: calendar, baseCurrency: base, converter: converter)
}

@Test func rangeIsTwelveMonths() {
    #expect(YearPlan.range(today: today) == d("2026-10-21")...d("2027-10-20"))
    #expect(YearPlan.range(today: d("2028-02-29")) == d("2028-02-29")...d("2029-02-27"))
    #expect(YearPlan.range(today: d("2027-03-01")) == d("2027-03-01")...d("2028-02-29"))
}

@Test func lastDayIncluded() {
    let onLastDay = plan([sub("X", rub(1), .yearly, start: "2027-10-20")])
    #expect(onLastDay.charges.map(\.charge.date) == [d("2027-10-20")])
    #expect(plan([sub("X", rub(1), .yearly, start: "2027-10-21")]).charges.isEmpty)
}

@Test func weeksMondayFirst() throws {
    let p = plan([])
    #expect(p.weeks.count == 53)
    let first = p.weeks[0]
    #expect(first.id == d("2026-10-19"))
    #expect(first.start == today)
    #expect(first.isPartial)
    func week(_ iso: String) throws -> YearPeriod { try #require(p.weeks.first { $0.id == d(iso) }) }
    #expect(try week("2026-12-28").monthKey == MonthKey(year: 2026, month: 12))
    #expect(try week("2027-03-29").monthKey == MonthKey(year: 2027, month: 4))
    #expect(try week("2026-11-30").monthKey == MonthKey(year: 2026, month: 12))
    #expect(p.weeks.last!.end == d("2027-10-20"))
}

@Test func fiftyFourWeeks() {
    let p = plan([], today: d("2028-01-02"))
    #expect(p.weeks.count == 54)
    let columns = p.weekColumns()
    #expect(columns.count == 14)
    #expect(columns.first!.weeks.count == 1)
    #expect(columns.last!.weeks.count == 1)
    #expect(columns.map(\.weeks.count).reduce(0, +) == 54)
}

@Test func sundayFirstWeeks() throws {
    let p = plan([], calendar: sundayFirst)
    #expect(p.weeks[0].id == d("2026-10-18"))
    let w = try #require(p.weeks.first { $0.id == d("2027-03-28") })
    #expect(w.monthKey == MonthKey(year: 2027, month: 3))
}

@Test func monthsPartial() {
    let p = plan([])
    #expect(p.months.count == 13)
    #expect(p.months[0].start == today)
    #expect(p.months[0].isPartial)
    #expect(p.months.last!.end == d("2027-10-20"))
    #expect(p.months.last!.isPartial)
    #expect(p.months.dropFirst().dropLast().allSatisfy { !$0.isPartial })

    let q = plan([], today: d("2026-11-01"))
    #expect(q.months.count == 12)
    #expect(q.months.allSatisfy { !$0.isPartial })
}

@Test func levels() {
    #expect([0, 1, 3, 4, 7].map { YearPlan.level(count: $0, thresholds: YearPlan.weekLevels) } == [0, 1, 3, 4, 4])
    #expect([0, 1, 3, 4, 6, 7, 9, 10].map { YearPlan.level(count: $0, thresholds: YearPlan.monthLevels) }
        == [0, 1, 1, 2, 2, 3, 3, 4])
    let daily = sub("X", rub(1), .d1, start: "2026-01-01")
    let p = plan([daily])
    let full = p.weeks.first { !$0.isPartial }!
    #expect(full.count == 7)
    #expect(full.level == 4)
    let many = plan((0..<50).map { sub("s\($0)", rub(1), .d1, start: "2026-01-01") })
    #expect(many.weeks[1].count == 350)
    #expect(many.weeks[1].level == 4)
}

@Test func trialBoundary() {
    let trial = sub("X", rub(100), .monthly, start: "2026-10-01", trialEnd: "2026-10-24")
    let p = plan([trial])
    #expect(p.charges.first!.charge.date == d("2026-10-24"))
    #expect(p.charges.allSatisfy { $0.isTrialFuturePrice })
    #expect(p.trialSubscriptionIDs == [trial.id])

    let over = sub("X", rub(100), .monthly, start: "2026-10-01", trialEnd: "2026-10-21")
    let q = plan([over])
    #expect(q.charges.allSatisfy { !$0.isTrialFuturePrice })
    #expect(q.trialSubscriptionIDs.isEmpty)
}

@Test func planEndDateInclusive() {
    let s = sub(start: "2026-01-15", end: "2027-01-15")
    let p = plan([s])
    #expect(p.charges.last!.charge.date == d("2027-01-15"))
    #expect(p.charges.count == 3)
    #expect(plan([sub(end: "2026-10-20")]).charges.isEmpty)
}

@Test func planInactiveHasNoCharges() {
    var s = sub()
    s.isActive = false
    let p = plan([s])
    #expect(p.charges.isEmpty)
    #expect(p.matchedSubscriptionIDs == [s.id])
}

@Test func farFirstCharge() {
    let s = sub(start: "2027-11-01")
    let p = plan([s])
    #expect(p.charges.isEmpty)
    #expect(p.matchedSubscriptionIDs == [s.id])
}

@Test func totalsAddUp() {
    let subs = [sub("A", rub(299)), sub("B", usd(10), .yearly, start: "2026-03-01"),
                sub("C", eur(5), .w1, start: "2026-02-02"), sub("D", rub(1000), BillingCycle(3, .month), start: "2026-01-20")]
    let p = plan(subs)
    func sum(_ xs: [Decimal]) -> Decimal { xs.reduce(0, +) }
    #expect(sum(p.weeks.map(\.total.amount.amount)) == p.total.amount.amount)
    #expect(sum(p.months.map(\.total.amount.amount)) == p.total.amount.amount)
    #expect(p.weeks.map(\.count).reduce(0, +) == p.charges.count)
    #expect(p.months.map(\.count).reduce(0, +) == p.charges.count)
    #expect(p.total.display == .amount(p.total.amount))
    #expect(p.total.convertedCount == p.charges.count)
}

@Test func usdBaseCurrency() {
    let p = plan([sub("X", rub(816), .yearly, start: "2026-01-01")], base: "USD")
    #expect(p.charges[0].converted == Money(10, "USD"))
    #expect(p.total.amount == Money(10, "USD"))
}

@Test func partialConversion() {
    var s = sub("X", rub(100), .monthly, start: "2026-01-05")
    s.changePrice(to: Money(5, "XYZ"), effectiveFrom: d("2027-02-01"))
    let p = plan([s])
    let missing = p.charges.filter { $0.converted == nil }.count
    #expect(missing > 0 && missing < p.charges.count)
    guard case let .partial(_, n) = p.total.display else { Issue.record("expected partial"); return }
    #expect(n == missing)
    #expect(p.excludedSubscriptionIDs == [s.id])
}

@Test func excludedSortedByName() {
    let b = sub("item 10", Money(5, "XYZ"))
    let a = sub("item 2", Money(5, "XYZ"))
    let ok = sub("ok", rub(1))
    let p = plan([b, ok, a])
    #expect(p.excludedSubscriptionIDs == [a.id, b.id])
}

@Test func noRatesShowsDash() {
    let none = CurrencyConverter(table: nil)
    let p = plan([sub("X", usd(5))], converter: none)
    #expect(p.total.display == .unavailable)
    #expect(plan([], converter: none).total.display == .zero)
}

@Test func chargesOrdered() {
    let a = sub("item 10", rub(1), .yearly, start: "2025-11-01")
    let b = sub("item 2", rub(1), .yearly, start: "2025-11-01")
    let c1 = sub("same", rub(1), .yearly, start: "2025-11-01")
    let c2 = sub("same", rub(1), .yearly, start: "2025-11-01")
    let early = sub("zzz", rub(1), .yearly, start: "2025-10-30")
    let all = [a, b, c1, c2, early]
    let p = plan(all)
    let sameIDs = [c1, c2].map(\.id.uuidString).sorted()
    #expect(p.charges.map(\.charge.subscriptionID.uuidString).first == early.id.uuidString)
    let names = p.charges.map { x in all.first { $0.id == x.charge.subscriptionID }!.name }
    #expect(names == ["zzz", "item 2", "item 10", "same", "same"])
    #expect(p.charges.suffix(2).map(\.charge.subscriptionID.uuidString) == sameIDs)
}

@Test func filterApplies() {
    let work = SubusCore.Category(name: "Work", colorIndex: 0)
    var w = sub("W")
    w.categoryID = work.id
    let o = sub("O")
    var f = YearFilter()
    f.categoryIDs = [work.id]
    let p = plan([w, o], filter: f, categories: [work])
    #expect(!p.charges.isEmpty)
    #expect(p.charges.allSatisfy { $0.charge.subscriptionID == w.id })
    #expect(p.matchedSubscriptionIDs == [w.id])
}
