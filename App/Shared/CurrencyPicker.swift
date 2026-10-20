import SwiftUI

/// Popular currencies first, then every other ISO code; a code outside the list stays selectable.
struct CurrencyPicker: View {
    @Binding var selection: String

    var body: some View {
        let (popular, others) = Self.currencies(including: selection)
        Picker("Currency", selection: $selection) {
            ForEach(popular, id: \.self) { Text(Self.label($0)).tag($0) }
            Divider()
            ForEach(others, id: \.self) { Text(Self.label($0)).tag($0) }
        }
        .labelsHidden()
        .frame(width: 200)
    }

    private static let popularCurrencies = ["RUB", "USD", "EUR", "GBP", "KZT", "TRY", "AMD", "GEL", "UAH", "BYN", "CNY"]
    private static let otherCurrencies = Set(Locale.commonISOCurrencyCodes).subtracting(popularCurrencies).sorted()

    private static func currencies(including current: String) -> (popular: [String], others: [String]) {
        guard !popularCurrencies.contains(current), !otherCurrencies.contains(current) else {
            return (popularCurrencies, otherCurrencies)
        }
        return (popularCurrencies, (otherCurrencies + [current]).sorted())
    }

    private static func name(_ code: String) -> String { Locale.current.localizedString(forCurrencyCode: code) ?? code }

    private static func label(_ code: String) -> String { "\(code) — \(name(code))" }
}
