import AppKit
import OSLog
import SubusCore
@preconcurrency import UserNotifications

@MainActor
final class UserNotifier: NSObject, UNUserNotificationCenterDelegate {
    private enum Category {
        static let chargeManage = "SUB_CHARGE_MANAGE", charge = "SUB_CHARGE"
        static let trialManage = "SUB_TRIAL_MANAGE", trial = "SUB_TRIAL"
    }
    private static let manageAction = "MANAGE"
    private static let ourMarker: Character = "|"

    /// Clicks that arrive before the model is ready wait here until `onOpen` is set.
    var onOpen: ((UUID) -> Void)? {
        didSet { flushPendingOpen() }
    }
    private var pendingOpen: UUID?
    private var generation = 0
    private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "reminders")

    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func registerCategories() {
        guard let center else { return }
        let manage = UNNotificationAction(identifier: Self.manageAction,
                                          title: String(localized: "Manage Subscription"), options: [])
        func category(_ id: String, _ actions: [UNNotificationAction]) -> UNNotificationCategory {
            UNNotificationCategory(identifier: id, actions: actions, intentIdentifiers: [], options: [])
        }
        center.setNotificationCategories([
            category(Category.chargeManage, [manage]), category(Category.charge, []),
            category(Category.trialManage, [manage]), category(Category.trial, []),
        ])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        guard let center else { return .notDetermined }
        return await center.notificationSettings().authorizationStatus
    }

    func isAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional: true
        default: false
        }
    }

    func requestAuthorization() async -> Bool {
        guard let center else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            log.error("Authorization request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func replaceAll(_ reminders: [PlannedReminder], library: Library) async {
        guard let center else { return }
        generation += 1
        let mine = generation
        let pending = await center.pendingNotificationRequests()
        guard mine == generation else { return }
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.contains(Self.ourMarker) })

        let calendar = Calendar.subus()
        let now = Date()
        for reminder in reminders {
            guard let subscription = library.subscriptions.first(where: { $0.id == reminder.subscriptionID }) else { continue }
            let content = UNMutableNotificationContent()
            content.title = subscription.name
            content.body = body(for: reminder, subscription: subscription, library: library)
            content.sound = .default
            var info: [String: String] = ["subscriptionID": subscription.id.uuidString]
            let hasManage = subscription.manageURL != nil
            if let url = subscription.manageURL { info["manageURL"] = url.absoluteString }
            content.userInfo = info
            switch (reminder.kind, hasManage) {
            case (.charge, true): content.categoryIdentifier = Category.chargeManage
            case (.charge, false): content.categoryIdentifier = Category.charge
            case (.trialEnd, true): content.categoryIdentifier = Category.trialManage
            case (.trialEnd, false): content.categoryIdentifier = Category.trial
            }

            let trigger: UNNotificationTrigger
            if reminder.isCatchUp {
                trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, reminder.fireDate.timeIntervalSince(now)), repeats: false)
            } else {
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
                components.calendar = calendar
                components.timeZone = calendar.timeZone
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                log.error("Could not add \(reminder.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            guard mine == generation else { return }
        }
    }

    func sendTest() {
        guard let center else { return }
        Task {
            if await authorizationStatus() == .notDetermined { _ = await requestAuthorization() }
            let content = UNMutableNotificationContent()
            content.title = "Subus"
            content.body = String(localized: "Test notification — reminders will look like this.")
            content.sound = .default
            do {
                try await center.add(UNNotificationRequest(identifier: "test", content: content, trigger: nil))
            } catch {
                log.error("Test notification failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func body(for r: PlannedReminder, subscription: Subscription, library: Library) -> String {
        let d = r.daysBefore
        let amount = Formatters.money(r.amount)
        switch r.kind {
        case .charge:
            var text: String
            switch d {
            case 0: text = String(localized: "Charged today · \(amount)")
            case 1: text = String(localized: "Charge tomorrow · \(amount)")
            default: text = String(localized: "Charge in \(d) days · \(amount)")
            }
            if let id = subscription.paymentMethodID,
               let method = library.paymentMethods.first(where: { $0.id == id }) {
                text += " · " + method.label
            }
            return text
        case .trialEnd:
            let cycle = Formatters.cycle(subscription.cycle)
            switch d {
            case 0: return String(localized: "Trial ends today, then \(amount) / \(cycle)")
            case 1: return String(localized: "Trial ends tomorrow, then \(amount) / \(cycle)")
            default: return String(localized: "Trial ends in \(d) days, then \(amount) / \(cycle)")
            }
        }
    }

    private func handle(subscriptionID: UUID?, action: String, manageURL: URL?) {
        if action == Self.manageAction {
            if let manageURL, ["http", "https"].contains(manageURL.scheme?.lowercased()) {
                NSWorkspace.shared.open(manageURL)
            }
            return
        }
        guard action == UNNotificationDefaultActionIdentifier, let subscriptionID else { return }
        pendingOpen = subscriptionID
        flushPendingOpen()
    }

    private func flushPendingOpen() {
        guard let onOpen, let id = pendingOpen else { return }
        pendingOpen = nil
        log.info("Opening subscription from notification \(id.uuidString, privacy: .public)")
        onOpen(id)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let id = (info["subscriptionID"] as? String).flatMap(UUID.init(uuidString:))
        let url = (info["manageURL"] as? String).flatMap(URL.init(string:))
        let action = response.actionIdentifier
        await MainActor.run { handle(subscriptionID: id, action: action, manageURL: url) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
