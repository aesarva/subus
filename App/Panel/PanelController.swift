import AppKit
import SwiftUI

/// The menu-bar panel: a transient `NSPopover` whose height follows its SwiftUI content.
@MainActor
final class PanelController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let anchor: () -> NSStatusBarButton?
    private let onAdd: () -> Void
    private let onSettings: () -> Void
    private let state = PanelState()
    private let popover = NSPopover()
    private var host: NSHostingController<PanelRoot>!
    private var keyMonitor: Any?
    private var moveMonitor: Any?
    private var clickMonitor: Any?
    /// A click on the status item first closes the transient popover, then fires the button:
    /// that click means "close", not "reopen".
    private var closedAt = Date.distantPast

    init(model: AppModel, anchor: @escaping () -> NSStatusBarButton?,
         onAdd: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.model = model
        self.anchor = anchor
        self.onAdd = onAdd
        self.onSettings = onSettings
        super.init()
        let actions = PanelActions(
            onAdd: { [weak self] in self?.onAdd() },
            onSettings: { [weak self] in self?.onSettings() },
            onOpen: { [weak self] id in self?.show(subscription: id) })
        host = NSHostingController(rootView: PanelRoot(model: model, state: state, actions: actions))
        // The hosting controller publishes the SwiftUI ideal size as preferredContentSize,
        // and the popover's contentSize follows it as the content changes.
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    var isShown: Bool { popover.isShown }

    func toggle() {
        if popover.isShown {
            close()
        } else if Date().timeIntervalSince(closedAt) > 0.3 {
            open()
        }
    }

    /// Opens the panel; the subscription card arrives with Task 17, until then the charge is selected.
    func show(subscription id: UUID?) {
        if !popover.isShown { open() }
        guard let id, state.selection?.subscriptionID != id else { return }
        if let key = UpcomingTab.keys(model).first(where: { $0.subscriptionID == id }) {
            state.selection = key
        }
    }

    func close() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    private func open() {
        guard let button = anchor() else { return }
        removeMonitors()
        let screen = button.window?.screen ?? NSScreen.main
        state.maxHeight = max(320, (screen?.visibleFrame.height ?? 800) - 80)
        // Size before showing, so the first frame is already the content's height.
        fit(host.sizeThatFits(in: CGSize(width: PanelRoot.width, height: .greatestFiniteMagnitude)))
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = host.view.window {
            // The popover window is a non-activating panel: making it key keeps glass and controls active.
            window.makeKey()
            window.makeFirstResponder(host.view)
            window.acceptsMouseMovedEvents = true
        }
        Task { await model.refreshAuthorization() }
        installMonitors()
    }

    private func fit(_ size: CGSize) {
        let target = NSSize(width: PanelRoot.width, height: ceil(size.height))
        guard target.height > 0, popover.contentSize != target else { return }
        popover.contentSize = target
    }

    func popoverDidClose(_ notification: Notification) {
        closedAt = Date()
        state.clearPointer()
        removeMonitors()
    }

    // MARK: Keyboard

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let key = Key(code: event.keyCode,
                          modifiers: event.modifierFlags.intersection([.command, .shift, .option, .control]),
                          windowNumber: event.windowNumber)
            let consumed = MainActor.assumeIsolated { self?.handle(key) ?? false }
            return consumed ? nil : event
        }
        moveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated { self?.state.pointerMoved() }
            return event
        }
        // Safety net: a click in another app closes the panel even if activation was refused.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let moveMonitor { NSEvent.removeMonitor(moveMonitor) }
        moveMonitor = nil
        keyMonitor = nil
        clickMonitor = nil
    }

    private struct Key: Sendable {
        let code: UInt16
        let modifiers: NSEvent.ModifierFlags
        let windowNumber: Int
    }

    /// true when the key was handled here.
    private func handle(_ key: Key) -> Bool {
        guard let window = host.view.window, key.windowNumber == window.windowNumber else { return false }
        // Physical keys, so the shortcuts work on any layout (Russian included).
        if key.modifiers == .command {
            switch key.code {
            case 45: onAdd(); return true // kVK_ANSI_N
            case 43: onSettings(); return true // kVK_ANSI_Comma
            default: return false
            }
        }
        // Text fields (the search on All) keep their own arrows, Return and Escape.
        guard key.modifiers.isEmpty, !(window.firstResponder is NSText) else { return false }
        switch key.code {
        case 53: // Escape
            close()
            return true
        case 125, 126: // ↓ ↑
            guard state.tab == .upcoming else { return false }
            state.moveSelection(by: key.code == 125 ? 1 : -1, in: UpcomingTab.keys(model))
            return true
        case 36, 76: // Return, Enter
            guard state.tab == .upcoming, let selection = state.selection else { return false }
            show(subscription: selection.subscriptionID)
            return true
        default:
            return false
        }
    }
}
