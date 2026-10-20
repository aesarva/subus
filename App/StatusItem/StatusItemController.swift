import AppKit

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let onTogglePanel: () -> Void
    private let onAdd: () -> Void
    private let onSettings: () -> Void

    var button: NSStatusBarButton? { item.button }

    init(onTogglePanel: @escaping () -> Void, onAdd: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onTogglePanel = onTogglePanel
        self.onAdd = onAdd
        self.onSettings = onSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// `nil` counter text shows the glyph alone.
    func update(counterText: String?, accent: Bool, accessibilityLabel: String? = nil) {
        guard let button = item.button else { return }
        button.image = MenuBarIcon.image(accent: accent)
        if let counterText {
            button.attributedTitle = NSAttributedString(
                string: " " + counterText,
                attributes: [.font: NSFont.monospacedDigitSystemFont(
                    ofSize: NSFont.systemFontSize, weight: accent ? .semibold : .regular)]
            )
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
        button.setAccessibilityLabel(accessibilityLabel ?? "Subus")
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            guard let button = item.button else { return }
            // statusItem.menu stays unset: it would swallow left clicks.
            QuickMenu.build(onAdd: onAdd, onSettings: onSettings)
                .popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
        } else {
            onTogglePanel()
        }
    }
}
