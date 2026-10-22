import AppKit
import SwiftUI

/// The menu-bar panel: a transient `NSPopover` whose height follows its SwiftUI content.
@MainActor
final class PanelController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let anchor: () -> NSStatusBarButton?
    private let onAdd: () -> Void
    private let onYear: () -> Void
    private let onSettings: () -> Void
    private let onEdit: (UUID) -> Void
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
         onAdd: @escaping () -> Void, onYear: @escaping () -> Void, onSettings: @escaping () -> Void,
         onEdit: @escaping (UUID) -> Void) {
        self.model = model
        self.anchor = anchor
        self.onAdd = onAdd
        self.onYear = onYear
        self.onSettings = onSettings
        self.onEdit = onEdit
        super.init()
        let actions = PanelActions(
            onAdd: { [weak self] in self?.onAdd() },
            onYear: { [weak self] in self?.onYear() },
            onSettings: { [weak self] in self?.onSettings() },
            onOpen: { [weak self] id in self?.show(subscription: id) },
            onEdit: { [weak self] id in self?.onEdit(id) },
            onBack: { [weak self] in self?.focusContent() },
            onModal: { [weak self] presented in
                // The confirmation sheet takes focus; a transient popover would close under it.
                self?.popover.behavior = presented ? .applicationDefined : .transient
            })
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

    /// Opens the panel, on the subscription's card when there is one.
    func show(subscription id: UUID?) {
        if let id, model.library.subscriptions.contains(where: { $0.id == id }) {
            state.openCard(id, upcomingKeys: UpcomingTab.keys(model), spendingKeys: SpendingTab.keys(model))
        }
        // Pushed before opening, so the first frame already has the card's height.
        if popover.isShown { focusContent() } else { open() }
    }

    /// The content view takes the keyboard back, e.g. from the search field or a card's control.
    private func focusContent() {
        guard let window = host.view.window else { return }
        window.makeFirstResponder(host.view)
    }

    private func back() {
        state.closeCard()
        focusContent()
    }

    func close() {
        guard popover.isShown else { return }
        // A click elsewhere while the delete confirmation is up dismisses it with the panel: nothing is deleted.
        state.confirmingDelete = false
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
        // The next opening starts on the tab, with an empty search.
        state.closeCard()
        state.restoreRowFocus = false
        state.search = ""
        state.allSelection = nil
        popover.behavior = .transient
        removeMonitors()
    }

    // MARK: Keyboard

    private func installMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let key = Key(code: event.keyCode,
                          modifiers: event.modifierFlags.intersection([.command, .shift, .option, .control]),
                          characters: event.characters,
                          windowNumber: event.windowNumber)
            let consumed = MainActor.assumeIsolated { self?.handle(key, event: event) ?? false }
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
        let characters: String?
        let windowNumber: Int
    }

    /// true when the key was handled here.
    private func handle(_ key: Key, event: NSEvent) -> Bool {
        guard let window = host.view.window, key.windowNumber == window.windowNumber else { return false }
        // Physical keys, so the shortcuts work on any layout (Russian included).
        if key.modifiers == .command {
            switch key.code {
            case 45: onAdd(); return true // kVK_ANSI_N
            case 16: onYear(); return true // kVK_ANSI_Y
            case 43: onSettings(); return true // kVK_ANSI_Comma
            default: return false
            }
        }
        if let field = state.searchField, field.currentEditor() != nil, window.firstResponder === field.currentEditor() {
            return handleInSearch(key, field: field)
        }
        // Other text fields keep their own arrows, Return and Escape.
        guard !(window.firstResponder is NSText) else { return false }
        if key.modifiers.isEmpty {
            switch key.code {
            case 53: // Escape
                if state.card != nil {
                    back()
                } else if state.tab == .all, !state.search.isEmpty {
                    state.search = ""
                } else {
                    close()
                }
                return true
            case 125, 126: // ↓ ↑
                return contentHasKeyboard(window) && moveSelection(by: key.code == 125 ? 1 : -1)
            case 36, 76, 49: // Return, Enter, Space
                return contentHasKeyboard(window) && openSelection()
            default:
                break
            }
        }
        // Typing on All goes to the search field, starting with the key just pressed.
        // An empty `characters` is a dead key: it starts a composed character in the field.
        if state.tab == .all, state.card == nil, key.modifiers.isSubset(of: [.shift, .option]),
           let text = key.characters, text.isEmpty || Self.isPrintable(text) {
            return type(event)
        }
        return false
    }

    /// The list's keys belong to the panel only while its own content has the keyboard: the hosting view, or a
    /// plain view inside it (the strip and All rows are SwiftUI-drawn, not AppKit controls). A focused control
    /// (segmented control, button, switch) keeps its native Return, Space and arrows.
    private func contentHasKeyboard(_ window: NSWindow) -> Bool {
        guard let responder = window.firstResponder as? NSView else { return false }
        return responder === host.view || (responder.isDescendant(of: host.view) && !(responder is NSControl))
    }

    /// In the search field ↑/↓ and Return reach the list; Esc clears the search, and on an empty one closes the panel.
    private func handleInSearch(_ key: Key, field: NSSearchField) -> Bool {
        // While an input method or a dead key composes, its keys are its own.
        if let editor = field.currentEditor() as? NSTextView, editor.hasMarkedText() { return false }
        guard key.modifiers.isEmpty else { return false }
        switch key.code {
        case 53:
            if field.stringValue.isEmpty {
                close()
            } else {
                // Cleared in the field editor too, so the field keeps the focus for the next Esc.
                field.currentEditor()?.string = ""
                field.stringValue = ""
                state.search = ""
            }
            return true
        case 125, 126:
            return moveSelection(by: key.code == 125 ? 1 : -1)
        case 36, 76:
            // Nothing selected among the results: Return opens the first one.
            let order = AllTab.rows(model, state).order
            if state.allSelection.map({ !order.contains($0) }) ?? true { state.allSelection = order.first }
            return openSelection()
        default:
            return false
        }
    }

    private func moveSelection(by step: Int) -> Bool {
        guard state.card == nil else { return false }
        switch state.tab {
        case .upcoming: state.moveSelection(by: step, in: UpcomingTab.keys(model))
        case .all: state.moveAllSelection(by: step, in: AllTab.rows(model, state).order)
        case .spending: state.moveSpendingSelection(by: step, in: SpendingTab.keys(model))
        }
        return true
    }

    private func openSelection() -> Bool {
        guard state.card == nil else { return false }
        let id: UUID? = switch state.tab {
        case .upcoming: state.selection?.subscriptionID
        case .all: state.allSelection.flatMap { AllTab.rows(model, state).order.contains($0) ? $0 : nil }
        case .spending: state.spendingSelection.flatMap { SpendingTab.keys(model).contains($0) ? $0.subscriptionID : nil }
        }
        guard let id else { return false }
        show(subscription: id)
        return true
    }

    /// The key goes through the field editor's input context, so dead keys and input methods compose as usual.
    private func type(_ event: NSEvent) -> Bool {
        guard let field = state.searchField, let window = host.view.window, window.makeFirstResponder(field),
              let editor = field.currentEditor() as? NSTextView else { return false }
        editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        editor.interpretKeyEvents([event])
        return true
    }

    /// Letters, digits, punctuation and symbols; not whitespace alone, control or function keys (arrows, F-keys).
    private static func isPrintable(_ text: String) -> Bool {
        guard !text.isEmpty, !text.allSatisfy(\.isWhitespace) else { return false }
        return text.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
        }
    }
}
