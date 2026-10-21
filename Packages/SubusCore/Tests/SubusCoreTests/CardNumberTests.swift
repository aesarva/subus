import Foundation
import Testing
@testable import SubusCore

private let ru = Locale(identifier: "ru_RU")
private let en = Locale(identifier: "en_US")

@Suite struct CardNumberTests {
    @Test(arguments: [
        ("4111111111111111", CardNetwork.visa),
        ("5105105105105100", .mastercard),
        ("2221000000000009", .mastercard),
        ("2720990000000007", .mastercard),
        ("2200000000000004", .mir),
        ("2204000000000001", .mir),
        ("340000000000009", .amex),
        ("370000000000002", .amex),
        ("6200000000000005", .unionPay),
        ("3528000000000007", .jcb),
        ("3589000000000003", .jcb),
    ])
    func networkPrefixes(digits: String, network: CardNetwork) {
        #expect(CardNumber.network(ofDigits: digits) == network)
    }

    @Test(arguments: ["2205000000000000", "3590000000000000", "9999000000000000"])
    func unknownPrefixHasNoNetwork(digits: String) {
        #expect(CardNumber.network(ofDigits: digits) == nil)
    }

    @Test(arguments: ["41111111111", "41111111111111111111", "4111 1111 1111 111a", "•• 4242", ""])
    func summaryRejects(text: String) {
        #expect(CardNumber.summary(of: text) == nil)
    }

    @Test func summaryIgnoresSpacesDashesAndNBSP() {
        let s = CardNumber.summary(of: "4111-1111\u{00A0}1111 1111")
        #expect(s?.last4 == "1111")
        #expect(s?.network == .visa)
    }

    @Test func cardFieldParsesAutoFillWithSpaces() {
        let s = CardFieldParser.edited(CardFieldState(), to: "4242 4242 4242 4242")
        #expect(s == CardFieldState(text: "•• 4242", last4: "4242", network: .visa))
    }

    @Test func cardFieldWaitsWhileTyping() {
        var state = CardFieldState()
        let number = "4242424242424242"
        for i in 1...number.count {
            state = CardFieldParser.edited(state, to: String(number.prefix(i)))
            #expect(state.text == String(number.prefix(i)))
            #expect(state.last4 == (i == 4 ? "4242" : nil))
            #expect(state.network == nil)
        }
    }

    @Test func cardFieldParsesAutoFillOverTypedText() {
        let typed = CardFieldState(text: "123456789")
        let s = CardFieldParser.edited(typed, to: "4242424242424242", inserted: 16)
        #expect(s == CardFieldState(text: "•• 4242", last4: "4242", network: .visa))
        #expect(CardFieldParser.edited(typed, to: "1234567890", inserted: 1).last4 == nil)
    }

    @Test func cardFieldParsesOnEnd() {
        let typed = CardFieldState(text: "4242424242424242")
        #expect(CardFieldParser.ended(typed) == CardFieldState(text: "•• 4242", last4: "4242", network: .visa))
        let four = CardFieldState(text: "1234", last4: "1234")
        #expect(CardFieldParser.ended(four) == four)
    }

    @Test func maskReadsBack() {
        let parsed = CardFieldState(text: "•• 4242", last4: "4242", network: .visa)
        #expect(CardFieldParser.edited(parsed, to: "•• 4242") == parsed)
        #expect(CardFieldParser.edited(parsed, to: "•• 1111") == CardFieldState(text: "•• 1111", last4: "1111", network: nil))
        #expect(CardFieldParser.edited(parsed, to: "••4242").network == .visa)
    }

    @Test func editResets() {
        let parsed = CardFieldState(text: "•• 4242", last4: "4242", network: .visa)
        #expect(CardFieldParser.edited(parsed, to: "•• 42") == CardFieldState(text: "•• 42"))
    }

    @Test func maskFormat() {
        #expect(CardFieldParser.mask("0815") == "•• 0815")
    }

    @Test func networkNames() {
        #expect(CardNetwork.mir.displayName(locale: ru) == "Мир")
        #expect(CardNetwork.mir.displayName(locale: en) == "Mir")
        #expect(CardNetwork.amex.displayName(locale: ru) == "Amex")
        #expect(CardNetwork.unionPay.displayName(locale: en) == "UnionPay")
    }
}

@Test(arguments: [
    ("Т-Банк", "4242", CardNetwork?.some(.visa), en, "Т-Банк •• 4242"),
    ("Т-Банк", nil, nil, en, "Т-Банк"),
    ("", "4242", .visa, en, "Visa •• 4242"),
    ("", "4242", .mir, ru, "Мир •• 4242"),
    ("", "4242", .mir, en, "Mir •• 4242"),
    ("", "4242", nil, en, "•• 4242"),
    (" ", nil, nil, en, ""),
    ("  Revolut ", "0815", .mastercard, en, "Revolut •• 0815"),
] as [(String, String?, CardNetwork?, Locale, String)])
func composeForms(bank: String, last4: String?, network: CardNetwork?, locale: Locale, expected: String) {
    #expect(PaymentLabel.compose(bank: bank, last4: last4, network: network, locale: locale) == expected)
}

@Test func composeSplits() {
    let label = PaymentLabel.compose(bank: "Т-Банк", last4: "4242", network: nil, locale: en)
    #expect(PaymentLabel.split(label) == ("Т-Банк", "•• 4242"))
    #expect(PaymentLabel.split("Visa •• 4242") == ("Visa", "•• 4242"))
    #expect(PaymentLabel.split("•• 4242") == ("•• 4242", nil))
}

@Test func cardSheetAddWaitsForTypedText() {
    #expect(CardSheetAdd.enabled(label: "", hasText: true))
    #expect(CardSheetAdd.enabled(label: "Т-Банк", hasText: false))
    #expect(!CardSheetAdd.enabled(label: "", hasText: false))
    #expect(CardSheetAdd.blocked(CardFieldState(), hasText: true))
    #expect(!CardSheetAdd.blocked(CardFieldState(text: "•• 4242", last4: "4242", network: .visa), hasText: true))
    #expect(!CardSheetAdd.blocked(CardFieldState(), hasText: false))
}
