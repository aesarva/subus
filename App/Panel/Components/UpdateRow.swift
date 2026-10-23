import SubusCore
import SwiftUI

/// The update line above the panel's footer. With no update to show it is not there.
struct UpdateRow: View {
    let updates: UpdateController

    var body: some View {
        if isShown {
            VStack(spacing: 0) {
                Divider()
                content
                    .font(.system(size: 12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
    }

    private var isShown: Bool {
        switch updates.state {
        case .idle, .upToDate: false
        default: true
        }
    }

    @ViewBuilder private var content: some View {
        switch updates.state {
        case .available(let version, let notesURL):
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    UpdateBadge()
                    Text("Version \(version) is available").lineLimit(1)
                    Spacer(minLength: 8)
                    if let notesURL {
                        Link(String(localized: "What's New"), destination: notesURL)
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                Button { updates.install() } label: {
                    Text("Install and Relaunch").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        case .downloading(let version, let progress):
            VStack(alignment: .leading, spacing: 6) {
                Text("Downloading \(version)")
                if let progress {
                    ProgressView(value: progress)
                } else {
                    ProgressView().progressViewStyle(.linear)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .installing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Installing…")
                Spacer(minLength: 0)
            }
        case .checking:
            Text("Checking for updates…")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            HStack {
                Text("Couldn't update").help(message)
                Spacer(minLength: 8)
                Button(String(localized: "Try Again")) { updates.checkNow() }
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .medium))
                    .disabled(!updates.canCheckNow)
            }
        case .needsMove:
            Text("Move Subus to Applications to get updates.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .idle, .upToDate:
            EmptyView()
        }
    }
}

/// The update dot: the system accent, the same as the badge on the menu-bar icon.
struct UpdateBadge: View {
    var body: some View {
        Circle()
            .fill(Color(nsColor: .controlAccentColor))
            .frame(width: 6, height: 6)
            .accessibilityHidden(true)
    }
}
