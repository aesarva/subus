#if DEBUG
import AppKit
import SubusCore
import SwiftUI

/// `-Snapshots`: renders every panel/editor/settings state and the status item with demo data, in light and dark,
/// to PNGs at 2× (`<state>-<light|dark>-<en|ru>.png`) and prints the folder. The language follows the launch
/// (`-AppleLanguages "(ru)"`); `make snapshots` runs both languages and collects the files.
@MainActor
enum Snapshots {
    static func run() {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let language = Bundle.main.preferredLocalizations.first == "ru" ? "ru" : "en"
        let today = LocalDate.today(now: Date(), calendar: .subus())
        let base = PreviewSupport.demoLibrary(today: today)

        /// Runs `body` once per theme with the target file for that theme.
        func each(_ name: String, _ body: (NSAppearance.Name, URL) -> Void) {
            for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                body(appearance, directory.appendingPathComponent("\(name)-\(theme)-\(language).png"))
            }
        }
        func panel(_ name: String, _ library: Library, maxHeight: CGFloat = 640, quiet: Bool = true,
                   recovery: Recovery? = nil, failingSaves: Bool = false,
                   _ configure: (AppModel, PanelState) -> Void = { _, _ in }) {
            each(name) { appearance, url in
                let appModel = model(library, in: directory, recovery: recovery, failingSaves: failingSaves)
                if failingSaves, let first = appModel.library.subscriptions.first { appModel.save(first) }
                let state = PanelState()
                state.notificationsBannerDismissed = quiet
                state.maxHeight = maxHeight
                configure(appModel, state)
                render(PanelRoot(model: appModel, state: state, actions: PanelActions()), appearance: appearance, to: url)
            }
        }
        /// The demo's first subscription (a trial) moved so its first charge falls `days` from today.
        func trial(in days: Int, name: String? = nil) -> Library {
            var library = base
            library.subscriptions[0].trialEndDate = today.adding(days: days)
            if let name { library.subscriptions[0].name = name }
            return library
        }
        func id(_ model: AppModel, _ name: String) -> UUID {
            model.library.subscriptions.first { $0.name == name }!.id
        }
        let initial = Library.initial(categoryNames: AppModel.defaultCategoryNames())

        // Upcoming
        panel("upcoming", base)
        panel("upcoming-empty", initial, quiet: false)
        panel("next-today", trial(in: 0))
        panel("next-tomorrow", trial(in: 1))
        panel("selected", base) { m, s in
            s.moveSelection(by: 1, in: UpcomingTab.keys(m))
            s.moveSelection(by: 1, in: UpcomingTab.keys(m))
        }
        let corrupt = directory.appendingPathComponent("subscriptions.corrupt-demo.json")
        panel("banners", base, quiet: false, recovery: .restoredFromBackup(corruptFile: corrupt), failingSaves: true)
        panel("notifications-off", base, quiet: false)
        var paused = base
        for i in paused.subscriptions.indices { paused.subscriptions[i].isActive = false }
        panel("paused", paused)
        var distant = initial
        var yearly = Subscription(name: "1Password", price: Money(Decimal(string: "35.88")!, "USD"), cycle: .yearly,
                                  startDate: today.adding(days: 100).adding(months: -12))
        yearly.categoryID = distant.categories[0].id
        distant.subscriptions = [yearly]
        panel("quiet", distant)
        // A long name, and a payment label too long for the date line: the label gives way first.
        var long = trial(in: 3, name: "Яндекс Практикум — курс «Продуктовый дизайнер»")
        long.paymentMethods[1].label = "Revolut Metal •• 0815 (рабочая, общая с семьёй)"
        panel("longname", long)

        // All
        panel("all", base) { _, s in s.tab = .all }
        panel("all-inactive-expanded", base, maxHeight: 900) { _, s in s.tab = .all; s.inactiveExpanded = true }
        panel("all-search-noresults", base) { _, s in s.tab = .all; s.search = "Disney" }

        // Spending
        panel("spending", base, maxHeight: 900) { _, s in s.tab = .spending }
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
        panel("spending-no-increases", steady, maxHeight: 900) { _, s in s.tab = .spending }

        // Card
        panel("card", base, maxHeight: 900) { m, s in s.card = id(m, "Яндекс Плюс") }
        panel("card-trial", base, maxHeight: 900) { m, s in s.card = id(m, "ChatGPT Plus") }
        panel("card-noupcoming", base, maxHeight: 900) { m, s in s.card = id(m, "Notion") }

        // Editor
        func editorShot(_ name: String, editing: String? = nil, _ configure: (EditorState) -> Void = { _ in }) {
            each(name) { appearance, url in
                let editorModel = model(base, in: directory)
                let subscription = editing.flatMap { n in editorModel.library.subscriptions.first { $0.name == n } }
                let state = EditorState(model: editorModel, editing: subscription)
                configure(state)
                renderEditor(state, appearance: appearance, height: 900, to: url)
            }
        }
        editorShot("editor-new") { $0.draft.name = "Spotify"; $0.draft.priceText = "169,00" }
        editorShot("editor-edit", editing: "Яндекс Плюс") { $0.draft.priceText = "449" }
        editorShot("editor-errors") {
            $0.draft.priceText = "abc"
            $0.draft.websiteText = "not a url"
            $0.setTrial(true)
            $0.draft.trialEndDate = $0.draft.startDate.adding(days: -3)
            $0.save()
        }

        // Settings
        func settingsShot(_ name: String, _ tab: SettingsTab) {
            each(name) { appearance, url in
                let navigation = SettingsNavigation()
                navigation.tab = tab
                let settingsModel = model(base, in: directory)
                renderWindow(SettingsView(model: settingsModel, notifier: UserNotifier(), navigation: navigation),
                             width: SettingsView.width, appearance: appearance, to: url)
            }
        }
        settingsShot("settings-general", .general)
        settingsShot("settings-notifications", .notifications)
        settingsShot("settings-categories", .categories)
        settingsShot("settings-payment", .paymentMethods)
        settingsShot("settings-data", .data)
        settingsShot("settings-about", .about)
        var imported = ImportPreview(library: base)
        imported.errors = [ImportRowError(line: 4, field: "price"), ImportRowError(line: 9, field: "start_date")]
        each("import-preview") { appearance, url in
            renderWindow(ImportPreviewView(preview: imported, onAdd: {}, onReplace: {}, onCancel: {}),
                         width: 520, appearance: appearance, to: url)
        }

        // Status item: the glyph alone, "3d", and the accent "1d" and "0d", on a light and a dark menu bar.
        for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let strip = StatusItemStrip(states: [(nil, false), (Formatters.counter(3), false),
                                                 (Formatters.counter(1), true), (Formatters.counter(0), true)])
            strip.appearance = NSAppearance(named: appearance)
            strip.background = appearance == .darkAqua ? NSColor(white: 0x1E / 255, alpha: 1) : NSColor(white: 0xF6 / 255, alpha: 1)
            strip.frame.size = strip.fittingSize
            write(strip, to: directory.appendingPathComponent("statusitem-\(theme)-\(language).png"))
        }

        print(directory.path)
    }

    private static func renderWindow<Content: View>(_ content: Content, width: CGFloat, appearance: NSAppearance.Name,
                                                    to url: URL) {
        let host = NSHostingView(rootView: content.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: appearance)
        let window = KeyWindow(contentRect: NSRect(x: -4000, y: -4000, width: width, height: 400),
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
        let window = KeyWindow(contentRect: NSRect(x: -4000, y: -4000, width: EditorView.width, height: height),
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
                        notifier: UserNotifier(), logosDirectory: directory.appendingPathComponent("Logos"),
                        stateStorage: storage)
    }

    /// Draws on the opaque ground the system gives the popover under Reduce Transparency.
    private static func render(_ root: PanelRoot, appearance: NSAppearance.Name, to url: URL) {
        let dark = appearance == .darkAqua
        let host = NSHostingView(rootView: root.background(Color(hex: dark ? 0x1C1C1E : 0xF6F6F3)))
        host.appearance = NSAppearance(named: appearance)
        let window = KeyWindow(contentRect: NSRect(x: -4000, y: -4000, width: PanelRoot.width, height: 600),
                               styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            let size = host.fittingSize
            window.setContentSize(NSSize(width: PanelRoot.width, height: size.height))
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        }
        write(host, to: url)
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

/// A menu-bar strip with the status item's content (glyph + counter) in each state, drawn as the button lays
/// it out: the 18 pt glyph, then the counter title, both centred on the 24 pt bar.
private final class StatusItemStrip: NSView {
    private let states: [(text: String?, accent: Bool)]
    var background = NSColor.windowBackgroundColor

    private static let barHeight: CGFloat = 24
    private static let padding: CGFloat = 12
    private static let gap: CGFloat = 28

    init(states: [(text: String?, accent: Bool)]) {
        self.states = states
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override var fittingSize: NSSize {
        let content = states.reduce(CGFloat(0)) { sum, state in
            sum + 18 + (state.text.map { Self.title($0, state.accent).size().width } ?? 0)
        }
        return NSSize(width: ceil(content + Self.gap * CGFloat(states.count - 1) + Self.padding * 2), height: Self.barHeight)
    }

    private static func title(_ text: String, _ accent: Bool) -> NSAttributedString {
        StatusItemController.title(text, accent: accent)
    }

    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            background.setFill()
            bounds.fill()
            let icon = MenuBarIcon.image()
            var x = Self.padding
            for state in states {
                icon.draw(in: NSRect(x: x, y: (Self.barHeight - 18) / 2, width: 18, height: 18), from: .zero,
                          operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
                x += 18
                if let text = state.text {
                    let title = Self.title(text, state.accent)
                    let size = title.size()
                    title.draw(at: NSPoint(x: x, y: ((Self.barHeight - size.height) / 2).rounded()))
                    x += size.width
                }
                x += Self.gap
            }
        }
    }
}

/// Borderless windows refuse key status by default; snapshots want active-state control colours.
private final class KeyWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
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
