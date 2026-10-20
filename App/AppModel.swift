import AppKit
import Observation
import OSLog
import SubusCore

@MainActor @Observable
final class AppModel {
    private(set) var library: Library
    private(set) var settings: AppSettings
    private(set) var rates: RateTable?
    private(set) var recovery: Recovery?
    private(set) var notificationsAuthorized = false
    private(set) var saveError: String?
    var openSubscriptionRequest: UUID?

    /// Bumped when the calendar day may have changed, so derived values recompute.
    private var clock = 0
    @ObservationIgnored private var unreadableMessage: String?
    @ObservationIgnored private var carriedCatchUps: [PlannedReminder] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var rateTimer: Timer?
    @ObservationIgnored private(set) var replanCount = 0

    @ObservationIgnored private let store: SubscriptionStore
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let rateProvider: RateProvider
    @ObservationIgnored private let rateCache: RateCache
    @ObservationIgnored private let notifier: UserNotifier
    @ObservationIgnored private let logosDirectory: URL?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "store")
    @ObservationIgnored private let ratesLog = Logger(subsystem: "io.github.aesarva.Subus", category: "rates")
    @ObservationIgnored private let remindersLog = Logger(subsystem: "io.github.aesarva.Subus", category: "reminders")

    init(store: SubscriptionStore, settingsStore: SettingsStore, rateProvider: RateProvider, rateCache: RateCache,
         notifier: UserNotifier, logosDirectory: URL? = nil, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.settingsStore = settingsStore
        self.rateProvider = rateProvider
        self.rateCache = rateCache
        self.notifier = notifier
        self.logosDirectory = logosDirectory
        self.now = now
        settings = settingsStore.load()
        rates = rateCache.load()
        do {
            let result = try store.load()
            library = result.library
            recovery = result.recovery
        } catch {
            library = .empty
            let message = String(localized: "Couldn't read your data. Changes are not saved, so your file stays untouched.")
            unreadableMessage = message
            saveError = message
            log.error("Load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    nonisolated static func defaultCategoryNames() -> [String] {
        [String(localized: "Software"), String(localized: "Entertainment"), String(localized: "Music"),
         String(localized: "Cloud"), String(localized: "Work"), String(localized: "Other")]
    }

    // MARK: Derived

    var today: LocalDate {
        _ = clock
        return LocalDate.today(now: now(), calendar: .subus())
    }

    var summary: SpendingSummary {
        SummaryBuilder.build(library: library, baseCurrency: settings.baseCurrency,
                             converter: CurrencyConverter(table: rates), ratesDate: rates?.date, today: today)
    }

    var sections: [UpcomingSection] {
        Upcoming.sections(library: library, today: today, calendar: .subus())
    }

    var daysToNearest: Int? { Upcoming.daysToNearest(library: library, today: today) }

    var nearestCharge: (Subscription, Charge)? {
        let today = today
        return library.subscriptions
            .filter { $0.isLive(today: today) }
            .compactMap { s in BillingSchedule.nextCharge(for: s, onOrAfter: today).map { (s, $0) } }
            .min { ($0.1.date, $0.0.name) < ($1.1.date, $1.0.name) }
    }

    func category(_ id: UUID?) -> SubusCore.Category? {
        id.flatMap { id in library.categories.first { $0.id == id } }
    }

    func paymentMethod(_ id: UUID?) -> PaymentMethod? {
        id.flatMap { id in library.paymentMethods.first { $0.id == id } }
    }

    // MARK: Lifecycle

    func start() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.timeMayHaveChanged() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.timeMayHaveChanged() }
        })
        rateTimer = Timer.scheduledTimer(withTimeInterval: 12 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshRatesIfNeeded() }
        }
        replan()
        Task {
            await refreshAuthorization()
            await refreshRatesIfNeeded()
        }
    }

    private func timeMayHaveChanged() {
        clock += 1
        replan()
    }

    // MARK: Mutations

    @discardableResult
    func save(_ s: Subscription) -> Bool {
        let ok = commit(justSaved: [s.id]) { $0.upsert(s) }
        if ok { Task { await requestAuthorizationIfNeeded() } }
        return ok
    }

    @discardableResult
    func delete(_ id: UUID) -> Bool {
        let logo = library.subscriptions.first { $0.id == id }?.logo
        guard commit(mutating: { $0.remove(subscriptionID: id) }) else { return false }
        if let logo { removeLogoFileIfUnused(logo) }
        return true
    }

    @discardableResult
    func setActive(_ id: UUID, _ active: Bool) -> Bool {
        guard var s = library.subscriptions.first(where: { $0.id == id }) else { return false }
        s.isActive = active
        return commit(justSaved: active ? [id] : []) { $0.upsert(s) }
    }

    func updateSettings(_ s: AppSettings) {
        settingsStore.save(s)
        settings = s
        replan()
    }

    @discardableResult
    func replaceLibrary(_ l: Library) -> Bool {
        let ok = commit(justSaved: Set(l.subscriptions.map(\.id))) { $0 = l }
        if ok { removeUnusedLogoFiles() }
        return ok
    }

    private func commit(justSaved: Set<UUID> = [], mutating mutate: (inout Library) -> Void) -> Bool {
        if let unreadableMessage {
            saveError = unreadableMessage
            return false
        }
        var copy = library
        mutate(&copy)
        do {
            try store.save(copy)
        } catch {
            saveError = String(localized: "Couldn't save changes: \(error.localizedDescription)")
            log.error("Save failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
        library = copy
        saveError = nil
        replan(justSaved: justSaved)
        return true
    }

    private func removeLogoFileIfUnused(_ logo: Logo) {
        guard let logosDirectory else { return }
        switch logo {
        case .image(let name), .siteIcon(let name):
            guard Logo.isSafeFileName(name), !library.subscriptions.contains(where: { $0.logo == logo }) else { return }
            try? FileManager.default.removeItem(at: logosDirectory.appendingPathComponent(name))
        case .monogram:
            break
        }
    }

    private func removeUnusedLogoFiles() {
        guard let logosDirectory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: logosDirectory.path) else { return }
        let used = Set(library.subscriptions.compactMap { s -> String? in
            switch s.logo {
            case .image(let name), .siteIcon(let name): name
            case .monogram: nil
            }
        })
        for name in files where Logo.isSafeFileName(name) && !used.contains(name) {
            try? FileManager.default.removeItem(at: logosDirectory.appendingPathComponent(name))
        }
    }

    func dismissRecovery() { recovery = nil }

    // MARK: Reminders

    func replan(justSaved: Set<UUID> = []) {
        let plan = ReminderPlanner.plan(library: library, settings: settings, now: now(), calendar: .subus(),
                                        justSaved: justSaved, carriedCatchUps: carriedCatchUps)
        carriedCatchUps = plan.filter(\.isCatchUp)
        replanCount += 1
        remindersLog.info("Replan #\(self.replanCount): \(plan.count) reminders")
        let library = library
        Task { await notifier.replaceAll(plan, library: library) }
    }

    func refreshAuthorization() async {
        notificationsAuthorized = await notifier.isAuthorized()
    }

    private func requestAuthorizationIfNeeded() async {
        if await notifier.authorizationStatus() == .notDetermined {
            notificationsAuthorized = await notifier.requestAuthorization()
            if notificationsAuthorized { replan() }
        } else {
            await refreshAuthorization()
        }
    }

    // MARK: Rates

    func refreshRatesIfNeeded() async {
        guard RateRefreshPolicy.needsRefresh(cached: rates, now: now()) else { return }
        do {
            let table = try await rateProvider.fetchRates()
            rates = table
            try rateCache.save(table)
            ratesLog.info("Rates updated for \(table.date.iso, privacy: .public)")
        } catch {
            ratesLog.error("Rates refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
