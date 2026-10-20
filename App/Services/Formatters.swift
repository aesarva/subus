import Foundation
import SubusCore

enum Formatters {
    static func money(_ m: Money) -> String {
        var whole = m.amount, source = m.amount
        NSDecimalRound(&whole, &source, 0, .plain)
        let style = Decimal.FormatStyle.Currency(code: m.currency, locale: .current)
        return m.amount.formatted(whole == m.amount ? style.precision(.fractionLength(0)) : style)
    }

    static func relativeDays(_ n: Int) -> String {
        switch n {
        case 0: String(localized: "today")
        case 1: String(localized: "tomorrow")
        default: String(localized: "in \(n) days")
        }
    }

    static func shortDate(_ d: LocalDate) -> String {
        let calendar = Calendar.subus()
        let date = d.date(hour: 12, minute: 0, calendar: calendar)
        let style = Date.FormatStyle(locale: .current, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).day().month(.abbreviated)
        return date.formatted(style)
    }

    /// Totals: whole units once the amount reaches 100, so the header stays a glance.
    static func total(_ m: Money) -> String {
        guard abs(m.amount) >= 100 else { return money(m) }
        return m.amount.formatted(Decimal.FormatStyle.Currency(code: m.currency, locale: .current).precision(.fractionLength(0)))
    }

    /// "20 Oct"
    static func dayMonth(_ d: LocalDate) -> String {
        let calendar = Calendar.subus()
        let style = Date.FormatStyle(locale: .current, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        return d.date(hour: 12, minute: 0, calendar: calendar).formatted(style)
    }

    /// "OCT" — a month label on the overview line.
    static func monthAbbreviation(_ d: LocalDate) -> String {
        let calendar = Calendar.subus()
        let style = Date.FormatStyle(locale: .current, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated)
        let text = d.date(hour: 12, minute: 0, calendar: calendar).formatted(style)
        return text.trimmingCharacters(in: CharacterSet(charactersIn: ".")).uppercased(with: .current)
    }

    static func counter(_ days: Int) -> String {
        String(localized: "\(days)d")
    }

    static func cycle(_ c: BillingCycle) -> String {
        let n = c.count
        switch (c.unit, n) {
        case (.day, 1): return String(localized: "day")
        case (.week, 1): return String(localized: "week")
        case (.month, 1): return String(localized: "month")
        case (.year, 1): return String(localized: "year")
        case (.day, _): return String(localized: "\(n) days")
        case (.week, _): return String(localized: "\(n) weeks")
        case (.month, _): return String(localized: "\(n) months")
        case (.year, _): return String(localized: "\(n) years")
        }
    }

    /// "RUB 399 / month", "$35.88 / year".
    static func perCycle(_ m: Money, _ c: BillingCycle) -> String {
        String(localized: "\(money(m)) / \(cycle(c))")
    }

    /// The cycle as VoiceOver reads it after an amount: "per month", "every 3 months".
    static func spokenCycle(_ c: BillingCycle) -> String {
        let n = c.count
        switch (c.unit, n) {
        case (.day, 1): return String(localized: "per day")
        case (.week, 1): return String(localized: "per week")
        case (.month, 1): return String(localized: "per month")
        case (.year, 1): return String(localized: "per year")
        case (.day, _): return String(localized: "every \(n) days")
        case (.week, _): return String(localized: "every \(n) weeks")
        case (.month, _): return String(localized: "every \(n) months")
        case (.year, _): return String(localized: "every \(n) years")
        }
    }

    /// "Nov 11", with the year when it is not this year's: "Apr 11, 2025".
    static func date(_ d: LocalDate, today: LocalDate) -> String {
        let calendar = Calendar.subus()
        var style = Date.FormatStyle(locale: .current, calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        if d.year != today.year { style = style.year() }
        return d.date(hour: 12, minute: 0, calendar: calendar).formatted(style)
    }

    /// "Wed, Nov 11", with the year when it is not this year's.
    static func shortDate(_ d: LocalDate, today: LocalDate) -> String {
        guard d.year != today.year else { return shortDate(d) }
        let calendar = Calendar.subus()
        let style = Date.FormatStyle(locale: .current, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.abbreviated).day().month(.abbreviated).year()
        return d.date(hour: 12, minute: 0, calendar: calendar).formatted(style)
    }
}
