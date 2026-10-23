import AppKit
import SubusCore
import SwiftUI

/// The Settings tabs, as toolbar items of a standard macOS Settings window.
enum SettingsTab: Hashable, CaseIterable {
    case general, notifications, categories, paymentMethods, data, about

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .notifications: String(localized: "Notifications")
        case .categories: String(localized: "Categories")
        case .paymentMethods: String(localized: "Payment Methods")
        case .data: String(localized: "Data")
        case .about: String(localized: "About")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .notifications: "bell"
        case .categories: "tag"
        case .paymentMethods: "creditcard"
        case .data: "externaldrive"
        case .about: "info.circle"
        }
    }
}

/// The Settings window's content: one native toolbar tab per `SettingsTab`, like Safari's or Mail's. A SwiftUI
/// `TabView` in a plain window draws the old segmented switch over an inset ground instead.
@MainActor
enum SettingsView {
    static let width: CGFloat = 540

    static func makeTabs(model: AppModel, notifier: UserNotifier, updates: UpdateController,
                         selected: SettingsTab = .general) -> NSTabViewController {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let host = NSHostingController(rootView: content(tab, model: model, notifier: notifier, updates: updates)
                .frame(width: width)
                .fixedSize(horizontal: false, vertical: true))
            // The window follows each tab's natural height, so no tab is ever clipped.
            host.sizingOptions = [.preferredContentSize]
            // The window takes the selected tab's title.
            host.title = tab.title
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            tabs.addTabViewItem(item)
        }
        tabs.selectedTabViewItemIndex = SettingsTab.allCases.firstIndex(of: selected) ?? 0
        return tabs
    }

    /// Forms keep the grouped style's own margins; the lists and About get the window's 20 pt.
    @ViewBuilder
    private static func content(_ tab: SettingsTab, model: AppModel, notifier: UserNotifier,
                                updates: UpdateController) -> some View {
        switch tab {
        case .general: GeneralTab(model: model, updates: updates)
        case .notifications: NotificationsTab(model: model, notifier: notifier)
        case .categories: CategoriesTab(model: model).padding(20)
        case .paymentMethods: PaymentMethodsTab(model: model).padding(20)
        case .data: DataTab(model: model)
        case .about: AboutTab().padding(20)
        }
    }
}

extension AppModel {
    /// Applies an edit to a copy of the library (no catch-up reminders); returns the error text on failure.
    func editLibrary(_ change: (inout Library) -> Void) -> String? {
        var copy = library
        change(&copy)
        return replaceLibrary(copy, justSaved: []) ? nil : (saveError ?? String(localized: "Couldn't save changes."))
    }

    /// Writes one settings change; every change replans the reminders.
    func update(_ change: (inout AppSettings) -> Void) {
        var copy = settings
        change(&copy)
        guard copy != settings else { return }
        updateSettings(copy)
    }
}
