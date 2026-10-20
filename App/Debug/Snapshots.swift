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

        print(directory.path)
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
    private static func render(_ root: PanelRoot, appearance: NSAppearance.Name, to url: URL) {
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
        let size = host.bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2),
                                         pixelsHigh: Int(size.height * 2), bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        window.orderOut(nil)
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
