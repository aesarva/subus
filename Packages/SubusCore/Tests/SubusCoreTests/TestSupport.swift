import Foundation
@testable import SubusCore

func d(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }
func rub(_ v: Decimal) -> Money { Money(v, "RUB") }
func usd(_ v: Decimal) -> Money { Money(v, "USD") }
func eur(_ v: Decimal) -> Money { Money(v, "EUR") }

let msk = Calendar.subus(timeZone: TimeZone(identifier: "Europe/Moscow")!, locale: Locale(identifier: "en_US"))
let ny = Calendar.subus(timeZone: TimeZone(identifier: "America/New_York")!, locale: Locale(identifier: "en_US"))
