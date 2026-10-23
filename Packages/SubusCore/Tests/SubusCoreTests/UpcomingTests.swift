import Foundation
import Testing
@testable import SubusCore

private let mondayFirst: Calendar = {
    var c = msk
    c.firstWeekday = 2
    return c
}()

private func yearly(_ name: String = "X", charging iso: String) -> Subscription {
    let date = d(iso)
    return Subscription(name: name, price: rub(100), cycle: .yearly,
                        startDate: LocalDate(year: date.year - 1, month: date.month, day: date.day)!)
}

private let today = d("2026-10-20")

@Test func grouping() {
    let dates = ["2026-10-20", "2026-10-21", "2026-10-24", "2026-10-30", "2026-11-15", "2026-12-25"]
    let library = Library(subscriptions: dates.map { yearly(charging: $0) })
    let sections = Upcoming.sections(library: library, today: today, calendar: mondayFirst)
    #expect(sections.map(\.group) == [.todayTomorrow, .thisWeek, .thisMonth, .later])
    #expect(sections.map(\.charges.count) == [2, 1, 1, 1])
    #expect(sections[1].charges[0].date == d("2026-10-24"))
    #expect(sections[3].charges[0].date == d("2026-11-15"))
}

@Test func sortedByDateThenName() {
    let library = Library(subscriptions: [yearly("b", charging: "2026-10-22"), yearly("A", charging: "2026-10-22"),
                                          yearly("c", charging: "2026-10-21")])
    let sections = Upcoming.sections(library: library, today: today, calendar: mondayFirst)
    let names = sections.flatMap(\.charges).map { c in library.subscriptions.first { $0.id == c.subscriptionID }!.name }
    #expect(names == ["c", "A", "b"])
}

@Test func inactiveAndEndedExcluded() {
    var off = yearly("off", charging: "2026-10-21")
    off.isActive = false
    let library = Library(subscriptions: [off])
    #expect(Upcoming.sections(library: library, today: today, calendar: mondayFirst).isEmpty)
}

@Test func nearestDays() {
    #expect(Upcoming.daysToNearest(library: Library(subscriptions: [yearly(charging: "2026-10-23")]), today: today) == 3)
    #expect(Upcoming.daysToNearest(library: Library(subscriptions: [yearly(charging: "2026-10-20")]), today: today) == 0)
    var off = yearly(charging: "2026-10-23")
    off.isActive = false
    #expect(Upcoming.daysToNearest(library: Library(subscriptions: [off]), today: today) == nil)
    #expect(Upcoming.daysToNearest(library: Library(subscriptions: [yearly(charging: "2027-01-25")]), today: today) == 97)
}

@Test func nextThree() {
    let s = Subscription(name: "M", price: rub(100), cycle: .monthly, startDate: d("2026-10-25"))
    #expect(Upcoming.nextCharges(for: s, today: today).map(\.date) == [d("2026-10-25"), d("2026-11-25"), d("2026-12-25")])
    var ending = s
    ending.endDate = d("2026-11-25")
    #expect(Upcoming.nextCharges(for: ending, today: today).map(\.date) == [d("2026-10-25"), d("2026-11-25")])
}

@Test func eachSubscriptionOnceWithItsNearestCharge() {
    let weekly = Subscription(name: "W", price: rub(100), cycle: BillingCycle(1, .week), startDate: d("2026-10-21"))
    let monthly = Subscription(name: "M", price: rub(100), cycle: .monthly, startDate: d("2026-09-25"))
    let sections = Upcoming.sections(library: Library(subscriptions: [weekly, monthly]), today: today, calendar: mondayFirst)
    let charges = sections.flatMap(\.charges)
    #expect(charges.map(\.subscriptionID) == [weekly.id, monthly.id])
    #expect(charges.map(\.date) == [d("2026-10-21"), d("2026-10-25")])
}

@Test func horizonIsThirtyDays() {
    #expect(Upcoming.horizonDays == 30)
    let inside = yearly("in", charging: "2026-11-19"), outside = yearly("out", charging: "2026-11-20")
    let sections = Upcoming.sections(library: Library(subscriptions: [inside, outside]), today: today, calendar: mondayFirst)
    #expect(sections.flatMap(\.charges).map(\.subscriptionID) == [inside.id])
}

@Test func remindersKeepTheirOwnSixtyDayHorizon() {
    #expect(ReminderPlanner.horizonDays == 60)
}
