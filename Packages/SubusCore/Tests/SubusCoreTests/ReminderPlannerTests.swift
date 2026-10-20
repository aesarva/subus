import Foundation
import Testing
@testable import SubusCore

@Suite struct ReminderPlannerTests {
    let settings = AppSettings.defaults(locale: Locale(identifier: "ru_RU"))

    func at(_ iso: String, _ h: Int, _ m: Int = 0, _ cal: Calendar = msk) -> Date {
        d(iso).date(hour: h, minute: m, calendar: cal)
    }

    func sub(anchor: String = "2026-10-25", cycle: BillingCycle = BillingCycle(1, .month), trialEnd: String? = nil) -> Subscription {
        Subscription(name: "X", price: rub(100), cycle: cycle, startDate: d(anchor),
                     trialEndDate: trialEnd.map(d))
    }

    func plan(_ subs: [Subscription], now: Date, settings: AppSettings? = nil, calendar: Calendar = msk,
              justSaved: Set<UUID> = [], carried: [PlannedReminder] = []) -> [PlannedReminder] {
        ReminderPlanner.plan(library: Library(subscriptions: subs), settings: settings ?? self.settings, now: now,
                             calendar: calendar, justSaved: justSaved, carriedCatchUps: carried)
    }

    @Test func basicSchedule() {
        let r = plan([sub()], now: at("2026-10-20", 8))
        #expect(r.count == 6)
        #expect(r.prefix(3).map(\.fireDate) == [at("2026-10-20", 10), at("2026-10-22", 10), at("2026-10-24", 10)])
        #expect(r.prefix(3).map(\.daysBefore) == [5, 3, 1])
        #expect(r.prefix(3).allSatisfy { $0.chargeDate == d("2026-10-25") && !$0.isCatchUp })
        #expect(r.suffix(3).allSatisfy { $0.chargeDate == d("2026-11-25") })
    }

    @Test func deterministicIDs() {
        let s = sub()
        let now = at("2026-10-20", 8)
        let a = plan([s], now: now), b = plan([s], now: now)
        #expect(a == b)
        #expect(a[0].id == "\(s.id)|2026-10-25|5|charge")
    }

    @Test func customTime() {
        var st = settings
        st.reminderHour = 21; st.reminderMinute = 30
        let r = plan([sub()], now: at("2026-10-20", 8), settings: st)
        #expect(r[0].fireDate == at("2026-10-20", 21, 30))
    }

    @Test func pastMomentsDropped() {
        let r = plan([sub(cycle: BillingCycle(1, .year))], now: at("2026-10-22", 12))
        #expect(r.map(\.daysBefore) == [1])
        #expect(r[0].fireDate == at("2026-10-24", 10))
    }

    @Test func momentEqualToNowDropped() {
        let r = plan([sub(cycle: BillingCycle(1, .year))], now: at("2026-10-20", 10))
        #expect(r.map(\.daysBefore) == [3, 1])
    }

    @Test func catchUpOnlyWhenJustSaved() {
        let s = sub(cycle: BillingCycle(1, .year))
        let now = at("2026-10-24", 15)
        #expect(plan([s], now: now).isEmpty)
        let r = plan([s], now: now, justSaved: [s.id])
        #expect(r.count == 1)
        #expect(r[0].fireDate == now.addingTimeInterval(60))
        #expect(r[0].daysBefore == 1)
        #expect(r[0].isCatchUp)
        #expect(r[0].id == "\(s.id)|2026-10-25|1|charge")
        #expect(plan([s], now: now, justSaved: []).isEmpty)
    }

    @Test func noCatchUpWhileFutureMomentRemains() {
        let s = sub(cycle: BillingCycle(1, .year))
        let r = plan([s], now: at("2026-10-21", 15), justSaved: [s.id])
        #expect(r.map(\.fireDate) == [at("2026-10-22", 10), at("2026-10-24", 10)])
        #expect(r.allSatisfy { !$0.isCatchUp })
    }

    @Test func catchUpOnlyForNearestCharge() {
        let s = sub(cycle: BillingCycle(1, .month))
        let r = plan([s], now: at("2026-10-24", 15), justSaved: [s.id])
        #expect(r.filter(\.isCatchUp).count == 1)
        #expect(r.filter { $0.chargeDate == d("2026-11-25") }.count == 3)
    }

    @Test func catchUpNeedsReminderDays() {
        var st = settings
        st.reminderDays = []
        let s = sub()
        #expect(plan([s], now: at("2026-10-24", 15), settings: st, justSaved: [s.id]).isEmpty)
    }

    @Test func trialKind() {
        let r = plan([sub(anchor: "2026-10-01", trialEnd: "2026-10-25")], now: at("2026-10-20", 8))
        #expect(r.filter { $0.chargeDate == d("2026-10-25") }.allSatisfy { $0.kind == .trialEnd })
        #expect(r.filter { $0.chargeDate == d("2026-11-25") }.allSatisfy { $0.kind == .charge })
        #expect(r.contains { $0.chargeDate == d("2026-11-25") })
    }

    @Test func capAndOrder() {
        let subs = (0..<30).map { _ in sub(anchor: "2026-10-21", cycle: BillingCycle(1, .week)) }
        let r = plan(subs, now: at("2026-10-20", 8))
        #expect(r.count == 60)
        #expect(zip(r, r.dropFirst()).allSatisfy { $0.fireDate <= $1.fireDate })
    }

    @Test func filters() {
        let now = at("2026-10-20", 8)
        var off = sub(); off.notificationsEnabled = false
        var inactive = sub(); inactive.isActive = false
        var ended = sub(); ended.endDate = d("2026-10-01")
        #expect(plan([off, inactive, ended], now: now).isEmpty)
        var st = settings; st.reminderDays = []
        #expect(plan([sub()], now: now, settings: st).isEmpty)
    }

    @Test func timeZoneIndependentDates() {
        let r = plan([sub()], now: at("2026-10-20", 8, 0, ny), calendar: ny)
        #expect(r.count == 6)
        #expect(Set(r.map(\.chargeDate)) == [d("2026-10-25"), d("2026-11-25")])
        #expect(r[0].fireDate == at("2026-10-20", 10, 0, ny))
    }

    @Test func carriedCatchUpSurvivesReplan() {
        var s = sub(cycle: BillingCycle(1, .year))
        let now = at("2026-10-24", 15)
        let c = plan([s], now: now, justSaved: [s.id])[0]
        #expect(c.isCatchUp)
        let later = now.addingTimeInterval(20)
        #expect(plan([s], now: later, carried: [c]) == [c])
        #expect(plan([s], now: c.fireDate, carried: [c]).isEmpty)
        #expect(plan([s], now: c.fireDate.addingTimeInterval(1), carried: [c]).isEmpty)
        // re-saved in the same minute: one reminder, not two
        #expect(plan([s], now: later, justSaved: [s.id], carried: [c]).count == 1)
        s.isActive = false
        #expect(plan([s], now: later, carried: [c]).isEmpty)
        s.isActive = true; s.notificationsEnabled = false
        #expect(plan([s], now: later, carried: [c]).isEmpty)
        s.notificationsEnabled = true; s.startDate = d("2026-10-26")
        #expect(!plan([s], now: later, carried: [c]).contains(c))
    }

    @Test func carriedCatchUpCountsTowardBudget() {
        let s = sub(cycle: BillingCycle(1, .year))
        let now = at("2026-10-24", 15)
        let c = plan([s], now: now, justSaved: [s.id])[0]
        let many = (0..<40).map { _ in sub(anchor: "2026-10-26", cycle: BillingCycle(1, .day)) }
        let r = plan(many + [s], now: now.addingTimeInterval(20), carried: [c])
        #expect(r.count == 60)
        #expect(r.contains(c))
    }

    @Test func dstTransition() throws {
        let iso = ISO8601DateFormatter()
        var st = settings; st.reminderDays = [1]
        let fall = plan([sub(anchor: "2026-11-02", cycle: BillingCycle(1, .year))], now: at("2026-10-30", 8, 0, ny),
                        settings: st, calendar: ny)
        #expect(fall.first?.fireDate == iso.date(from: "2026-11-01T15:00:00Z"))
        let spring = plan([sub(anchor: "2026-03-09", cycle: BillingCycle(1, .year))], now: at("2026-03-05", 8, 0, ny),
                          settings: st, calendar: ny)
        #expect(spring.first?.fireDate == iso.date(from: "2026-03-08T14:00:00Z"))
    }
}
