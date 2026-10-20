import Foundation

/// Decimal в JSON — строкой ("1199.99"); при чтении допускается и число.
@propertyWrapper
public struct DecimalString: Hashable, Codable, Sendable {
    public var wrappedValue: Decimal

    public init(wrappedValue: Decimal) { self.wrappedValue = wrappedValue }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            guard let v = Decimal(string: s, locale: Locale(identifier: "en_US_POSIX")) else {
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid decimal: \(s)")
            }
            wrappedValue = v
        } else {
            wrappedValue = try c.decode(Decimal.self)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode("\(wrappedValue)")
    }
}

public struct Money: Hashable, Codable, Sendable {
    public var amount: Decimal
    public var currency: String { didSet { currency = currency.uppercased() } }

    public init(_ amount: Decimal, _ currency: String) {
        self.amount = amount
        self.currency = currency.uppercased()
    }

    private enum CodingKeys: String, CodingKey { case amount, currency }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try c.decode(DecimalString.self, forKey: .amount).wrappedValue,
                  try c.decode(String.self, forKey: .currency))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(DecimalString(wrappedValue: amount), forKey: .amount)
        try c.encode(currency, forKey: .currency)
    }
}
