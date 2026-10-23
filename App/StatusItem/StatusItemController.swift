import AppKit

@MainActor
final class StatusItemController {
    private let item: NSStatusItem
    private let onTogglePanel: () -> Void
    private let onAdd: () -> Void
    private let onYear: () -> Void
    private let onSettings: () -> Void

    var button: NSStatusBarButton? { item.button }

    init(onTogglePanel: @escaping () -> Void, onAdd: @escaping () -> Void, onYear: @escaping () -> Void,
         onSettings: @escaping () -> Void) {
        self.onTogglePanel = onTogglePanel
        self.onAdd = onAdd
        self.onYear = onYear
        self.onSettings = onSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    /// `nil` counter text shows the glyph alone; `badge` marks an update not installed yet.
    func update(counterText: String?, accent: Bool, badge: Bool, accessibilityLabel: String? = nil) {
        guard let button = item.button else { return }
        button.image = MenuBarIcon.image(badge: badge)
        if let counterText {
            button.attributedTitle = Self.title(counterText, accent: accent)
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
        let label = accessibilityLabel ?? "Subus"
        button.setAccessibilityLabel(badge ? label + ", " + String(localized: "update available") : label)
    }

    /// The counter after the glyph: label colour, or the accent in semibold for today and tomorrow.
    static func title(_ counterText: String, accent: Bool) -> NSAttributedString {
        NSAttributedString(
            string: " " + counterText,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: accent ? .semibold : .regular),
                .foregroundColor: accent ? Brand.accentText : NSColor.labelColor,
            ]
        )
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            guard let button = item.button else { return }
            // statusItem.menu stays unset: it would swallow left clicks.
            QuickMenu.build(onAdd: onAdd, onYear: onYear, onSettings: onSettings)
                .popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
        } else {
            onTogglePanel()
        }
    }
}
