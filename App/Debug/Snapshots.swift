#if DEBUG
import AppKit
import SubusCore
import SwiftUI

/// `-Snapshots`: renders panel states with demo data to PNGs at 2× and prints the folder.
/// Language follows the launch (`-AppleLanguages "(ru)"` for Russian).
@MainActor
enum Snapshots {
    static func run() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let language = Bundle.main.preferredLocalizations.first == "ru" ? "ru" : "en"
        let today = LocalDate.today(now: Date(), calendar: .subus())

        let demo = model(PreviewSupport.demoLibrary(today: today), in: directory)
        let resting = PanelState()
        resting.notificationsBannerDismissed = true
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            render(PanelRoot(model: demo, state: resting, actions: PanelActions()), appearance: appearance,
                   to: directory.appendingPathComponent("upcoming-\(name)-\(language).png"))
        }

        let selected = PanelState()
        selected.notificationsBannerDismissed = true
        selected.moveSelection(by: 1, in: UpcomingTab.keys(demo))
        selected.moveSelection(by: 1, in: UpcomingTab.keys(demo))
        render(PanelRoot(model: demo, state: selected, actions: PanelActions()), appearance: .darkAqua,
               to: directory.appendingPathComponent("selected-dark-\(language).png"))

        let empty = model(Library.initial(categoryNames: AppModel.defaultCategoryNames()), in: directory)
        render(PanelRoot(model: empty, state: PanelState(), actions: PanelActions()), appearance: .aqua,
               to: directory.appendingPathComponent("empty-light-\(language).png"))

        let corrupt = directory.appendingPathComponent("subscriptions.corrupt-demo.json")
        let troubled = model(PreviewSupport.demoLibrary(today: today), in: directory,
                             recovery: .restoredFromBackup(corruptFile: corrupt), failingSaves: true)
        if let first = troubled.library.subscriptions.first { troubled.save(first) }
        render(PanelRoot(model: troubled, state: PanelState(), actions: PanelActions()), appearance: .aqua,
               to: directory.appendingPathComponent("banners-light-\(language).png"))

        func shot(_ library: Library, _ name: String, quiet: Bool = true, appearance: NSAppearance.Name = .aqua) {
            let state = PanelState()
            state.notificationsBannerDismissed = quiet
            render(PanelRoot(model: model(library, in: directory), state: state, actions: PanelActions()),
                   appearance: appearance, to: directory.appendingPathComponent("\(name)-\(language).png"))
        }
        let base = PreviewSupport.demoLibrary(today: today)
        /// The demo's first subscription (a trial) moved so its first charge falls `days` from today.
        func trial(in days: Int, name: String? = nil) -> Library {
            var library = base
            library.subscriptions[0].trialEndDate = today.adding(days: days)
            if let name { library.subscriptions[0].name = name }
            return library
        }
        shot(trial(in: 0), "next-today-light")
        shot(trial(in: 0), "next-today-dark", appearance: .darkAqua)
        shot(trial(in: 1), "next-tomorrow-light")
        shot(trial(in: 3, name: "Яндекс Практикум — курс «Продуктовый дизайнер»"), "longname-light")
        shot(base, "notifications-light", quiet: false)

        var paused = base
        for i in paused.subscriptions.indices { paused.subscriptions[i].isActive = false }
        shot(paused, "paused-light")

        var distant = Library.initial(categoryNames: AppModel.defaultCategoryNames())
        var yearly = Subscription(name: "1Password", price: Money(Decimal(string: "35.88")!, "USD"), cycle: .yearly,
                                  startDate: today.adding(days: 100).adding(months: -12))
        yearly.categoryID = distant.categories[0].id
        distant.subscriptions = [yearly]
        shot(distant, "quiet-light")

        // All
        func panel(_ model: AppModel, _ name: String, appearance: NSAppearance.Name = .aqua, maxHeight: CGFloat = 640,
                   sheet: Bool = false, _ configure: (PanelState) -> Void) {
            let state = PanelState()
            state.notificationsBannerDismissed = true
            state.maxHeight = maxHeight
            configure(state)
            render(PanelRoot(model: model, state: state, actions: PanelActions()), appearance: appearance,
                   to: directory.appendingPathComponent("\(name)-\(language).png"),
                   sheetTo: sheet ? directory.appendingPathComponent("\(name)-sheet-\(language).png") : nil)
        }
        panel(demo, "all-light") { $0.tab = .all }
        panel(demo, "all-dark", appearance: .darkAqua) { $0.tab = .all }
        panel(demo, "all-search-noresults-light") { $0.tab = .all; $0.search = "Disney" }
        panel(demo, "all-search-net-light") { $0.tab = .all; $0.search = "net" }
        let other = demo.library.categories.first { $0.name == String(localized: "Other") }?.id
        panel(demo, "all-filter-empty-light") { $0.tab = .all; $0.categoryFilter = other }
        let entertainment = demo.library.categories[1].id
        panel(demo, "all-filter-light") { $0.tab = .all; $0.categoryFilter = entertainment }
        panel(demo, "all-inactive-expanded-light", maxHeight: 900) { $0.tab = .all; $0.inactiveExpanded = true }
        panel(demo, "all-selected-dark", appearance: .darkAqua) {
            $0.tab = .all
            $0.moveAllSelection(by: 1, in: AllTab.rows(demo, $0).order)
            $0.moveAllSelection(by: 1, in: AllTab.rows(demo, $0).order)
        }

        // Spending
        panel(demo, "spending-light", maxHeight: 900) { $0.tab = .spending }
        panel(demo, "spending-dark", appearance: .darkAqua, maxHeight: 900) { $0.tab = .spending }
        panel(demo, "spending-selected-dark", appearance: .darkAqua, maxHeight: 900) {
            $0.tab = .spending
            $0.moveSpendingSelection(by: 1, in: SpendingTab.keys(demo))
        }
        var single = base
        for i in single.subscriptions.indices { single.subscriptions[i].categoryID = single.categories[1].id }
        panel(model(single, in: directory), "spending-single-category-light", maxHeight: 900) { $0.tab = .spending }
        var cashless = base
        cashless.paymentMethods = []
        for i in cashless.subscriptions.indices { cashless.subscriptions[i].paymentMethodID = nil }
        panel(model(cashless, in: directory), "spending-no-payment-light", maxHeight: 900) { $0.tab = .spending }
        var steady = base
        for i in steady.subscriptions.indices {
            steady.subscriptions[i].priceHistory = [PriceChange(effectiveFrom: steady.subscriptions[i].startDate,
                                                                price: steady.subscriptions[i].price)]
        }
        // One subscription with neither a category nor a method: its bars ride the rail colour.
        if let i = steady.subscriptions.firstIndex(where: { $0.name == "YouTube Premium" }) {
            steady.subscriptions[i].categoryID = nil
            steady.subscriptions[i].paymentMethodID = nil
        }
        panel(model(steady, in: directory), "spending-no-increases-light", maxHeight: 900) { $0.tab = .spending }

        // Card
        func id(_ model: AppModel, _ name: String) -> UUID {
            model.library.subscriptions.first { $0.name == name }!.id
        }
        panel(demo, "card-light", maxHeight: 900) { $0.card = id(demo, "Яндекс Плюс") }
        panel(demo, "card-trial-dark", appearance: .darkAqua, maxHeight: 900) { $0.card = id(demo, "ChatGPT Plus") }
        panel(demo, "card-noupcoming-light", maxHeight: 900) { $0.card = id(demo, "Notion") }
        panel(demo, "card-ended-light", maxHeight: 900) { $0.card = id(demo, "Кинопоиск") }
        panel(demo, "card-yearly-light", maxHeight: 900) { $0.card = id(demo, "1Password") }
        panel(demo, "card-delete-confirm-light", maxHeight: 900, sheet: true) {
            $0.card = id(demo, "Spotify")
            $0.confirmingDelete = true
        }
        let refusing = model(PreviewSupport.demoLibrary(today: today), in: directory, failingSaves: true)
        refusing.setActive(id(refusing, "Spotify"), false)
        panel(refusing, "card-toggle-failed-light", maxHeight: 900) { $0.card = id(refusing, "Spotify") }

        // Editor
        func editorShot(_ name: String, editing: Subscription? = nil, appearance: NSAppearance.Name = .aqua,
                        height: CGFloat = 900, _ configure: (EditorState) -> Void = { _ in }) {
            let editorModel = model(PreviewSupport.demoLibrary(today: today), in: directory)
            let subscription = editing.flatMap { e in editorModel.library.subscriptions.first { $0.name == e.name } }
            let state = EditorState(model: editorModel, editing: subscription)
            configure(state)
            renderEditor(state, appearance: appearance, height: height,
                         to: directory.appendingPathComponent("\(name)-\(language).png"))
        }
        editorShot("editor-new-light") { $0.draft.name = "Spotify"; $0.draft.priceText = "169,00" }
        editorShot("editor-new-dark", appearance: .darkAqua)
        editorShot("editor-edit-light", editing: demo.library.subscriptions.first { $0.name == "Яндекс Плюс" }) {
            $0.draft.priceText = "449"
        }
        editorShot("editor-errors-light") {
            $0.draft.priceText = "abc"
            $0.draft.websiteText = "not a url"
            $0.setTrial(true)
            $0.draft.trialEndDate = $0.draft.startDate.adding(days: -3)
            $0.save()
        }

        // Settings
        func settingsShot(_ name: String, _ tab: SettingsTab, appearance: NSAppearance.Name = .aqua) {
            let navigation = SettingsNavigation()
            navigation.tab = tab
            let settingsModel = model(PreviewSupport.demoLibrary(today: today), in: directory)
            renderWindow(SettingsView(model: settingsModel, notifier: UserNotifier(), navigation: navigation),
                         width: SettingsView.width, appearance: appearance,
                         to: directory.appendingPathComponent("\(name)-\(language).png"))
        }
        settingsShot("settings-general-light", .general)
        settingsShot("settings-notifications-light", .notifications)
        settingsShot("settings-categories-dark", .categories, appearance: .darkAqua)
        settingsShot("settings-data-light", .data)
        settingsShot("settings-about-light", .about)
        var imported = ImportPreview(library: demo.library)
        imported.errors = [ImportRowError(line: 4, field: "price"), ImportRowError(line: 9, field: "start_date")]
        renderWindow(ImportPreviewView(preview: imported, onAdd: {}, onReplace: {}, onCancel: {}),
                     width: 520, appearance: .aqua,
                     to: directory.appendingPathComponent("import-preview-light-\(language).png"))

        print(directory.path)
    }

    private static func renderWindow<Content: View>(_ content: Content, width: CGFloat, appearance: NSAppearance.Name,
                                                    to url: URL) {
        let host = NSHostingView(rootView: content.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: width, height: 400),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            window.setContentSize(NSSize(width: width, height: host.fittingSize.height))
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
        write(host, to: url)
        window.orderOut(nil)
    }

    private static func renderEditor(_ state: EditorState, appearance: NSAppearance.Name, height: CGFloat, to url: URL) {
        let host = NSHostingView(rootView: EditorView(state: state))
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: EditorView.width, height: height),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        }
        write(host, to: url)
        window.orderOut(nil)
    }

    private static func model(_ library: Library, in directory: URL, recovery: Recovery? = nil,
                              failingSaves: Bool = false) -> AppModel {
        let storage = MemorySettingsStorage()
        let settingsStore = SettingsStore(storage: storage, locale: .current)
        var settings = AppSettings.defaults(locale: .current)
        settings.baseCurrency = "RUB"
        settingsStore.save(settings)

        let ratesURL = directory.appendingPathComponent("rates.json")
        let today = LocalDate.today(now: Date(), calendar: .subus())
        try? RateCache(fileURL: ratesURL).save(RateTable(
            date: today, rubPerUnit: ["RUB": 1, "USD": Decimal(string: "81.6")!, "EUR": Decimal(string: "94.3")!],
            fetchedAt: Date()))
        return AppModel(store: MemoryStore(result: LoadResult(library: library, recovery: recovery), failing: failingSaves),
                        settingsStore: settingsStore, rateProvider: NoRates(), rateCache: RateCache(fileURL: ratesURL),
                        notifier: UserNotifier(), logosDirectory: directory.appendingPathComponent("Logos"))
    }

    /// Draws on the opaque ground the system gives the popover under Reduce Transparency.
    private static func render(_ root: PanelRoot, appearance: NSAppearance.Name, to url: URL, sheetTo sheetURL: URL? = nil) {
        let dark = appearance == .darkAqua
        let host = NSHostingView(rootView: root.background(Color(hex: dark ? 0x1C1C1E : 0xF6F6F3)))
        host.appearance = NSAppearance(named: appearance)
        let window = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: PanelRoot.width, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        window.orderFrontRegardless()
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            let size = host.fittingSize
            window.setContentSize(NSSize(width: PanelRoot.width, height: size.height))
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        }
        write(host, to: url)
        if let sheetURL {
            if let sheet = window.attachedSheet, let content = sheet.contentView {
                write(content, to: sheetURL)
                window.endSheet(sheet)
            } else {
                print("no sheet attached for \(sheetURL.lastPathComponent)")
            }
        }
        window.orderOut(nil)
    }

    private static func write(_ view: NSView, to url: URL) {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2),
                                         pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}

private final class MemorySettingsStorage: SettingsStorage, @unchecked Sendable {
    private var values: [String: Data] = [:]
    func data(forKey key: String) -> Data? { values[key] }
    func set(_ data: Data, forKey key: String) { values[key] = data }
}

private struct MemoryStore: SubscriptionStore {
    struct Refused: LocalizedError {
        var errorDescription: String? { "The disk is full (demo)." }
    }
    let result: LoadResult
    let failing: Bool
    func load() throws -> LoadResult { result }
    func save(_ library: Library) throws { if failing { throw Refused() } }
}

private struct NoRates: RateProvider {
    struct Offline: Error {}
    func fetchRates() async throws -> RateTable { throw Offline() }
}
#endif
