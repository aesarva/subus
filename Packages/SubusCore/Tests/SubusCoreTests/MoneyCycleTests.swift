import Foundation
import Testing
@testable import SubusCore

@Test func moneyKeepsPrecision() throws {
    let m = rub(Decimal(string: "1199.99")!)
    let json = try JSONEncoder().encode(m)
    #expect(String(decoding: json, as: UTF8.self).contains("\"1199.99\""))
    #expect(try JSONDecoder().decode(Money.self, from: json) == m)
    #expect(try JSONDecoder().decode(Money.self, from: Data(#"{"amount":5,"currency":"USD"}"#.utf8)) == usd(5))
}

@Test func moneyUppercasesCurrency() throws {
    #expect(Money(1, "usd").currency == "USD")
    #expect(try JSONDecoder().decode(Money.self, from: Data(#"{"amount":"1","currency":"eur"}"#.utf8)).currency == "EUR")
}

@Test func cycleCodable() throws {
    let c = BillingCycle(3, .month)
    #expect(try JSONDecoder().decode(BillingCycle.self, from: JSONEncoder().encode(c)) == c)
    #expect(try JSONDecoder().decode(BillingCycle.self, from: Data(#"{"count":0,"unit":"month"}"#.utf8)).count == 1)
    #expect(try JSONDecoder().decode(BillingCycle.self, from: Data(#"{"count":100000,"unit":"day"}"#.utf8)).count == 999)
    #expect(BillingCycle(-3, .week).count == 1)
}
