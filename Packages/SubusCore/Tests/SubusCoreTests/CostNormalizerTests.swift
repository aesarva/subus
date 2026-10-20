import Foundation
import Testing
@testable import SubusCore

@Test func monthlyFromYearly() {
    #expect(CostNormalizer.monthly(rub(1200), cycle: .yearly) == rub(100))
}

@Test func monthlyFromMultiMonth() {
    #expect(CostNormalizer.monthly(rub(900), cycle: BillingCycle(3, .month)) == rub(300))
}

@Test func monthlyFromWeekAndDay() {
    #expect(CostNormalizer.monthly(usd(10), cycle: BillingCycle(1, .week)).amount.rounded(2) == Decimal(string: "43.33")!)
    #expect(CostNormalizer.monthly(usd(1), cycle: BillingCycle(1, .day)).amount.rounded(2) == Decimal(string: "30.42")!)
}

@Test func yearlyFromMonthly() {
    #expect(CostNormalizer.yearly(rub(100), cycle: .monthly) == rub(1200))
}

@Test func normalizationKeepsCurrency() {
    #expect(CostNormalizer.monthly(eur(5), cycle: .monthly).currency == "EUR")
    #expect(CostNormalizer.yearly(eur(5), cycle: .monthly).currency == "EUR")
}
