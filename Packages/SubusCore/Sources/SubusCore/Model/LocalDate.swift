import Foundation

public struct LocalDate: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public static let minYear = 1900, maxYear = 2999
    public static let min = LocalDate(year: minYear, month: 1, day: 1)!
    public static let max = LocalDate(year: maxYear, month: 12, day: 31)!

    public let year: Int, month: Int, day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (Self.minYear...Self.maxYear).contains(year), (1...12).contains(month),
              (1...Self.daysInMonth(year: year, month: month)).contains(day) else { return nil }
        self.year = year; self.month = month; self.day = day
    }

    public init?(iso: String) {
        let parts = iso.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var iso: String {
        let y = String(year), m = String(month), d = String(day)
        return String(repeating: "0", count: 4 - y.count) + y + "-"
            + String(repeating: "0", count: 2 - m.count) + m + "-"
            + String(repeating: "0", count: 2 - d.count) + d
    }

    public var description: String { iso }

    public static func < (a: LocalDate, b: LocalDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let date = LocalDate(iso: s) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(s)"))
        }
        self = date
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso)
    }

    // MARK: Calendar arithmetic (gregorian, UTC)

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private var utcDate: Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public static func today(now: Date, calendar: Calendar) -> LocalDate {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return LocalDate(year: c.year!, month: c.month!, day: c.day!)!
    }

    public func date(hour: Int, minute: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    public func adding(days: Int) -> LocalDate {
        guard (-1_000_000...1_000_000).contains(days) else { return days < 0 ? .min : .max }
        guard let shifted = Self.utc.date(byAdding: .day, value: days, to: utcDate) else { return days < 0 ? .min : .max }
        return Self.from(shifted)
    }

    public func adding(months: Int) -> LocalDate {
        guard (-100_000...100_000).contains(months) else { return months < 0 ? .min : .max }
        let index = year * 12 + (month - 1) + months
        let y = Int((Double(index) / 12).rounded(.down)), m = index - y * 12 + 1
        guard y >= Self.minYear else { return .min }
        guard y <= Self.maxYear else { return .max }
        return LocalDate(year: y, month: m, day: Swift.min(day, Self.daysInMonth(year: y, month: m)))!
    }

    public func days(until other: LocalDate) -> Int {
        Self.utc.dateComponents([.day], from: utcDate, to: other.utcDate).day!
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    private static func from(_ date: Date) -> LocalDate {
        let c = utc.dateComponents([.year, .month, .day], from: date)
        let r = LocalDate(year: c.year!, month: c.month!, day: c.day!)
        return r ?? (c.year! < minYear ? .min : .max)
    }
}

extension Calendar {
    /// Календарь приложения: всегда григорианский, зона и первый день недели — из аргументов.
    public static func subus(timeZone: TimeZone = .current, locale: Locale = .current) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = locale
        return c
    }
}
