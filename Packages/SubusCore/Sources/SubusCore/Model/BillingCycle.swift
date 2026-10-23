import Foundation

public struct BillingCycle: Hashable, Codable, Sendable {
    public enum Unit: String, Codable, CaseIterable, Sendable { case day, week, month, year }

    public static let maxCount = 999

    public var count: Int { didSet { count = Self.clamp(count) } }
    public var unit: Unit

    public init(_ count: Int, _ unit: Unit) {
        self.count = Self.clamp(count)
        self.unit = unit
    }

    public static let monthly = BillingCycle(1, .month)
    public static let yearly = BillingCycle(1, .year)

    private static func clamp(_ n: Int) -> Int { min(max(n, 1), maxCount) }

    private enum CodingKeys: String, CodingKey { case count, unit }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try c.decode(Int.self, forKey: .count), try c.decode(Unit.self, forKey: .unit))
    }
}
