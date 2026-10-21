import AppKit
import SubusCore
import SwiftUI

/// Which list the side pane shows: the selected cell's charges, or every subscription.
enum YearPane: Hashable { case period, all }

/// Year window state. The mode survives relaunches (`yearMode` in `UserDefaults`); the filter,
/// the selected cell, the pane, the sort and the pushed pages live while the window is open.
@MainActor @Observable
final class YearState {
    static let modeKey = "yearMode"

    var mode: YearMode {
        didSet { if mode != oldValue { defaults.set(mode.rawValue, forKey: Self.modeKey) } }
    }
    var filter = YearFilter()
    /// The selected cell by its start date; nil — the current week or month.
    var selection: LocalDate?
    var pane: YearPane = .period
    var sort: YearSort = .total
    /// Subscription pages pushed over the year.
    var path: [UUID] = []
    /// Bumped when the system locale changes: `firstWeekday` and every formatter depend on it.
    var localeTick = 0
    /// The window's width, from which the toolbar works out how many category chips fit.
    var windowWidth: CGFloat = 1100
    /// The plan and rows of the last inputs, so selecting a cell does not build the year again.
    @ObservationIgnored let cache = YearPlanCache()

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = defaults.string(forKey: Self.modeKey).flatMap(YearMode.init(rawValue:)) ?? .weeks
    }

    /// Pushes or pops subscription pages; under Reduce Motion without the push animation.
    func navigate(reduceMotion: Bool, _ change: (YearState) -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = reduceMotion
        withTransaction(transaction) { change(self) }
    }

    /// The next opening starts over, in the remembered mode.
    func reset() {
        filter = YearFilter()
        selection = nil
        pane = .period
        sort = .total
        path = []
    }
}

/// The one Year window: a resizable `NSWindow` whose SwiftUI content drives its own toolbar and title.
/// While it is open the app keeps its Dock icon.
@MainActor
final class YearWindowController: NSObject, NSWindowDelegate {
    private static let autosaveName = "YearWindow"

    private let model: AppModel
    private let closePanel: () -> Void
    private let onEdit: (UUID) -> Void
    private let onAdd: () -> Void
    private let state = YearState()
    private var localeObserver: NSObjectProtocol?
    private(set) var window: NSWindow?

    init(model: AppModel, closePanel: @escaping () -> Void, onEdit: @escaping (UUID) -> Void,
         onAdd: @escaping () -> Void) {
        self.model = model
        self.closePanel = closePanel
        self.onEdit = onEdit
        self.onAdd = onAdd
        super.init()
        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.state.localeTick += 1 }
        }
    }

    var isOpen: Bool { window?.isVisible ?? false }

    func windowWillClose(_ notification: Notification) { state.reset() }

    func show() {
        closePanel()
        if window == nil {
            let host = NSHostingController(rootView: YearView(model: model, state: state, onEdit: onEdit, onAdd: onAdd))
            // The window, not the content, owns the size; SwiftUI owns the title and the toolbar.
            host.sizingOptions = []
            host.sceneBridgingOptions = [.title, .toolbars]
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.title = String(localized: "Year")
            window.contentMinSize = NSSize(width: 960, height: 600)
            window.setContentSize(NSSize(width: 1100, height: 720))
            window.isReleasedWhenClosed = false
            window.identifier = DockPresence.identifier
            if !window.setFrameUsingName(Self.autosaveName) { window.center() }
            window.setFrameAutosaveName(Self.autosaveName)
            self.window = window
            window.delegate = self
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
