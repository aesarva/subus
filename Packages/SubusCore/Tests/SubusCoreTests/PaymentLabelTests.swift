import Testing
@testable import SubusCore

@Test(arguments: [
    ("Т-Банк •• 4242", "Т-Банк", "•• 4242"),
    ("Visa ••1234 личная", "Visa", "••1234"),
    ("Card 12345678", "Card", "12345678"),
    ("Т-Банк\u{00A0}••\u{00A0}4242", "Т-Банк", "•• 4242"),
    ("Revolut Metal Premium •• 0815", "Revolut Metal Premium", "•• 0815"),
])
func paymentLabelSplitsOffTheCardTail(label: String, head: String, tail: String) {
    let result = PaymentLabel.split(label)
    #expect(result.head == head)
    #expect(result.tail == tail)
}

@Test(arguments: ["•• 4242", "4242", "①②③④", "Card ①②③④", "Card 123", "Card 123456789", "Т-Банк", ""])
func paymentLabelWithoutATailStaysWhole(label: String) {
    let result = PaymentLabel.split(label)
    #expect(result.head == label)
    #expect(result.tail == nil)
}
