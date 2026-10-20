import Foundation
import Testing
@testable import SubusCore

private func sub(_ start: String, _ cycle: BillingCycle = .monthly, trial: String? = nil, end: String? = nil) -> Subscription {
    Subscription(name: "X", price: rub(100), cycle: cycle, startDate: d(start),
                 trialEndDate: trial.map(d), endDate: end.map(d))
}

@Test(arguments: [
    ("2026-01-31", 1, "2026-02-28"), ("2026-01-31", 2, "2026-03-31"), ("2026-01-31", 3, "2026-04-30"),
    ("2028-01-31", 1, "2028-02-29"),
])
func monthEndClamping(anchor: String, n: Int, expected: String) {
    #expect(BillingSchedule.chargeDate(anchor: d(anchor), cycle: .monthly, index: n) == d(expected))
}

@Test(arguments: [(1, "2025-02-28"), (4, "2028-02-29")])
func leapDayYearly(n: Int, expected: String) {
    #expect(BillingSchedule.chargeDate(anchor: d("2024-02-29"), cycle: .yearly, index: n) == d(expected))
}

@Test func otherCycles() {
    #expect(BillingSchedule.chargeDate(anchor: d("2026-01-01"), cycle: BillingCycle(28, .day), index: 1) == d("2026-01-29"))
    #expect(BillingSchedule.chargeDate(anchor: d("2026-01-01"), cycle: BillingCycle(2, .week), index: 1) == d("2026-01-15"))
    #expect(BillingSchedule.chargeDate(anchor: d("2026-01-15"), cycle: BillingCycle(3, .month), index: 1) == d("2026-04-15"))
}

@Test(arguments: [("2026-10-01", "2026-10-25"), ("2026-10-25", "2026-10-25"), ("2026-10-26", "2026-11-25")])
func nextChargeBoundaries(day: String, expected: String) {
    let s = sub("2026-10-25")
    #expect(BillingSchedule.nextCharge(for: s, onOrAfter: d(day))?.date == d(expected))
}

@Test func trialAnchor() {
    let s = sub("2026-10-01", trial: "2026-10-15")
    let first = BillingSchedule.nextCharge(for: s, onOrAfter: d("2026-10-02"))
    #expect(first?.date == d("2026-10-15"))
    #expect(first?.isFirstAfterTrial == true)
    #expect(first?.amount == rub(100))
    let second = BillingSchedule.nextCharge(for: s, onOrAfter: d("2026-10-16"))
    #expect(second?.date == d("2026-11-15"))
    #expect(second?.isFirstAfterTrial == false)
}

@Test func endDateInclusive() {
    let s = sub("2026-10-15", end: "2026-12-15")
    #expect(BillingSchedule.charges(for: s, in: d("2026-10-01")...d("2027-03-01")).map(\.date)
        == [d("2026-10-15"), d("2026-11-15"), d("2026-12-15")])
    #expect(BillingSchedule.nextCharge(for: s, onOrAfter: d("2026-12-16")) == nil)
}

@Test func inactiveHasNoCharges() {
    var s = sub("2026-10-15")
    s.isActive = false
    #expect(BillingSchedule.nextCharge(for: s, onOrAfter: d("2026-10-01")) == nil)
    #expect(BillingSchedule.charges(for: s, in: d("2026-10-01")...d("2027-03-01")).isEmpty)
}

@Test func amountFollowsHistory() {
    var s = sub("2026-01-01")
    s.changePrice(to: rub(150), effectiveFrom: d("2026-06-01"))
    let charges = BillingSchedule.charges(for: s, in: d("2026-05-01")...d("2026-06-01"))
    #expect(charges.map(\.amount) == [rub(100), rub(150)])
}

@Test func oldAnchorJumpsDirectly() {
    let daily = sub("2015-03-10", BillingCycle(1, .day))
    #expect(BillingSchedule.nextCharge(for: daily, onOrAfter: d("2026-10-20"))?.date == d("2026-10-20"))
    let monthly = sub("2015-01-31")
    #expect(BillingSchedule.nextCharge(for: monthly, onOrAfter: d("2026-10-20"))?.date == d("2026-10-31"))

    let a = BillingSchedule.firstIndex(anchor: d("2015-03-10"), cycle: BillingCycle(1, .day), onOrAfter: d("2026-10-20"))
    #expect(a.index == 4242 && a.steps <= 3)
    let b = BillingSchedule.firstIndex(anchor: d("2015-01-31"), cycle: .monthly, onOrAfter: d("2026-10-20"))
    #expect(b.index == 141 && b.steps <= 3)
}

@Test func terminatesAtLocalDateMax() {
    let s = sub("2999-12-01", BillingCycle(1, .day))
    let all = BillingSchedule.charges(for: s, in: d("2999-12-01")...LocalDate.max)
    #expect(all.count == 31 && all.last?.date == LocalDate.max)
    #expect(BillingSchedule.nextCharge(for: s, onOrAfter: .max)?.date == LocalDate.max)
}
