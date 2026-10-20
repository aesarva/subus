import AppKit

@main
enum SubusApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.mainMenu = MainMenu.make(newSubscription: #selector(AppDelegate.newSubscription),
                                   openSettings: #selector(AppDelegate.openSettings), target: delegate)
        withExtendedLifetime(delegate) { app.run() }
    }
}
