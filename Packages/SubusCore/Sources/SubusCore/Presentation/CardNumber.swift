import Foundation

public enum CardNetwork: String, Sendable, CaseIterable {
    case visa, mastercard, mir, amex, unionPay, jcb

    public func displayName(locale: Locale) -> String {
        switch self {
        case .visa: "Visa"
        case .mastercard: "Mastercard"
        case .mir: locale.language.languageCode == .russian ? "Мир" : "Mir"
        case .amex: "Amex"
        case .unionPay: "UnionPay"
        case .jcb: "JCB"
        }
    }
}

/// Reads a full card number down to what Subus keeps: the last four digits and the network.
public enum CardNumber {
    /// Last four digits and network of a full number (12–19 digits, spaces and dashes ignored);
    /// nil when the text is not a full number.
    public static func summary(of text: String) -> (last4: String, network: CardNetwork?)? {
        let separators: Set<Character> = [" ", "-", "\u{00A0}"]
        let digits = String(text.filter { !separators.contains($0) })
        guard (12...19).contains(digits.count), digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return (String(digits.suffix(4)), network(ofDigits: digits))
    }

    /// The network by issuer prefix; Mir is checked before Mastercard's 2221–2720 range.
    public static func network(ofDigits digits: String) -> CardNetwork? {
        func prefix(_ n: Int) -> Int? { digits.count >= n ? Int(digits.prefix(n)) : nil }
        if let p = prefix(4), (2200...2204).contains(p) { return .mir }
        if let p = prefix(2), (51...55).contains(p) { return .mastercard }
        if let p = prefix(4), (2221...2720).contains(p) { return .mastercard }
        if digits.hasPrefix("4") { return .visa }
        if let p = prefix(2), p == 34 || p == 37 { return .amex }
        if prefix(2) == 62 { return .unionPay }
        if let p = prefix(4), (3528...3589).contains(p) { return .jcb }
        return nil
    }
}

/// What the card-number field holds: its visible text and what was read from it. Never a full number once parsed.
public struct CardFieldState: Equatable, Sendable {
    public var text: String
    public var last4: String?
    public var network: CardNetwork?

    public init(text: String = "", last4: String? = nil, network: CardNetwork? = nil) {
        self.text = text
        self.last4 = last4
        self.network = network
    }
}

/// The card-number field's logic. AutoFill and paste arrive as one large edit and are parsed at once;
/// typing is parsed only when editing ends, so it is never cut off at the 12th digit.
public enum CardFieldParser {
    public static func mask(_ last4: String) -> String { "•• " + last4 }

    public static func edited(_ old: CardFieldState, to newText: String) -> CardFieldState {
        if newText.count - old.text.count >= 8, let parsed = parsed(newText) { return parsed }
        if let digits = maskDigits(newText) {
            return CardFieldState(text: newText, last4: digits, network: digits == old.last4 ? old.network : nil)
        }
        if isFourDigits(newText) { return CardFieldState(text: newText, last4: newText) }
        return CardFieldState(text: newText)
    }

    public static func ended(_ state: CardFieldState) -> CardFieldState {
        parsed(state.text) ?? state
    }

    private static func parsed(_ text: String) -> CardFieldState? {
        CardNumber.summary(of: text).map { CardFieldState(text: mask($0.last4), last4: $0.last4, network: $0.network) }
    }

    /// The four digits of "•• 4242" or "••4242".
    private static func maskDigits(_ text: String) -> String? {
        guard text.hasPrefix("••") else { return nil }
        var rest = text.dropFirst(2)
        if rest.first == " " { rest = rest.dropFirst() }
        let digits = String(rest)
        return isFourDigits(digits) ? digits : nil
    }

    private static func isFourDigits(_ text: String) -> Bool {
        text.count == 4 && text.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
