import Foundation

public enum UpcomingGroup: String, CaseIterable, Sendable { case todayTomorrow, thisWeek, thisMonth, later }

public struct UpcomingSection: Equatable, Sendable {
    public var group: UpcomingGroup
    public var charges: [Charge]

    public init(group: UpcomingGroup, charges: [Charge]) {
        self.group = group
        self.charges = charges
    }
}

public enum Upcoming {
    public static let horizonDays = 60

    public static func sections(library: Library, today: LocalDate, calendar: Calendar) -> [UpcomingSection] {
        let live = library.subscriptions.filter { $0.isLive(today: today) }
        let names = Dictionary(live.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let range = today...today.adding(days: horizonDays)
        let charges = live.flatMap { BillingSchedule.charges(for: $0, in: range) }.sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            let order = (names[a.subscriptionID] ?? "").localizedStandardCompare(names[b.subscriptionID] ?? "")
            if order != .orderedSame { return order == .orderedAscending }
            return a.subscriptionID.uuidString < b.subscriptionID.uuidString
        }

        let tomorrow = today.adding(days: 1)
        let weekEnd = endOfWeek(containing: today, calendar: calendar)
        let monthEnd = LocalDate(year: today.year, month: today.month,
                                 day: LocalDate.daysInMonth(year: today.year, month: today.month))!
        var buckets: [UpcomingGroup: [Charge]] = [:]
        for charge in charges {
            let group: UpcomingGroup =
                charge.date <= tomorrow ? .todayTomorrow
                : charge.date <= weekEnd ? .thisWeek
                : charge.date <= monthEnd ? .thisMonth : .later
            buckets[group, default: []].append(charge)
        }
        return UpcomingGroup.allCases.compactMap { group in
            buckets[group].map { UpcomingSection(group: group, charges: $0) }
        }
    }

    public static func daysToNearest(library: Library, today: LocalDate) -> Int? {
        library.subscriptions
            .filter { $0.isLive(today: today) }
            .compactMap { BillingSchedule.nextCharge(for: $0, onOrAfter: today)?.date }
            .min()
            .map { today.days(until: $0) }
    }

    public static func nextCharges(for s: Subscription, today: LocalDate, count: Int = 3) -> [Charge] {
        var result: [Charge] = []
        var day = today
        while result.count < count, let charge = BillingSchedule.nextCharge(for: s, onOrAfter: day) {
            result.append(charge)
            guard charge.date < .max else { break }
            day = charge.date.adding(days: 1)
        }
        return result
    }

    private static func endOfWeek(containing today: LocalDate, calendar: Calendar) -> LocalDate {
        let noon = today.date(hour: 12, minute: 0, calendar: calendar)
        let weekday = calendar.component(.weekday, from: noon)
        var untilNext = (calendar.firstWeekday - weekday + 7) % 7
        if untilNext == 0 { untilNext = 7 }
        return today.adding(days: untilNext - 1)
    }
}
