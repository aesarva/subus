import AppKit
import SwiftUI

enum SettingsTab: Hashable { case general, notifications, categories, paymentMethods, data, about }

@MainActor @Observable
final class SettingsNavigation {
    var tab: SettingsTab = .general
}

@MainActor
final class SettingsWindowController {
    private let model: AppModel
    private let notifier: UserNotifier
    private let closePanel: () -> Void
    private let navigation = SettingsNavigation()
    private var window: NSWindow?

    init(model: AppModel, notifier: UserNotifier, closePanel: @escaping () -> Void) {
        self.model = model
        self.notifier = notifier
        self.closePanel = closePanel
    }

    func show() {
        closePanel()
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(model: model, notifier: notifier, navigation: navigation))
            // The window follows each tab's natural height, so no tab is ever clipped.
            host.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable]
            window.title = String(localized: "Subus Settings")
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
