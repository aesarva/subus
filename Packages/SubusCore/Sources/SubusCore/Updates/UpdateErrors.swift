/// Sparkle's error codes, from SUErrors.h; `sparkleCode` is nil for an error outside the Sparkle domain.
public enum UpdateErrors {
    static let noUpdate = 1001
    static let runningFromDiskImage = 1003
    static let runningTranslocated = 1005
    static let installationCanceled = 4007

    /// Running from a disk image or after App Translocation is not a failure but a reason to move the app.
    public static func event(sparkleCode: Int?, message: String, userInitiated: Bool) -> UpdateEvent {
        switch sparkleCode {
        case runningFromDiskImage, runningTranslocated: .locationUnsupported
        default: .error(message: message, userInitiated: userInitiated)
        }
    }

    public enum CycleOutcome: Equatable, Sendable {
        case succeeded
        /// The user cancelled the administrator password prompt: the update is still there.
        case installCanceled
        case failed
    }

    /// How a check cycle ended. Sparkle reports "no update" as an error, but the check succeeded.
    public static func cycleOutcome(failed: Bool, sparkleCode: Int?) -> CycleOutcome {
        guard failed else { return .succeeded }
        switch sparkleCode {
        case noUpdate: return .succeeded
        case installationCanceled: return .installCanceled
        default: return .failed
        }
    }
}
