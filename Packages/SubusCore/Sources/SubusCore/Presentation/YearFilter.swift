import Foundation

/// Периодичность для фильтра: ежемесячная, ежегодная или любая другая.
public enum CycleKind: Hashable, Sendable, CaseIterable {
    case monthly, yearly, other

    public init(_ cycle: BillingCycle) {
        switch cycle {
        case BillingCycle(1, .month): self = .monthly
        case BillingCycle(1, .year): self = .yearly
        default: self = .other
        }
    }
}

/// Условия отбора подписок в окне «Год». Пустой набор означает «без ограничения»; `nil` в наборе — «без категории/карты».
public struct YearFilter: Equatable, Sendable {
    public var categoryIDs: Set<UUID?> = []
    public var paymentMethodIDs: Set<UUID?> = []
    public var cycles: Set<CycleKind> = []
    public var currencies: Set<String> = []
    public var includeTrials = true
    public var showInactive = false
    public var query = ""

    public init() {}

    public static func isTrial(_ s: Subscription, today: LocalDate) -> Bool {
        guard let end = s.trialEndDate else { return false }
        return end > today
    }

    /// Проверяет все условия, кроме `showInactive`.
    public func matches(_ s: Subscription, today: LocalDate) -> Bool {
        if !categoryIDs.isEmpty, !categoryIDs.contains(s.categoryID) { return false }
        if !paymentMethodIDs.isEmpty, !paymentMethodIDs.contains(s.paymentMethodID) { return false }
        if !cycles.isEmpty, !cycles.contains(CycleKind(s.cycle)) { return false }
        if !currencies.isEmpty, !currencies.contains(s.currentPrice(today: today).currency) { return false }
        if !includeTrials, Self.isTrial(s, today: today) { return false }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, !s.name.localizedStandardContains(text) { return false }
        return true
    }

    /// Убирает из фильтра удалённые категории и способы оплаты.
    public func pruned(to library: Library) -> YearFilter {
        var result = self
        let categories = Set(library.categories.map(\.id))
        let methods = Set(library.paymentMethods.map(\.id))
        result.categoryIDs = categoryIDs.filter { $0 == nil || categories.contains($0!) }
        result.paymentMethodIDs = paymentMethodIDs.filter { $0 == nil || methods.contains($0!) }
        return result
    }

    /// Число условий для бейджа меню «Фильтры»; категории (чипы) и поиск не считаются.
    public var activeCount: Int {
        [!paymentMethodIDs.isEmpty, !cycles.isEmpty, !currencies.isEmpty, !includeTrials, showInactive]
            .filter { $0 }.count
    }
}
