import Foundation

public struct Slice: Equatable, Sendable {
    /// nil — «без категории / без способа».
    public var id: UUID?
    public var monthly: Money

    public init(id: UUID?, monthly: Money) {
        self.id = id
        self.monthly = monthly
    }
}

public struct PriceIncrease: Equatable, Sendable {
    public var subscriptionID: UUID
    public var from: Money
    public var to: Money
    public var on: LocalDate

    public init(subscriptionID: UUID, from: Money, to: Money, on: LocalDate) {
        self.subscriptionID = subscriptionID
        self.from = from
        self.to = to
        self.on = on
    }
}

public struct SpendingSummary: Equatable, Sendable {
    public var monthly: Money
    public var yearly: Money
    /// Живые подписки, которые не удалось сконвертировать.
    public var excludedCount: Int
    /// Не nil, если хоть одна сумма была сконвертирована по курсу.
    public var ratesDate: LocalDate?
    /// Идущие пробные периоды, учтённые в итоге по будущей цене.
    public var trialCount: Int
    public var byCategory: [Slice]
    public var byPaymentMethod: [Slice]
}

public enum SummaryBuilder {
    public static func build(library: Library, baseCurrency: String, converter: CurrencyConverter,
                             ratesDate: LocalDate?, today: LocalDate) -> SpendingSummary {
        let base = baseCurrency.uppercased()
        var monthly = Decimal(0), yearly = Decimal(0)
        var excluded = 0, trials = 0, converted = false
        var categories: [UUID?: Decimal] = [:], methods: [UUID?: Decimal] = [:]

        for s in library.subscriptions where s.isLive(today: today) {
            let trialEnd = s.trialEndDate.flatMap { $0 > today ? $0 : nil }
            let inTrial = trialEnd != nil
            let price = s.price(on: trialEnd ?? today)
            guard let m = converter.convert(CostNormalizer.monthly(price, cycle: s.cycle), to: base),
                  let y = converter.convert(CostNormalizer.yearly(price, cycle: s.cycle), to: base) else {
                excluded += 1
                continue
            }
            if price.currency != base { converted = true }
            if inTrial { trials += 1 }
            monthly += m.amount
            yearly += y.amount
            categories[s.categoryID, default: 0] += m.amount
            methods[s.paymentMethodID, default: 0] += m.amount
        }

        return SpendingSummary(
            monthly: Money(monthly, base), yearly: Money(yearly, base),
            excludedCount: excluded, ratesDate: converted ? ratesDate : nil, trialCount: trials,
            byCategory: slices(categories, currency: base), byPaymentMethod: slices(methods, currency: base))
    }

    public static func priceIncreases(library: Library, today: LocalDate) -> [PriceIncrease] {
        let windowStart = today.adding(days: -365)
        var result: [PriceIncrease] = []
        for s in library.subscriptions where s.isLive(today: today) {
            let history = s.priceHistory.sorted { $0.effectiveFrom < $1.effectiveFrom }
            for (previous, change) in zip(history, history.dropFirst()) {
                guard change.effectiveFrom > windowStart, change.effectiveFrom <= today,
                      previous.price.currency == change.price.currency,
                      change.price.amount > previous.price.amount else { continue }
                result.append(PriceIncrease(subscriptionID: s.id, from: previous.price, to: change.price,
                                            on: change.effectiveFrom))
            }
        }
        return result.sorted {
            $0.on != $1.on ? $0.on > $1.on : $0.subscriptionID.uuidString < $1.subscriptionID.uuidString
        }
    }

    private static func slices(_ totals: [UUID?: Decimal], currency: String) -> [Slice] {
        totals
            .sorted {
                $0.value != $1.value ? $0.value > $1.value : ($0.key?.uuidString ?? "") < ($1.key?.uuidString ?? "")
            }
            .map { Slice(id: $0.key, monthly: Money($0.value, currency)) }
    }
}
