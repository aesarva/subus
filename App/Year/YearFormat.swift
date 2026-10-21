import Foundation
import SubusCore

/// The Year window's words for periods and sums: "Feb 8 – 14", "February 2027", "8,233 ₽ + 2 without a rate".
@MainActor
enum YearFormat {
    /// A period's sum as the whole window shows it: zero, the amount, "—" when nothing converts,
    /// the amount and "+ N without a rate" when part of it does not.
    static func money(_ m: YearMoney) -> String {
        switch m.display {
        case .zero: Formatters.total(m.amount)
        case .amount(let amount): Formatters.total(amount)
        case .partial(let amount, let missing): Formatters.total(amount) + " + " + withoutRate(missing)
        case .unavailable: "—"
        }
    }

    /// "2 without a rate".
    static func withoutRate(_ n: Int) -> String { String(localized: "\(n) without a rate") }

    /// A week's days, "February 8 – 14"; `short` abbreviates the month ("Feb 8 – 14").
    static func week(_ p: YearPeriod, short: Bool = false) -> String {
        let calendar = Calendar.subus()
        return intervalFormatter(short ? "MMMd" : "MMMMd")
            .string(from: p.start.date(hour: 12, minute: 0, calendar: calendar),
                    to: p.end.date(hour: 12, minute: 0, calendar: calendar))
    }

    /// "February 2027".
    static func month(_ p: YearPeriod) -> String {
        let calendar = Calendar.subus()
        let text = dateFormatter("LLLLy").string(from: p.id.date(hour: 12, minute: 0, calendar: calendar))
        return text.prefix(1).uppercased(with: .current) + text.dropFirst()
    }

    /// The period as the side pane titles it.
    static func title(_ p: YearPeriod, mode: YearMode) -> String {
        mode == .weeks ? week(p) : month(p)
    }

    /// "OCT", and for a January of another year than today's "JAN ’27".
    static func monthLabel(_ key: MonthKey, today: LocalDate) -> String {
        let first = LocalDate(year: key.year, month: key.month, day: 1)!
        let label = Formatters.monthAbbreviation(first)
        guard key.month == 1, key.year != today.year else { return label }
        return label + " ’" + String(format: "%02d", key.year % 100)
    }

    /// The word of "%lld charges" without its number — "charges", «списаний» — for a tile that sets the number
    /// apart. The catalog refuses a plural that leaves the number out, so the number is cut from the full phrase.
    static func chargesWord(_ n: Int) -> String {
        String(localized: "\(n) charges").replacingOccurrences(of: "\(n)", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// "2 charges · 8,233 ₽"
    static func countAndSum(_ p: YearPeriod) -> String {
        String(localized: "\(p.count) charges") + " · " + money(p.total)
    }

    /// The cell's tooltip: "Feb 8 – 14 · 2 charges · 8,233 ₽ · 1 without a rate".
    static func tooltip(_ p: YearPeriod, mode: YearMode) -> String {
        var parts = [mode == .weeks ? week(p, short: true) : month(p), String(localized: "\(p.count) charges")]
        switch p.total.display {
        case .zero, .amount, .unavailable: parts.append(money(p.total))
        case .partial(let amount, let missing): parts += [Formatters.total(amount), withoutRate(missing)]
        }
        return parts.joined(separator: " · ")
    }

    /// What VoiceOver reads for a cell: "Week February 8 – 14: 2 charges, 8,233 ₽".
    static func spoken(_ p: YearPeriod, mode: YearMode) -> String {
        let name = mode == .weeks ? String(localized: "Week") + " " + week(p) : String(localized: "Month") + " " + month(p)
        return name + ": " + String(localized: "\(p.count) charges") + ", " + money(p.total)
    }

    private static var intervalFormatters: [String: DateIntervalFormatter] = [:]
    private static var dateFormatters: [String: DateFormatter] = [:]

    /// Keyed by template, locale and time zone: a locale change brings a new formatter.
    private static func intervalFormatter(_ template: String) -> DateIntervalFormatter {
        let calendar = Calendar.subus()
        let key = template + "|" + Locale.current.identifier + "|" + calendar.timeZone.identifier
        if let cached = intervalFormatters[key] { return cached }
        let formatter = DateIntervalFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = template
        intervalFormatters[key] = formatter
        return formatter
    }

    private static func dateFormatter(_ template: String) -> DateFormatter {
        let calendar = Calendar.subus()
        let key = template + "|" + Locale.current.identifier + "|" + calendar.timeZone.identifier
        if let cached = dateFormatters[key] { return cached }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        dateFormatters[key] = formatter
        return formatter
    }
}
