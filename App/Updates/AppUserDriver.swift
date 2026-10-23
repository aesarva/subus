import Foundation
import OSLog
import Sparkle
import SubusCore

/// Sparkle's interface without its windows: turns Sparkle's calls into `UpdateEvent`s, and the panel and the
/// menu-bar icon show them. The choices Sparkle waits for are made here: installing on the panel's button,
/// relaunching right away, with no second click.
@MainActor
final class AppUserDriver: NSObject, SPUUserDriver {
    private let onEvent: (UpdateEvent) -> Void
    private let onShowPanel: () -> Void
    /// Sparkle's reply to a found update; called exactly once.
    private var pendingChoice: ((SPUUserUpdateChoice) -> Void)?
    /// Until it is answered Sparkle checks no more. After a day the offer is dropped and checked again, so a Subus
    /// left running for weeks does not offer 1.1 when 1.2 is out.
    private var offerExpiry: Task<Void, Never>?
    private static let offerLifetime: Duration = .seconds(24 * 60 * 60)
    /// A check the user asked for: its result and errors are shown, a background one's are not.
    private var userInitiated = false
    private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "updates")

    init(onEvent: @escaping (UpdateEvent) -> Void, onShowPanel: @escaping () -> Void) {
        self.onEvent = onEvent
        self.onShowPanel = onShowPanel
    }

    func install() {
        reply(.install)
    }

    private func reply(_ choice: SPUUserUpdateChoice) {
        offerExpiry?.cancel()
        offerExpiry = nil
        guard let reply = pendingChoice else { return }
        pendingChoice = nil
        reply(choice)
    }

    // MARK: Checking

    func show(_ request: SPUUpdatePermissionRequest,
              reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        userInitiated = true
        onEvent(.checkStarted(userInitiated: true))
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                         reply: @escaping (SPUUserUpdateChoice) -> Void) {
        userInitiated = false
        pendingChoice = reply
        offerExpiry?.cancel()
        offerExpiry = Task { [weak self] in
            try? await Task.sleep(for: Self.offerLifetime, clock: .continuous)
            guard !Task.isCancelled, let self, self.pendingChoice != nil else { return }
            // Reported first: the controller checks again when the session this dismissal closes is over.
            self.onEvent(.offerExpired)
            self.reply(.dismiss)
        }
        onEvent(.found(version: appcastItem.displayVersionString,
                       notesURL: appcastItem.releaseNotesURL ?? appcastItem.infoURL))
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {}

    func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        log.info("No update: \((error as NSError).code)")
        onEvent(.notFound(userInitiated: userInitiated))
        userInitiated = false
        acknowledgement()
    }

    func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
        let ns = error as NSError
        log.error("Updater error \(ns.domain, privacy: .public) \(ns.code): \(ns.localizedDescription, privacy: .public)")
        onEvent(UpdateController.event(for: error, userInitiated: userInitiated))
        userInitiated = false
        acknowledgement()
    }

    // MARK: Downloading and installing

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        onEvent(.downloadStarted)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        onEvent(.expectedLength(expectedContentLength))
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        onEvent(.received(length))
    }

    func showDownloadDidStartExtractingUpdate() {
        onEvent(.installing)
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        onEvent(.installing)
        reply(.install)
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool,
                              retryTerminatingApplication: @escaping () -> Void) {
        onEvent(.installing)
        // Subus does not hold up quitting, but if something delayed it, ask again rather than hang on "Installing…".
        guard !applicationTerminated else { return }
        Task {
            try? await Task.sleep(for: .seconds(5))
            retryTerminatingApplication()
        }
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdateInFocus() {
        onShowPanel()
    }

    func dismissUpdateInstallation() {
        offerExpiry?.cancel()
        offerExpiry = nil
        pendingChoice = nil
        userInitiated = false
        onEvent(.dismissed)
    }
}
