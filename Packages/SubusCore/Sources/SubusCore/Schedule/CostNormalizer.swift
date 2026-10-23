import Foundation

public enum CostNormalizer {
    public static func monthly(_ price: Money, cycle: BillingCycle) -> Money {
        let p = price.amount
        let n = Decimal(cycle.count)
        let amount: Decimal
        switch cycle.unit {
        case .month: amount = p / n
        case .year: amount = p / (12 * n)
        case .week: amount = p * 52 / (12 * n)
        case .day: amount = p * 365 / (12 * n)
        }
        return Money(amount, price.currency)
    }

    public static func yearly(_ price: Money, cycle: BillingCycle) -> Money {
        let m = monthly(price, cycle: cycle)
        return Money(m.amount * 12, m.currency)
    }
}

extension Decimal {
    public func rounded(_ scale: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, .plain)
        return result
    }
}
