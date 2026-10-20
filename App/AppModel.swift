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
    /// Logo files the previous save dropped: the backup file still references them until the next save.
    @ObservationIgnored private var pendingLogoDeletions: Set<String> = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var rateTimer: Timer?
    @ObservationIgnored private var ratesRefreshing = false
    @ObservationIgnored private(set) var replanCount = 0

    @ObservationIgnored private let store: SubscriptionStore
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let rateProvider: RateProvider
    @ObservationIgnored private let rateCache: RateCache
    @ObservationIgnored private let notifier: UserNotifier
    /// Small app state that outlives a launch: catch-up reminders not yet delivered, logo files awaiting deletion.
    @ObservationIgnored private let stateStorage: SettingsStorage
    @ObservationIgnored let logosDirectory: URL?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "store")
    @ObservationIgnored private let ratesLog = Logger(subsystem: "io.github.aesarva.Subus", category: "rates")
    @ObservationIgnored private let remindersLog = Logger(subsystem: "io.github.aesarva.Subus", category: "reminders")

    init(store: SubscriptionStore, settingsStore: SettingsStore, rateProvider: RateProvider, rateCache: RateCache,
         notifier: UserNotifier, logosDirectory: URL? = nil,
         stateStorage: SettingsStorage = UserDefaultsSettingsStorage(), now: @escaping () -> Date = Date.init) {
        self.store = store
        self.settingsStore = settingsStore
        self.rateProvider = rateProvider
        self.rateCache = rateCache
        self.notifier = notifier
        self.logosDirectory = logosDirectory
        self.stateStorage = stateStorage
        self.now = now
        settings = settingsStore.load()
        pendingLogoDeletions = Set(Self.decode([String].self, stateStorage.data(forKey: Self.logoPurgeKey)) ?? [])
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

    /// The data folder: the logos directory lives inside it.
    var dataDirectory: URL? { logosDirectory?.deletingLastPathComponent() }

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
        observers.append(center.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                NSTimeZone.resetSystemTimeZone()
                self?.timeMayHaveChanged()
            }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.timeMayHaveChanged() }
        })
        rateTimer = Timer.scheduledTimer(withTimeInterval: 12 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshRatesIfNeeded() }
        }
        rateTimer?.tolerance = 600
        // A catch-up planned just before the last quit still fires: the first plan carries it over.
        let date = now()
        carriedCatchUps = (Self.decode([PlannedReminder].self, stateStorage.data(forKey: Self.catchUpsKey)) ?? [])
            .filter { $0.isCatchUp && $0.fireDate > date }
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
        let ok = commit(justSaved: Self.changedIDs(from: library, to: library.upserting(s))) { $0.upsert(s) }
        if ok { Task { await requestAuthorizationIfNeeded() } }
        return ok
    }

    @discardableResult
    func delete(_ id: UUID) -> Bool {
        commit(mutating: { $0.remove(subscriptionID: id) })
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
    func replaceLibrary(_ l: Library, justSaved: Set<UUID>? = nil) -> Bool {
        let old = library
        let ok = commit(justSaved: justSaved ?? Self.changedIDs(from: old, to: l)) { $0 = l }
        // An import that brings subscriptions asks for notifications, as the first save does.
        if ok, !Set(l.subscriptions.map(\.id)).isSubset(of: old.subscriptions.map(\.id)) {
            Task { await requestAuthorizationIfNeeded() }
        }
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
        let old = library
        library = copy
        saveError = nil
        purgeLogoFiles(replaced: old)
        replan(justSaved: justSaved)
        return true
    }

    private static func logoFileNames(_ library: Library) -> Set<String> {
        Set(library.subscriptions.compactMap { s -> String? in
            switch s.logo {
            case .image(let name), .siteIcon(let name): name
            case .monogram: nil
            }
        })
    }

    /// Deletes logo files one save late: what a save drops is still referenced by the backup it wrote,
    /// so a file goes only once neither the main file nor the backup (the library just replaced) names it.
    private func purgeLogoFiles(replaced old: Library) {
        let oldNames = Self.logoFileNames(old), newNames = Self.logoFileNames(library)
        if let logosDirectory {
            for name in pendingLogoDeletions where !oldNames.contains(name) && !newNames.contains(name)
                && Logo.isSafeFileName(name) {
                try? FileManager.default.removeItem(at: logosDirectory.appendingPathComponent(name))
            }
        }
        pendingLogoDeletions = oldNames.subtracting(newNames)
        persist(pendingLogoDeletions.sorted(), key: Self.logoPurgeKey)
    }

    private static let catchUpsKey = "catchups.v1"
    private static let logoPurgeKey = "logoPurge.v1"

    private func persist<T: Encodable>(_ value: T, key: String) {
        do {
            stateStorage.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            log.error("State write failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private static func changedIDs(from old: Library, to new: Library) -> Set<UUID> {
        let before = Dictionary(old.subscriptions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return Set(new.subscriptions.filter { before[$0.id] != $0 }.map(\.id))
    }

    // MARK: Reminders

    func replan(justSaved: Set<UUID> = []) {
        if unreadableMessage != nil {
            remindersLog.info("Replan skipped: data is unreadable")
            return
        }
        let plan = ReminderPlanner.plan(library: library, settings: settings, now: now(), calendar: .subus(),
                                        justSaved: justSaved, carriedCatchUps: carriedCatchUps)
        carriedCatchUps = plan.filter(\.isCatchUp)
        persist(carriedCatchUps, key: Self.catchUpsKey)
        replanCount += 1
        remindersLog.info("Replan #\(self.replanCount): \(plan.count) reminders")
        notifier.replaceAll(plan, library: library, now: now())
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
        guard !ratesRefreshing, RateRefreshPolicy.needsRefresh(cached: rates, now: now()) else { return }
        ratesRefreshing = true
        defer { ratesRefreshing = false }
        do {
            let table = try await rateProvider.fetchRates()
            rates = table
            ratesLog.info("Rates updated for \(table.date.iso, privacy: .public)")
            do { try rateCache.save(table) } catch {
                ratesLog.error("Rates cache write failed: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            ratesLog.error("Rates refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private extension Library {
    func upserting(_ s: Subscription) -> Library {
        var copy = self
        copy.upsert(s)
        return copy
    }
}
