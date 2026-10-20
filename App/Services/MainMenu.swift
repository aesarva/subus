import AppKit

/// The standard main menu. A menu-bar app never shows it, but its key equivalents are what give
/// text fields ⌘X, ⌘C, ⌘V, ⌘A, ⌘Z and ⇧⌘Z.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: String(localized: "Quit Subus"), action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q")
        main.addItem(submenu: app, title: "Subus")

        let edit = NSMenu(title: String(localized: "menu.edit", defaultValue: "Edit"))
        edit.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)),
                     keyEquivalent: "a")
        main.addItem(submenu: edit, title: edit.title)
        return main
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
