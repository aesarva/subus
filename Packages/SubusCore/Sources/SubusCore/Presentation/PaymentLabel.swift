import Foundation

/// Splits a payment-method label into the part that may be truncated and the card tail that must stay whole.
public enum PaymentLabel {
    /// The tail is the last "••" token plus at most one adjacent ASCII-digit token ("•• 4242", "••1234"), or a
    /// trailing token of 4–8 ASCII digits. Text after the tail is dropped (the date line has no room for it).
    /// A label that is only a tail, or has none, comes back whole with a nil tail.
    public static func split(_ label: String) -> (head: String, tail: String?) {
        let tokens = label.split(whereSeparator: \.isWhitespace).map(String.init)
        var start: Int?
        var end = 0
        if let i = tokens.lastIndex(where: { $0.hasPrefix("••") }) {
            start = i
            end = i + 1
            if tokens[i].allSatisfy({ $0 == "•" }), i + 1 < tokens.count, isDigits(tokens[i + 1]) { end = i + 2 }
        } else if tokens.count > 1, let last = tokens.last, (4...8).contains(last.count), isDigits(last) {
            start = tokens.count - 1
            end = tokens.count
        }
        guard let start, start > 0 else { return (label, nil) }
        return (tokens[..<start].joined(separator: " "), tokens[start..<end].joined(separator: " "))
    }

    private static func isDigits(_ token: String) -> Bool {
        !token.isEmpty && token.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
