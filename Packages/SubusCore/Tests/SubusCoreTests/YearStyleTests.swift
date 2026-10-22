import Foundation
import Testing
@testable import SubusCore

private let mondayFirst: Calendar = {
    var c = msk
    c.firstWeekday = 2
    return c
}()

private let styleToday = d("2026-10-21")
private let styleConverter = CurrencyConverter(table: RateTable(date: styleToday, rubPerUnit: ["RUB": 1], fetchedAt: .now))

private func stylePlan(_ library: Library, filter: YearFilter = YearFilter()) -> YearPlan {
    YearPlan.build(library: library, filter: filter, today: styleToday, calendar: mondayFirst,
                   baseCurrency: "RUB", converter: styleConverter)
}

private func styleSub(_ name: String = "X", end: String? = nil) -> Subscription {
    Subscription(name: name, price: rub(100), cycle: .monthly, startDate: d("2026-01-05"), endDate: end.map(d))
}

@Test func rampMatchesSpec() {
    #expect(YearRamp.tone(level: 2, dark: false, increasedContrast: false).hex == "#A3A39D")
    #expect(YearRamp.tone(level: 4, dark: true, increasedContrast: true).hex == "#FFFFFF")
    #expect(YearRamp.text(level: 2, dark: true, increasedContrast: true).hex == "#000000")
    #expect(YearRamp.text(level: 3, dark: false, increasedContrast: false).hex == "#FFFFFF")
    #expect(YearRamp.text(level: 1, dark: true, increasedContrast: true).hex == "#FFFFFF")
}

@Test func rampTextContrast() {
    for dark in [false, true] {
        for ic in [false, true] {
            for level in 0...4 {
                let ratio = LineContrast.ratio(YearRamp.tone(level: level, dark: dark, increasedContrast: ic),
                                               YearRamp.text(level: level, dark: dark, increasedContrast: ic))
                #expect(ratio >= 4.5, "level \(level) dark \(dark) ic \(ic): \(ratio)")
            }
        }
    }
}

@Test func ringsContrast() throws {
    let accent = try #require(SRGBColor(hex: "#E8590C"))
    #expect(LineContrast.ratio(accent, YearRamp.cardLight) >= 3)
    #expect(LineContrast.ratio(accent, YearRamp.cardDark) >= 3)
}

@Test func selectionCarriesAcrossModes() {
    let p = stylePlan(Library())
    #expect(YearSelection.carry(d("2027-02-08"), from: .weeks, to: .months, plan: p, today: styleToday) == d("2027-02-01"))
    #expect(YearSelection.carry(d("2027-03-29"), from: .weeks, to: .months, plan: p, today: styleToday) == d("2027-04-01"))
    #expect(YearSelection.carry(d("2027-02-01"), from: .months, to: .weeks, plan: p, today: styleToday) == d("2027-02-01"))
    #expect(YearSelection.carry(d("2026-10-01"), from: .months, to: .weeks, plan: p, today: styleToday) == d("2026-10-19"))
    #expect(YearSelection.carry(d("2027-02-08"), from: .weeks, to: .weeks, plan: p, today: styleToday) == d("2027-02-08"))
}

@Test func lastWeekCarriesToLastMonthWhenItsMonthKeyIsOutsidePlan() {
    // Range ends Wed 2027-03-31: the last week (Mon 03-29) has its 4th day in April, a month the plan lacks.
    let today = d("2026-04-01")
    let p = YearPlan.build(library: Library(), filter: YearFilter(), today: today, calendar: mondayFirst,
                           baseCurrency: "RUB", converter: styleConverter)
    #expect(p.weeks.last?.id == d("2027-03-29"))
    #expect(YearSelection.carry(d("2027-03-29"), from: .weeks, to: .months, plan: p, today: today) == d("2027-03-01"))
}

@Test func selectionFallsBackToCurrent() {
    let p = stylePlan(Library())
    #expect(YearSelection.carry(d("2026-10-12"), from: .weeks, to: .weeks, plan: p, today: styleToday) == d("2026-10-19"))
    #expect(YearSelection.carry(nil, from: .weeks, to: .months, plan: p, today: styleToday) == d("2026-10-01"))
    #expect(YearSelection.current(in: p, mode: .weeks, today: styleToday) == d("2026-10-19"))
}

@Test func unreadableIsNotEmptyLibrary() {
    let p = stylePlan(.empty)
    #expect(YearScreenState.resolve(plan: p, library: .empty, isUnreadable: true) == .unreadable)
    #expect(YearScreenState.resolve(plan: p, library: .empty, isUnreadable: false) == .noSubscriptions)
}

@Test func screenStates() {
    let lib = Library(subscriptions: [styleSub()])
    var filter = YearFilter()
    filter.currencies = ["USD"]
    #expect(YearScreenState.resolve(plan: stylePlan(lib, filter: filter), library: lib, isUnreadable: false) == .nothingMatches)

    let ended = Library(subscriptions: [styleSub(end: "2026-06-01")])
    #expect(YearScreenState.resolve(plan: stylePlan(ended), library: ended, isUnreadable: false) == .noChargesThisYear)
    #expect(YearScreenState.resolve(plan: stylePlan(lib), library: lib, isUnreadable: false) == .grid)
}
