import AppKit

@MainActor
enum QuickMenu {
    static func build(onAdd: @escaping () -> Void, onYear: @escaping () -> Void, onSettings: @escaping () -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ActionItem(String(localized: "Add Subscription…"), key: "n", action: onAdd))
        menu.addItem(ActionItem(String(localized: "Year"), key: "y", action: onYear))
        menu.addItem(ActionItem(String(localized: "Settings…"), key: ",", action: onSettings))
        menu.addItem(.separator())
        menu.addItem(ActionItem(String(localized: "Quit Subus"), key: "q") { NSApp.terminate(nil) })
        return menu
    }
}

@MainActor
private final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String, action handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        keyEquivalentModifierMask = .command
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}
