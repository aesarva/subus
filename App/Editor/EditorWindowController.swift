import AppKit
import SubusCore
import SwiftUI

/// One window per subscription; "New subscription" has its own single slot.
@MainActor
final class EditorWindowController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let closePanel: () -> Void
    private var windows: [UUID?: NSWindow] = [:]

    init(model: AppModel, closePanel: @escaping () -> Void) {
        self.model = model
        self.closePanel = closePanel
    }

    func open(editing subscription: Subscription?) {
        closePanel()
        let key = subscription?.id
        if let window = windows[key] {
            bringForward(window)
            return
        }
        let state = EditorState(model: model, editing: subscription)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: EditorView.width, height: 700),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = subscription.map { String(localized: "Edit “\($0.name)”") } ?? String(localized: "New Subscription")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: EditorView(state: state, onCancel: { [weak window] in window?.close() }))
        window.setContentSize(NSSize(width: EditorView.width, height: 700))
        window.contentMinSize = NSSize(width: EditorView.width, height: 420)
        window.contentMaxSize = NSSize(width: EditorView.width, height: 1100)
        state.onSaved = { [weak window] in window?.close() }
        window.center()
        windows[key] = window
        bringForward(window)
    }

    private func bringForward(_ window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let key = windows.first(where: { $0.value === window })?.key else { return }
        windows[key] = nil
    }
}
