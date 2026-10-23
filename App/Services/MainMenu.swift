import AppKit

/// The standard main menu. A menu-bar app never shows it, but its key equivalents are what give
/// text fields ⌘X, ⌘C, ⌘V, ⌘A, ⌘Z and ⇧⌘Z.
@MainActor
enum MainMenu {
    static func make(newSubscription: Selector, openSettings: Selector, openYear: Selector, target: AnyObject) -> NSMenu {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: String(localized: "Settings…"), action: openSettings, keyEquivalent: ",").target = target
        app.addItem(.separator())
        app.addItem(withTitle: String(localized: "Quit Subus"), action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q")
        main.addItem(submenu: app, title: "Subus")

        let file = NSMenu(title: String(localized: "menu.file", defaultValue: "File"))
        let new = file.addItem(withTitle: String(localized: "New Subscription"), action: newSubscription, keyEquivalent: "n")
        new.target = target
        file.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        main.addItem(submenu: file, title: file.title)

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

        let window = NSMenu(title: String(localized: "menu.window", defaultValue: "Window"))
        window.addItem(withTitle: String(localized: "Year"), action: openYear, keyEquivalent: "y").target = target
        main.addItem(submenu: window, title: window.title)
        // AppKit lists the open windows under it.
        NSApp.windowsMenu = window
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
