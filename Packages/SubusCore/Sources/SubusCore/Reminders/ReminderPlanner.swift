import Foundation

public enum ReminderKind: String, Codable, Sendable { case charge, trialEnd }

public struct PlannedReminder: Equatable, Codable, Sendable {
    public var subscriptionID: UUID
    public var fireDate: Date
    public var chargeDate: LocalDate
    public var daysBefore: Int
    public var kind: ReminderKind
    public var amount: Money
    public var isCatchUp: Bool

    public var id: String { "\(subscriptionID)|\(chargeDate.iso)|\(daysBefore)|\(kind.rawValue)" }

    public init(subscriptionID: UUID, fireDate: Date, chargeDate: LocalDate, daysBefore: Int,
                kind: ReminderKind, amount: Money, isCatchUp: Bool) {
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
    private struct CatchUpKey: Hashable { let subscriptionID: UUID; let chargeDate: LocalDate }
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
                    let fire = now.addingTimeInterval(catchUpDelay)
                    let days = LocalDate.today(now: fire, calendar: calendar).days(until: charge.date)
                    if days >= 0 {
                        catchUps.append(PlannedReminder(subscriptionID: s.id, fireDate: fire, chargeDate: charge.date,
                                                        daysBefore: days, kind: kind, amount: charge.amount, isCatchUp: true))
                    }
                }
            }
        }

        let newCatchUpCharges = Set(catchUps.map { CatchUpKey(subscriptionID: $0.subscriptionID, chargeDate: $0.chargeDate) })
        let carried = settings.reminderDays.isEmpty ? [] : carriedCatchUps.filter {
            $0.fireDate > now && liveCharges[$0.subscriptionID]?.contains($0.chargeDate) == true
                && !newCatchUpCharges.contains(CatchUpKey(subscriptionID: $0.subscriptionID, chargeDate: $0.chargeDate))
        }

        var byID: [String: PlannedReminder] = [:]
        for r in regular + carried + catchUps { byID[r.id] = r }
        let sorted = byID.values.sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
        return Array(sorted.prefix(maxCount))
    }
}
