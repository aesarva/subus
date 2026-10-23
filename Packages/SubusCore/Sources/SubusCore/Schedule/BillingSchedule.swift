import Foundation

public struct Charge: Hashable, Sendable {
    public let subscriptionID: UUID
    public let date: LocalDate
    public let amount: Money
    public let isFirstAfterTrial: Bool

    public init(subscriptionID: UUID, date: LocalDate, amount: Money, isFirstAfterTrial: Bool) {
        self.subscriptionID = subscriptionID
        self.date = date
        self.amount = amount
        self.isFirstAfterTrial = isFirstAfterTrial
    }
}

public enum BillingSchedule {
    public static func chargeDate(anchor: LocalDate, cycle: BillingCycle, index n: Int) -> LocalDate {
        let k = n * cycle.count
        switch cycle.unit {
        case .day: return anchor.adding(days: k)
        case .week: return anchor.adding(days: k * 7)
        case .month: return anchor.adding(months: k)
        case .year: return anchor.adding(months: k * 12)
        }
    }

    public static func nextCharge(for s: Subscription, onOrAfter day: LocalDate) -> Charge? {
        guard s.isActive else { return nil }
        let n = firstIndex(anchor: s.anchor, cycle: s.cycle, onOrAfter: day).index
        return charge(for: s, index: n)
    }

    public static func charges(for s: Subscription, in range: ClosedRange<LocalDate>) -> [Charge] {
        guard s.isActive else { return [] }
        var result: [Charge] = []
        var n = firstIndex(anchor: s.anchor, cycle: s.cycle, onOrAfter: range.lowerBound).index
        var previous: LocalDate?
        while let c = charge(for: s, index: n), c.date <= range.upperBound, c.date != previous {
            result.append(c)
            previous = c.date
            n += 1
        }
        return result
    }

    static func firstIndex(anchor: LocalDate, cycle: BillingCycle, onOrAfter day: LocalDate) -> (index: Int, steps: Int) {
        var n: Int
        switch cycle.unit {
        case .day, .week:
            let period = cycle.count * (cycle.unit == .day ? 1 : 7)
            let days = anchor.days(until: day)
            n = days <= 0 ? 0 : (days + period - 1) / period
        case .month, .year:
            let period = cycle.count * (cycle.unit == .month ? 1 : 12)
            let months = (day.year - anchor.year) * 12 + (day.month - anchor.month)
            n = max(0, months / period)
        }
        var steps = 1
        if chargeDate(anchor: anchor, cycle: cycle, index: n) < day {
            while chargeDate(anchor: anchor, cycle: cycle, index: n) < day {
                n += 1
                steps += 1
                if chargeDate(anchor: anchor, cycle: cycle, index: n) == .max { break }
            }
        } else {
            while n > 0 {
                steps += 1
                if chargeDate(anchor: anchor, cycle: cycle, index: n - 1) < day { break }
                n -= 1
            }
        }
        return (n, steps)
    }

    private static func charge(for s: Subscription, index n: Int) -> Charge? {
        let date = chargeDate(anchor: s.anchor, cycle: s.cycle, index: n)
        if let end = s.endDate, date > end { return nil }
        return Charge(subscriptionID: s.id, date: date, amount: s.price(on: date),
                      isFirstAfterTrial: s.trialEndDate != nil && date == s.trialEndDate)
    }
}
