import AppKit

/// While an editor or Settings window is open the app is a regular one, so a window that slips behind
/// the browser stays reachable from the Dock and ⌘Tab; with none open it lives only in the menu bar.
@MainActor
final class DockPresence {
    /// Marks the windows that keep the Dock icon: editors and Settings, never alerts or open panels.
    static let identifier = NSUserInterfaceItemIdentifier("io.github.aesarva.Subus.window")

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didDeminiaturizeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { Self.update(closing: nil) }
            })
        }
        observers.append(center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated { Self.update(closing: window) }
        })
    }

    private static func update(closing: NSWindow?) {
        let hasWindow = NSApp.windows.contains {
            $0 !== closing && $0.identifier == identifier && ($0.isVisible || $0.isMiniaturized)
        }
        let policy: NSApplication.ActivationPolicy = hasWindow ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }
}
