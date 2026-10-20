import Foundation

public struct RateTable: Equatable, Codable, Sendable {
    public var date: LocalDate
    /// Рублей за 1 единицу валюты; "RUB" = 1. В JSON значения — строки.
    public var rubPerUnit: [String: Decimal]
    public var fetchedAt: Date

    public init(date: LocalDate, rubPerUnit: [String: Decimal], fetchedAt: Date) {
        self.date = date
        self.rubPerUnit = rubPerUnit
        self.fetchedAt = fetchedAt
    }

    private enum CodingKeys: String, CodingKey { case date, rubPerUnit, fetchedAt }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(LocalDate.self, forKey: .date)
        rubPerUnit = try c.decode([String: DecimalString].self, forKey: .rubPerUnit).mapValues(\.wrappedValue)
        fetchedAt = try c.decode(Date.self, forKey: .fetchedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(rubPerUnit.mapValues { DecimalString(wrappedValue: $0) }, forKey: .rubPerUnit)
        try c.encode(fetchedAt, forKey: .fetchedAt)
    }
}

public struct CurrencyConverter: Sendable {
    private let table: RateTable?

    public init(table: RateTable?) { self.table = table }

    public func convert(_ m: Money, to currency: String) -> Money? {
        let target = currency.uppercased()
        if m.currency == target { return m }
        guard let rates = table?.rubPerUnit, let from = rates[m.currency], let to = rates[target], to > 0 else { return nil }
        return Money(m.amount * from / to, target)
    }
}

public enum RateRefreshPolicy {
    public static let maxAge: TimeInterval = 24 * 3600

    public static func needsRefresh(cached: RateTable?, now: Date) -> Bool {
        guard let cached else { return true }
        return now.timeIntervalSince(cached.fetchedAt) > maxAge
    }
}
