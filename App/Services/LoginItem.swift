import Foundation
import ServiceManagement

enum LoginItemState { case enabled, disabled, requiresApproval, unavailable }

enum LoginItem {
    static var state: LoginItemState {
        switch SMAppService.mainApp.status {
        case .enabled: .enabled
        case .notRegistered: .disabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }

    static func setEnabled(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
