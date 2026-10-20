import AppKit
import Observation
import SubusCore

/// The app's own UI language, independent of the system list. Stored as `AppleLanguages`
/// in Subus's defaults domain, which macOS reads at launch, so a change applies on restart.
extension LanguageSetting {
    /// Native names, so each choice is readable whatever the current UI language.
    var title: String {
        switch self {
        case .system: String(localized: "Same as system")
        case .ru: "Русский"
        case .en: "English"
        }
    }

    /// The choice saved in Subus's own defaults (not the global language list).
    static var saved: LanguageSetting {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        guard let first = (domain?["AppleLanguages"] as? [String])?.first else { return .system }
        return LanguageSetting(rawValue: String(first.prefix(2))) ?? .system
    }

    func save() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}

@MainActor @Observable final class LanguageModel {
    /// What this process launched with; the UI shows it until a restart.
    private let launched = LanguageSetting.saved
    var selection = LanguageSetting.saved {
        didSet { selection.save() }
    }

    var needsRestart: Bool { selection != launched }

    /// Starts a second instance, then quits, so macOS loads the chosen language.
    func restart() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
