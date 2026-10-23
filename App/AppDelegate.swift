import AppKit
import OSLog
import SubusCore
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let launchArgs = ProcessInfo.processInfo.arguments

    private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "ui")
    private let notifier = UserNotifier()
    private var model: AppModel!
    private var statusItem: StatusItemController!
    private var panel: PanelController!
    private var editor: EditorWindowController!
    private var settings: SettingsWindowController!
    private var year: YearWindowController!
    private var updates: UpdateController!
    private var dockPresence: DockPresence?

    @objc func newSubscription() { editor?.open(editing: nil) }
    @objc func openSettings() { settings?.show() }
    @objc func openYear() { year?.show() }

    /// A Dock click with none of our windows on screen: restores a minimised one, else opens the Year window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let ours = NSApp.windows.filter { $0.identifier == DockPresence.identifier }
        if ours.contains(where: \.isVisible) { return false }
        if let minimised = ours.last(where: \.isMiniaturized) { minimised.deminiaturize(nil) } else { openYear() }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard settings?.isOpen == true else { return .terminateNow }
        // Lets a rename still being typed commit before the app goes.
        settings.commitEditing()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().delegate = notifier
        notifier.registerCategories()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if Self.launchArgs.contains("-Snapshots") {
            Snapshots.run()
            exit(0)
        }
        #endif

        model = makeModel()
        dockPresence = DockPresence()
        notifier.onOpen = { [weak model] id in model?.openSubscriptionRequest = id }

        // Debug arguments come only from the command line (argument domain), never from saved defaults.
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        updates = UpdateController(feedOverride: arguments["UpdateFeedURL"] as? String,
                                   autoInstall: (arguments["UpdateAutoInstall"] as? String) == "YES") { [weak self] in
            self?.panel.show(subscription: nil)
        }
        editor = EditorWindowController(model: model, closePanel: { [weak self] in self?.panel.close() })
        let onAdd: () -> Void = { [weak self] in self?.editor.open(editing: nil) }
        settings = SettingsWindowController(model: model, notifier: notifier, updates: updates,
                                            closePanel: { [weak self] in self?.panel.close() })
        let onSettings: () -> Void = { [weak self] in self?.settings.show() }
        let onEdit: (UUID) -> Void = { [weak self] id in
            guard let self, let s = model.library.subscriptions.first(where: { $0.id == id }) else { return }
            editor.open(editing: s)
        }
        year = YearWindowController(model: model, closePanel: { [weak self] in self?.panel.close() },
                                    onEdit: onEdit, onAdd: onAdd)
        let onYear: () -> Void = { [weak self] in self?.year.show() }
        statusItem = StatusItemController(
            onTogglePanel: { [weak self] in self?.panel.toggle() },
            onAdd: onAdd,
            onYear: onYear,
            onSettings: onSettings
        )
        panel = PanelController(model: model, updates: updates, anchor: { [weak self] in self?.statusItem.button },
                                onAdd: onAdd, onYear: onYear, onSettings: onSettings, onEdit: onEdit)
        refreshStatusItem()
        observeOpenRequests()

        #if DEBUG
        let args = Self.launchArgs
        if args.contains("-SeedDemoData"), model.library.subscriptions.isEmpty {
            model.replaceLibrary(PreviewSupport.demoLibrary(today: model.today))
        }
        #endif
        model.start()
        updates.start()
        #if DEBUG
        if args.contains("-OpenPanelOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.panel.toggle() }
        }
        if args.contains("-OpenEditorOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.editor.open(editing: nil) }
        }
        if args.contains("-OpenYearOnLaunch") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.year.show() }
        }
        if args.contains("-SendTestNotification") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [notifier] in notifier.sendTest() }
        }
        #endif
    }

    private func makeModel() -> AppModel {
        let settingsStore = SettingsStore(storage: UserDefaultsSettingsStorage(), locale: .current)
        let rateProvider = CBRRateProvider(http: URLSessionHTTPClient())
        let base: URL
        do {
            base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        } catch {
            log.fault("Application Support is unavailable: \(error.localizedDescription, privacy: .public)")
            return AppModel(store: UnavailableStore(), settingsStore: settingsStore, rateProvider: rateProvider,
                            rateCache: RateCache(fileURL: URL(fileURLWithPath: "/dev/null/rates.json")),
                            notifier: notifier)
        }
        let directory = base.appendingPathComponent("Subus", isDirectory: true)
        let logos = directory.appendingPathComponent("Logos", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: logos, withIntermediateDirectories: true)
        } catch {
            log.error("Could not create data directory: \(error.localizedDescription, privacy: .public)")
        }
        return AppModel(
            store: JSONFileStore(directory: directory,
                                 initial: { Library.initial(categoryNames: AppModel.defaultCategoryNames()) }),
            settingsStore: settingsStore,
            rateProvider: rateProvider,
            rateCache: RateCache(fileURL: directory.appendingPathComponent("rates.json")),
            notifier: notifier,
            logosDirectory: logos
        )
    }

    /// A notification click asks for a subscription: the panel opens on its card and the request is spent.
    private func observeOpenRequests() {
        let id = withObservationTracking {
            model.openSubscriptionRequest
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeOpenRequests() }
        }
        guard let id else { return }
        panel.show(subscription: id)
        model.openSubscriptionRequest = nil
    }

    /// Re-runs whenever the observed model state changes.
    private func refreshStatusItem() {
        let state = withObservationTracking {
            (model.settings.showMenuBarCounter ? model.daysToNearest : nil, model.nearestCharge?.0.name,
             updates.showsBadge)
        } onChange: { [weak self] in
            Task { @MainActor in self?.refreshStatusItem() }
        }
        guard let days = state.0 else {
            statusItem.update(counterText: nil, accent: false, badge: state.2)
            return
        }
        let label = String(localized: "Subus, next charge \(Formatters.relativeDays(days)): \(state.1 ?? "")")
        statusItem.update(counterText: Formatters.counter(days), accent: days <= 1, badge: state.2,
                          accessibilityLabel: label)
    }
}

/// Stands in when there is no data directory: loading fails, so the model blocks every write.
private struct UnavailableStore: SubscriptionStore {
    struct Unavailable: Error {}
    func load() throws -> LoadResult { throw Unavailable() }
    func save(_ library: Library) throws { throw Unavailable() }
}
