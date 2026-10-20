import AppKit
import OSLog
import SubusCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "ui")
    private var statusItem: StatusItemController!

    func applicationWillFinishLaunching(_ notification: Notification) {
        // The notification center delegate is set here, before launch finishes.
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.debug("Library schema version \(Library.currentSchemaVersion)")
        statusItem = StatusItemController(
            onTogglePanel: { [log] in log.info("toggle panel") },
            onAdd: { [log] in log.info("add subscription") },
            onSettings: { [log] in log.info("open settings") }
        )
        statusItem.update(counterText: nil, accent: false)
    }
}
