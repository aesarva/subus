import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let notifier: UserNotifier
    private let updates: UpdateController
    private let closePanel: () -> Void
    private(set) var window: NSWindow?

    init(model: AppModel, notifier: UserNotifier, updates: UpdateController, closePanel: @escaping () -> Void) {
        self.model = model
        self.notifier = notifier
        self.updates = updates
        self.closePanel = closePanel
        super.init()
    }

    /// A name still being typed commits when the window goes away.
    func windowWillClose(_ notification: Notification) { commitEditing() }

    var isOpen: Bool { window?.isVisible ?? false }

    func commitEditing() { window?.makeFirstResponder(nil) }

    func show() {
        closePanel()
        if window == nil {
            let tabs = SettingsView.makeTabs(model: model, notifier: notifier, updates: updates)
            let window = NSWindow(contentViewController: tabs)
            window.styleMask = [.titled, .closable]
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.identifier = DockPresence.identifier
            window.center()
            self.window = window
            window.delegate = self
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
