import Foundation

public enum ReminderKind: String, Sendable { case charge, trialEnd }

public struct PlannedReminder: Equatable, Sendable {
    public var id: String
    public var subscriptionID: UUID
    public var fireDate: Date
    public var chargeDate: LocalDate
    public var daysBefore: Int
    public var kind: ReminderKind
    public var amount: Money
    public var isCatchUp: Bool

    public init(subscriptionID: UUID, fireDate: Date, chargeDate: LocalDate, daysBefore: Int,
                kind: ReminderKind, amount: Money, isCatchUp: Bool) {
        self.id = "\(subscriptionID)|\(chargeDate.iso)|\(daysBefore)|\(kind.rawValue)"
        self.subscriptionID = subscriptionID
        self.fireDate = fireDate
        self.chargeDate = chargeDate
        self.daysBefore = daysBefore
        self.kind = kind
        self.amount = amount
        self.isCatchUp = isCatchUp
    }
}

public enum ReminderPlanner {
    public static let maxCount = 60
    public static let horizonDays = 60
    static let catchUpDelay: TimeInterval = 60

    public static func plan(library: Library, settings: AppSettings, now: Date, calendar: Calendar,
                            justSaved: Set<UUID>, carriedCatchUps: [PlannedReminder] = []) -> [PlannedReminder] {
        let today = LocalDate.today(now: now, calendar: calendar)
        let horizon = today...today.adding(days: horizonDays)
        var regular: [PlannedReminder] = []
        var catchUps: [PlannedReminder] = []
        var liveCharges: [UUID: Set<LocalDate>] = [:]

        for s in library.subscriptions where s.isLive(today: today) && s.notificationsEnabled {
            let charges = BillingSchedule.charges(for: s, in: horizon)
            liveCharges[s.id] = Set(charges.map(\.date))
            for (index, charge) in charges.enumerated() {
                let kind: ReminderKind = charge.isFirstAfterTrial ? .trialEnd : .charge
                var hasFuture = false
                for days in settings.reminderDays {
                    let fire = charge.date.adding(days: -days)
                        .date(hour: settings.reminderHour, minute: settings.reminderMinute, calendar: calendar)
                    guard fire > now else { continue }
                    hasFuture = true
                    regular.append(PlannedReminder(subscriptionID: s.id, fireDate: fire, chargeDate: charge.date,
                                                   daysBefore: days, kind: kind, amount: charge.amount, isCatchUp: false))
                }
                if index == 0, !hasFuture, !settings.reminderDays.isEmpty, justSaved.contains(s.id) {
                    catchUps.append(PlannedReminder(subscriptionID: s.id, fireDate: now.addingTimeInterval(catchUpDelay),
                                                    chargeDate: charge.date, daysBefore: today.days(until: charge.date),
                                                    kind: kind, amount: charge.amount, isCatchUp: true))
                }
            }
        }

        let newCatchUpIDs = Set(catchUps.map(\.id))
        let carried = carriedCatchUps.filter {
            $0.fireDate > now && liveCharges[$0.subscriptionID]?.contains($0.chargeDate) == true
                && !newCatchUpIDs.contains($0.id)
        }

        var byID: [String: PlannedReminder] = [:]
        for r in regular + carried + catchUps { byID[r.id] = r }
        let sorted = byID.values.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
        return Array(sorted.prefix(maxCount))
    }
}
