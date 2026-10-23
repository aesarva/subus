import Foundation
import Testing
@testable import SubusCore

@Test func isoRoundTrip() {
    #expect(d("2026-02-28").iso == "2026-02-28")
    #expect(LocalDate(iso: "2026-02-30") == nil)
    #expect(LocalDate(iso: "26-2-1") == nil)
}

@Test func addingMonthsClampsDay() {
    #expect(d("2026-01-31").adding(months: 1) == d("2026-02-28"))
    #expect(d("2028-01-31").adding(months: 1) == d("2028-02-29"))
    #expect(d("2026-03-31").adding(months: -1) == d("2026-02-28"))
}

@Test func daysBetween() {
    #expect(d("2026-01-01").days(until: d("2027-01-01")) == 365)
    #expect(d("2026-03-01").adding(days: -1) == d("2026-02-28"))
}

@Test func todayRespectsTimeZone() {
    let t = Date(timeIntervalSince1970: 1_792_537_200) // 2026-10-20 23:00 UTC
    #expect(LocalDate.today(now: t, calendar: msk) == d("2026-10-21"))
    #expect(LocalDate.today(now: t, calendar: ny) == d("2026-10-20"))
}

@Test func dateAtTimeInZone() {
    #expect(msk.dateComponents([.hour, .minute, .day], from: d("2026-10-20").date(hour: 10, minute: 0, calendar: msk)) == DateComponents(day: 20, hour: 10, minute: 0))
}

@Test func localDateCodableAsString() throws {
    #expect(String(decoding: try JSONEncoder().encode(d("2026-10-20")), as: UTF8.self) == "\"2026-10-20\"")
}

@Test func subusCalendarIsGregorian() {
    let c = Calendar.subus(timeZone: TimeZone(identifier: "Asia/Tokyo")!, locale: Locale(identifier: "ja_JP@calendar=japanese"))
    #expect(c.identifier == .gregorian)
    #expect(c.timeZone.identifier == "Asia/Tokyo")
    #expect(Calendar.subus(locale: Locale(identifier: "ru_RU")).firstWeekday == 2)
}

@Test func yearRangeEnforced() {
    #expect(LocalDate(iso: "1899-12-31") == nil)
    #expect(LocalDate(iso: "3000-01-01") == nil)
    #expect(LocalDate(iso: "1900-01-01") != nil)
    #expect(LocalDate(iso: "2999-12-31") != nil)
    #expect(LocalDate(year: 1899, month: 1, day: 1) == nil)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(LocalDate.self, from: Data("\"3000-01-01\"".utf8)) }
}

@Test func addingClampsAtBounds() {
    #expect(d("2999-12-31").adding(months: 1) == d("2999-12-31"))
    #expect(d("1900-01-01").adding(days: -1) == d("1900-01-01"))
    #expect(d("2999-12-31").adding(days: 1) == d("2999-12-31"))
    #expect(d("1900-01-01").adding(months: -1) == d("1900-01-01"))
    #expect(d("2026-01-01").adding(days: Int.max) == d("2999-12-31"))
    #expect(d("2026-01-01").adding(months: Int.min) == d("1900-01-01"))
}
