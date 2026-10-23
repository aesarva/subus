import Foundation

/// What the panel, the menu-bar icon and Settings show about an update.
public enum UpdateState: Equatable, Sendable {
    case idle
    /// Only for a check the user asked for: a background check runs silently.
    case checking
    /// Only after a check the user asked for.
    case upToDate
    case available(version: String, notesURL: URL?)
    /// `progress` is 0…1; `nil` until the server names the size.
    case downloading(version: String, progress: Double?)
    case installing(version: String)
    case failed(message: String)
    /// Subus runs from a disk image or a translocated folder, where Sparkle does not update.
    case needsMove
}

/// The updater's (Sparkle's) callbacks in our terms.
public enum UpdateEvent: Equatable, Sendable {
    case checkStarted(userInitiated: Bool)
    case found(version: String, notesURL: URL?)
    case notFound(userInitiated: Bool)
    case downloadStarted
    case expectedLength(UInt64)
    case received(UInt64)
    /// Extracting, ready to install and installing are one step to the user.
    case installing
    case error(message: String, userInitiated: Bool)
    /// Sparkle refused to run because of where the app is (disk image, App Translocation).
    case locationUnsupported
    /// A background check finished without errors. With no update Sparkle never calls the UI, so an old result of
    /// a manual check ("failed", "up to date") would otherwise stay until the next release.
    case backgroundCheckSucceeded
    /// An offer left unanswered for a day was withdrawn, to be checked again; its button no longer installs anything.
    case offerExpired
    /// Sparkle closed the update session.
    case dismissed
}

/// The update state and the download counters. A pure model: Sparkle only supplies events.
public struct UpdateModel: Equatable, Sendable {
    public private(set) var state: UpdateState = .idle
    private var expected: UInt64?
    private var received: UInt64 = 0

    public init() {}

    /// The badge on the menu-bar icon: an update exists and is not installed yet. A failed manual check does not
    /// mean there is one.
    public var showsBadge: Bool {
        switch state {
        case .available, .downloading, .installing: true
        default: false
        }
    }

    public mutating func apply(_ event: UpdateEvent) {
        switch event {
        case .checkStarted(let userInitiated):
            if userInitiated { state = .checking }
        case .found(let version, let notesURL):
            state = .available(version: version, notesURL: notesURL)
        case .notFound(let userInitiated):
            state = userInitiated ? .upToDate : .idle
        case .downloadStarted:
            expected = nil
            received = 0
            state = .downloading(version: version, progress: nil)
        case .expectedLength(let length):
            expected = length
            state = .downloading(version: version, progress: progress)
        case .received(let length):
            received &+= length
            state = .downloading(version: version, progress: progress)
        case .installing:
            state = .installing(version: version)
        case .error(let message, let userInitiated):
            state = userInitiated || isInstalling ? .failed(message: message) : .idle
        case .locationUnsupported:
            state = .needsMove
        case .backgroundCheckSucceeded:
            switch state {
            case .failed, .upToDate: state = .idle
            default: break
            }
        case .offerExpired:
            if case .available = state { state = .idle }
        case .dismissed:
            switch state {
            case .checking, .downloading, .installing: state = .idle
            default: break
            }
        }
    }

    private var version: String {
        switch state {
        case .available(let version, _), .downloading(let version, _), .installing(let version): version
        default: ""
        }
    }

    private var progress: Double? {
        guard let expected, expected > 0 else { return nil }
        // Whole percents: the state changes at most a hundred times, not on every chunk received.
        return (min(1, Double(received) / Double(expected)) * 100).rounded(.down) / 100
    }

    private var isInstalling: Bool {
        switch state {
        case .downloading, .installing: true
        default: false
        }
    }
}

/// Whether the app can be updated where it is. From a disk image (a read-only volume) and after App Translocation
/// Sparkle silently refuses even to check, so Subus says so itself.
public enum UpdateLocation {
    public static func canUpdate(bundlePath: String, volumeIsReadOnly: Bool) -> Bool {
        !volumeIsReadOnly && !bundlePath.contains("/AppTranslocation/")
    }
}
