import Foundation
import Testing
@testable import SubusCore

private let today = d("2026-10-21")

private func sub(_ name: String = "X", price: Money = rub(100), cycle: BillingCycle = .monthly,
                 category: UUID? = nil, card: UUID? = nil, trialEnd: LocalDate? = nil) -> Subscription {
    var s = Subscription(name: name, price: price, cycle: cycle, startDate: d("2026-01-01"), trialEndDate: trialEnd)
    s.categoryID = category
    s.paymentMethodID = card
    return s
}

@Test func cycleKinds() {
    #expect(CycleKind(.monthly) == .monthly)
    #expect(CycleKind(.yearly) == .yearly)
    #expect(CycleKind(BillingCycle(3, .month)) == .other)
    #expect(CycleKind(BillingCycle(12, .month)) == .other)
}

@Test func emptyFilterMatchesAll() {
    let filter = YearFilter()
    #expect(filter.matches(sub(category: UUID()), today: today))
    #expect(filter.matches(sub(cycle: .yearly), today: today))
    #expect(filter.matches(sub(trialEnd: today.adding(days: 3)), today: today))
    #expect(filter.matches(sub(category: nil), today: today))
}

@Test func categoryAndNoCategory() {
    let work = UUID()
    let a = sub(category: work), b = sub(category: nil)
    var filter = YearFilter()
    filter.categoryIDs = [work]
    #expect(filter.matches(a, today: today) && !filter.matches(b, today: today))
    filter.categoryIDs = [nil]
    #expect(!filter.matches(a, today: today) && filter.matches(b, today: today))
    filter.categoryIDs = [work, nil]
    #expect(filter.matches(a, today: today) && filter.matches(b, today: today))
}

@Test func paymentMethodAndNoCard() {
    let card = UUID()
    let a = sub(card: card), b = sub(card: nil)
    var filter = YearFilter()
    filter.paymentMethodIDs = [card]
    #expect(filter.matches(a, today: today) && !filter.matches(b, today: today))
    filter.paymentMethodIDs = [nil]
    #expect(!filter.matches(a, today: today) && filter.matches(b, today: today))
    filter.paymentMethodIDs = [card, nil]
    #expect(filter.matches(a, today: today) && filter.matches(b, today: today))
}

@Test func currencyUsesCurrentPrice() {
    var s = sub(price: rub(100))
    s.changePrice(to: rub(100), effectiveFrom: d("2026-01-01"))
    s.changePrice(to: usd(10), effectiveFrom: d("2027-03-01"))
    #expect(s.price.currency == "USD")
    var filter = YearFilter()
    filter.currencies = ["RUB"]
    #expect(filter.matches(s, today: today))
    filter.currencies = ["USD"]
    #expect(!filter.matches(s, today: today))
}

@Test func trialsExcluded() {
    var filter = YearFilter()
    filter.includeTrials = false
    #expect(!filter.matches(sub(trialEnd: today.adding(days: 3)), today: today))
    #expect(filter.matches(sub(trialEnd: today), today: today))
}

@Test func queryIgnoresCaseAndDiacritics() {
    var filter = YearFilter()
    filter.query = "яндекс"
    #expect(filter.matches(sub("Яндекс Плюс"), today: today))
    filter.query = "ICLOUD"
    #expect(filter.matches(sub("iCloud+"), today: today))
    filter.query = "елка"
    #expect(filter.matches(sub("Ёлка"), today: today))
    filter.query = "  "
    #expect(filter.matches(sub("Ёлка"), today: today))
    filter.query = "netflix"
    #expect(!filter.matches(sub("Ёлка"), today: today))
}

@Test func conditionsCombine() {
    let work = UUID()
    let both = sub(price: rub(1), category: work), wrongCurrency = sub(price: usd(1), category: work), wrongCategory = sub(price: rub(1))
    var filter = YearFilter()
    filter.categoryIDs = [work]
    filter.currencies = ["RUB"]
    #expect(filter.matches(both, today: today))
    #expect(!filter.matches(wrongCurrency, today: today))
    #expect(!filter.matches(wrongCategory, today: today))
}

@Test func prunedDropsDeletedIDs() {
    let kept = Category(name: "Kept", colorIndex: 0)
    let library = Library(categories: [kept])
    var filter = YearFilter()
    filter.categoryIDs = [UUID(), kept.id, nil]
    filter.paymentMethodIDs = [UUID()]
    let pruned = filter.pruned(to: library)
    #expect(pruned.categoryIDs == [kept.id, nil])
    #expect(pruned.paymentMethodIDs == [])
}

@Test func activeCountCountsMenuConditions() {
    #expect(YearFilter().activeCount == 0)
    var filter = YearFilter()
    filter.paymentMethodIDs = [UUID()]
    filter.cycles = [.yearly]
    filter.includeTrials = false
    #expect(filter.activeCount == 3)
    filter.categoryIDs = [UUID()]
    filter.query = "x"
    #expect(filter.activeCount == 3)
    filter.showInactive = true
    filter.currencies = ["USD"]
    #expect(filter.activeCount == 5)
}
