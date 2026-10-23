import Foundation
import Observation
import OSLog
import Sparkle
import SubusCore

/// Owns the Sparkle updater and publishes the update state for the panel, the menu-bar icon and Settings.
@MainActor @Observable
final class UpdateController: NSObject, SPUUpdaterDelegate {
    /// Published separately and only on change: the menu-bar icon follows `showsBadge` alone and is not redrawn
    /// for every chunk of a download.
    private(set) var state: UpdateState = .idle
    private(set) var showsBadge = false
    /// Sparkle can take a manual check: the updater is running and no other check is under way.
    private(set) var canCheckNow = false
    let currentVersion: String
    let currentBuild: String

    @ObservationIgnored private var model = UpdateModel()
    @ObservationIgnored private let feedOverride: String?
    /// One-shot: after one install it is spent, so a cancelled password prompt does not start the next attempt.
    @ObservationIgnored private var autoInstall: Bool
    /// An expired offer is checked again once Sparkle has closed its session; a check started earlier is refused.
    @ObservationIgnored private var recheckAfterCycle = false
    @ObservationIgnored private var driver: AppUserDriver?
    /// `nil` in a preview: the state is set directly and Sparkle never runs.
    @ObservationIgnored private var updater: SPUUpdater?
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "updates")

    /// `feedOverride` is a feed in place of `SUFeedURL` (the `-UpdateFeedURL` launch argument); `autoInstall` installs
    /// a found update without the click (`-UpdateAutoInstall YES`), for an end-to-end test with no one at the panel.
    init(feedOverride: String?, autoInstall: Bool = false, onShowPanel: @escaping () -> Void) {
        self.feedOverride = feedOverride
        self.autoInstall = autoInstall
        let info = Bundle.main.infoDictionary ?? [:]
        currentVersion = info["CFBundleShortVersionString"] as? String ?? "?"
        currentBuild = info["CFBundleVersion"] as? String ?? "?"
        super.init()
        let driver = AppUserDriver(onEvent: { [weak self] in self?.apply($0) }, onShowPanel: onShowPanel)
        let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        self.driver = driver
        self.updater = updater
        // Sparkle changes canCheckForUpdates on the main thread only.
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckNow = updater.canCheckForUpdates }
        }
    }

    #if DEBUG
    /// A controller showing `events` applied in order, with no updater behind it; for snapshots.
    private init(previewEvents events: [UpdateEvent]) {
        feedOverride = nil
        autoInstall = false
        currentVersion = "1.0.0"
        currentBuild = "120"
        super.init()
        canCheckNow = true
        events.forEach(apply)
    }

    static func preview(_ events: UpdateEvent...) -> UpdateController {
        UpdateController(previewEvents: events)
    }
    #endif

    var automaticallyChecks: Bool {
        get {
            access(keyPath: \.automaticallyChecks)
            return updater?.automaticallyChecksForUpdates ?? true
        }
        set {
            withMutation(keyPath: \.automaticallyChecks) { updater?.automaticallyChecksForUpdates = newValue }
        }
    }

    func start() {
        guard let updater else { return }
        let bundle = Bundle.main.bundleURL
        let readOnly = (try? bundle.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly ?? false
        guard UpdateLocation.canUpdate(bundlePath: bundle.path, volumeIsReadOnly: readOnly) else {
            apply(.locationUnsupported)
            return
        }
        do {
            try updater.start()
        } catch {
            let ns = error as NSError
            log.error("Updater failed to start \(ns.domain, privacy: .public) \(ns.code): \(ns.localizedDescription, privacy: .public)")
            apply(Self.event(for: error, userInitiated: true))
        }
    }

    func install() {
        guard case .available = state else { return }
        driver?.install()
    }

    /// A manual check; also "Try Again" after an error.
    func checkNow() {
        guard canCheckNow else { return }
        updater?.checkForUpdates()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        feedOverride
    }

    /// The end of every check. A background check with no update never calls the UI; this is the only word of it.
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if recheckAfterCycle {
            recheckAfterCycle = false
            Task { @MainActor [weak self] in self?.updater?.checkForUpdatesInBackground() }
            return
        }
        switch UpdateErrors.cycleOutcome(failed: error != nil, sparkleCode: Self.sparkleCode(of: error)) {
        case .succeeded:
            if updateCheck == .updatesInBackground { apply(.backgroundCheckSucceeded) }
        case .installCanceled:
            // The administrator password prompt was cancelled and Sparkle closed the session silently: offer the
            // update again, or it would be gone until the next daily check.
            Task { @MainActor [weak self] in self?.updater?.checkForUpdatesInBackground() }
        case .failed:
            break
        }
    }

    static func event(for error: any Error, userInitiated: Bool) -> UpdateEvent {
        UpdateErrors.event(sparkleCode: sparkleCode(of: error), message: error.localizedDescription,
                           userInitiated: userInitiated)
    }

    private static func sparkleCode(of error: (any Error)?) -> Int? {
        guard let error = error as NSError?, error.domain == SUSparkleErrorDomain else { return nil }
        return error.code
    }

    private func apply(_ event: UpdateEvent) {
        model.apply(event)
        if model.state != state { state = model.state }
        if model.showsBadge != showsBadge { showsBadge = model.showsBadge }
        if case .offerExpired = event { recheckAfterCycle = true }
        if autoInstall, case .found = event {
            autoInstall = false
            install()
        }
    }
}
