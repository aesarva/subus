import Foundation

/// Сумма списаний в базовой валюте; списания без курса в сумму не входят, но считаются.
public struct YearMoney: Equatable, Sendable {
    public var amount: Money
    public var convertedCount = 0
    public var unconvertedCount = 0

    public enum Display: Equatable, Sendable {
        case zero, amount(Money), partial(Money, missing: Int), unavailable
    }

    public init(currency: String) { amount = Money(0, currency) }

    public var display: Display {
        if convertedCount + unconvertedCount == 0 { return .zero }
        if convertedCount == 0 { return .unavailable }
        return unconvertedCount > 0 ? .partial(amount, missing: unconvertedCount) : .amount(amount)
    }

    mutating func add(_ converted: Money?) {
        if let converted {
            amount.amount += converted.amount
            convertedCount += 1
        } else {
            unconvertedCount += 1
        }
    }
}

public struct YearCharge: Equatable, Sendable {
    public let charge: Charge
    /// В базовой валюте; `nil`, если для валюты списания нет курса.
    public let converted: Money?
    /// Подписка ещё на пробном периоде: цена списания — будущая.
    public let isTrialFuturePrice: Bool
}

public struct MonthKey: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int

    public init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    public init(_ date: LocalDate) { self.init(year: date.year, month: date.month) }

    public static func < (a: MonthKey, b: MonthKey) -> Bool { (a.year, a.month) < (b.year, b.month) }
}

/// Неделя или месяц плана; `start`/`end` обрезаны по периоду плана, `id` — первый день полной недели/месяца.
public struct YearPeriod: Equatable, Sendable, Identifiable {
    public let id: LocalDate
    public let start: LocalDate
    public let end: LocalDate
    public let monthKey: MonthKey
    public let isPartial: Bool
    public let charges: [YearCharge]
    public let count: Int
    public let total: YearMoney
    public let level: Int
}

/// План списаний на 12 месяцев вперёд: недели и месяцы со списаниями, суммами и ступенью тона.
public struct YearPlan: Equatable, Sendable {
    public static let weekLevels = [1, 2, 3, 4]
    public static let monthLevels = [1, 4, 7, 10]

    public let range: ClosedRange<LocalDate>
    public let charges: [YearCharge]
    public let weeks: [YearPeriod]
    public let months: [YearPeriod]
    public let total: YearMoney
    /// Подписки, у которых хотя бы одно списание без курса, по имени.
    public let excludedSubscriptionIDs: [UUID]
    public let trialSubscriptionIDs: [UUID]
    /// Прошли фильтр, в том числе неактивные и без списаний в периоде.
    public let matchedSubscriptionIDs: [UUID]

    /// `today ... today + 12 месяцев − 1 день`, границы включительно.
    public static func range(today: LocalDate) -> ClosedRange<LocalDate> {
        today...today.adding(months: 12).adding(days: -1)
    }

    /// Нижние границы ступеней 1…4; результат 0 — «нет списаний».
    public static func level(count: Int, thresholds: [Int]) -> Int {
        thresholds.filter { count >= $0 }.count
    }

    public static func build(library: Library, filter: YearFilter, today: LocalDate, calendar: Calendar,
                             baseCurrency: String, converter: CurrencyConverter) -> YearPlan {
        let range = range(today: today)
        let matched = library.subscriptions.filter { filter.matches($0, today: today) }
        let live = matched.filter { $0.isLive(today: today) }
        let names = Dictionary(live.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let trials = Set(live.filter { YearFilter.isTrial($0, today: today) }.map(\.id))

        let charges = live.flatMap { BillingSchedule.charges(for: $0, in: range) }.sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            let order = (names[a.subscriptionID] ?? "").localizedStandardCompare(names[b.subscriptionID] ?? "")
            if order != .orderedSame { return order == .orderedAscending }
            return a.subscriptionID.uuidString < b.subscriptionID.uuidString
        }.map { c in
            YearCharge(charge: c, converted: converter.convert(c.amount, to: baseCurrency),
                       isTrialFuturePrice: trials.contains(c.subscriptionID))
        }

        var total = YearMoney(currency: baseCurrency)
        for c in charges { total.add(c.converted) }
        let excluded = Set(charges.filter { $0.converted == nil }.map(\.charge.subscriptionID))

        func period(id: LocalDate, fullEnd: LocalDate, monthKey: MonthKey, thresholds: [Int]) -> YearPeriod {
            let start = max(id, range.lowerBound), end = min(fullEnd, range.upperBound)
            let inside = charges.filter { $0.charge.date >= start && $0.charge.date <= end }
            var sum = YearMoney(currency: baseCurrency)
            for c in inside { sum.add(c.converted) }
            return YearPeriod(id: id, start: start, end: end, monthKey: monthKey, isPartial: start != id || end != fullEnd,
                              charges: inside, count: inside.count, total: sum,
                              level: level(count: inside.count, thresholds: thresholds))
        }

        var weeks: [YearPeriod] = []
        let back = (range.lowerBound.weekday(in: calendar) - calendar.firstWeekday + 7) % 7
        var weekStart = range.lowerBound.adding(days: -back)
        while weekStart <= range.upperBound {
            weeks.append(period(id: weekStart, fullEnd: weekStart.adding(days: 6),
                                monthKey: MonthKey(weekStart.adding(days: 3)), thresholds: weekLevels))
            weekStart = weekStart.adding(days: 7)
        }

        var months: [YearPeriod] = []
        var key = MonthKey(range.lowerBound)
        while key <= MonthKey(range.upperBound) {
            let first = LocalDate(year: key.year, month: key.month, day: 1)!
            let last = LocalDate(year: key.year, month: key.month,
                                 day: LocalDate.daysInMonth(year: key.year, month: key.month))!
            months.append(period(id: first, fullEnd: last, monthKey: key, thresholds: monthLevels))
            key = key.month == 12 ? MonthKey(year: key.year + 1, month: 1) : MonthKey(year: key.year, month: key.month + 1)
        }

        return YearPlan(range: range, charges: charges, weeks: weeks, months: months, total: total,
                        excludedSubscriptionIDs: live.filter { excluded.contains($0.id) }.sorted(by: byName).map(\.id),
                        trialSubscriptionIDs: matched.map(\.id).filter(trials.contains),
                        matchedSubscriptionIDs: matched.map(\.id))
    }

    /// Порядок «по имени, затем по id» для равных ключей сортировки.
    static func byName(_ a: Subscription, _ b: Subscription) -> Bool {
        let order = a.name.localizedStandardCompare(b.name)
        if order != .orderedSame { return order == .orderedAscending }
        return a.id.uuidString < b.id.uuidString
    }

    /// Столбцы недельной сетки: подряд идущие недели одного месяца.
    public func weekColumns() -> [(month: MonthKey, weeks: [YearPeriod])] {
        var columns: [(month: MonthKey, weeks: [YearPeriod])] = []
        for week in weeks {
            if let last = columns.last, last.month == week.monthKey {
                columns[columns.count - 1].weeks.append(week)
            } else {
                columns.append((week.monthKey, [week]))
            }
        }
        return columns
    }
}

extension LocalDate {
    /// 1 = воскресенье, как в `Calendar.component(.weekday, ...)`.
    func weekday(in calendar: Calendar) -> Int {
        calendar.component(.weekday, from: date(hour: 12, minute: 0, calendar: calendar))
    }
}
