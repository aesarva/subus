import Foundation

/// Списания одной подписки за 12 месяцев вперёд, сумма в базовой валюте и ближайшее списание.
public struct SubscriptionYear: Equatable, Sendable {
    public let charges: [YearCharge]
    public let total: YearMoney
    /// Ближайшее списание от сегодня, даже за пределами периода; `nil` у неактивных и завершённых.
    public let next: Charge?
    /// Первые фактические списания по новой цене (цена отличается от предыдущего списания периода).
    public let firstAtNewPrice: Set<LocalDate>

    public static func build(_ s: Subscription, today: LocalDate, baseCurrency: String,
                             converter: CurrencyConverter) -> SubscriptionYear {
        guard s.isLive(today: today) else {
            return SubscriptionYear(charges: [], total: YearMoney(currency: baseCurrency), next: nil, firstAtNewPrice: [])
        }
        let isTrial = YearFilter.isTrial(s, today: today)
        let raw = BillingSchedule.charges(for: s, in: YearPlan.range(today: today))
        let charges = raw.map {
            YearCharge(charge: $0, converted: converter.convert($0.amount, to: baseCurrency), isTrialFuturePrice: isTrial)
        }
        var total = YearMoney(currency: baseCurrency)
        for c in charges { total.add(c.converted) }
        // Первое списание периода сравнивается с предыдущим фактическим по расписанию; у самого первого списания его нет.
        var changed = zip(raw, raw.dropFirst()).filter { $0.amount != $1.amount }.map { $1.date }
        if let first = raw.first {
            let k = BillingSchedule.firstIndex(anchor: s.anchor, cycle: s.cycle, onOrAfter: first.date).index
            if k > 0, s.price(on: BillingSchedule.chargeDate(anchor: s.anchor, cycle: s.cycle, index: k - 1)) != first.amount {
                changed.append(first.date)
            }
        }
        return SubscriptionYear(charges: charges, total: total,
                                next: BillingSchedule.nextCharge(for: s, onOrAfter: today),
                                firstAtNewPrice: Set(changed))
    }

    /// Изменение цены между соседними записями истории; `percent` только для одной валюты и ненулевой прежней цены.
    public struct PriceStep: Equatable, Sendable {
        public let from: Money
        public let to: Money
        public let on: LocalDate
        public let percent: Decimal?
    }

    public static func priceSteps(_ s: Subscription) -> [PriceStep] {
        zip(s.priceHistory, s.priceHistory.dropFirst()).map { a, b in
            let percent: Decimal? = a.price.currency == b.price.currency && a.price.amount > 0
                ? (b.price.amount - a.price.amount) / a.price.amount * 100 : nil
            return PriceStep(from: a.price, to: b.price, on: b.effectiveFrom, percent: percent)
        }
    }
}

public typealias PriceStep = SubscriptionYear.PriceStep

public enum YearSort: String, CaseIterable, Sendable {
    case total, nextDate, name
}

public struct YearSubscriptionRow: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let subscription: Subscription
    public let year: SubscriptionYear
    public let isLive: Bool
}

extension YearPlan {
    /// Список «Все подписки»: прошедшие фильтр; неактивные и завершённые — только при `showInactive`.
    public static func subscriptionRows(library: Library, filter: YearFilter, today: LocalDate, baseCurrency: String,
                                        converter: CurrencyConverter, sort: YearSort) -> [YearSubscriptionRow] {
        let rows = library.subscriptions
            .filter { filter.matches($0, today: today) }
            .map { YearSubscriptionRow(id: $0.id, subscription: $0,
                                       year: .build($0, today: today, baseCurrency: baseCurrency, converter: converter),
                                       isLive: $0.isLive(today: today)) }
            .filter { $0.isLive || filter.showInactive }
        func tie(_ a: YearSubscriptionRow, _ b: YearSubscriptionRow) -> Bool { byName(a.subscription, b.subscription) }
        return rows.sorted { a, b in
            switch sort {
            case .name:
                return tie(a, b)
            case .total:
                switch (a.year.total.display, b.year.total.display) {
                case (.unavailable, .unavailable): return tie(a, b)
                case (.unavailable, _): return false
                case (_, .unavailable): return true
                default:
                    if a.year.total.amount.amount != b.year.total.amount.amount {
                        return a.year.total.amount.amount > b.year.total.amount.amount
                    }
                    return tie(a, b)
                }
            case .nextDate:
                switch (a.year.next?.date, b.year.next?.date) {
                case let (x?, y?): return x != y ? x < y : tie(a, b)
                case (nil, nil): return tie(a, b)
                case (_?, nil): return true
                case (nil, _?): return false
                }
            }
        }
    }
}
