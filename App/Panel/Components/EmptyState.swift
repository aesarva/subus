import SwiftUI

/// A calm centred state: what is going on, and the one thing to do about it.
struct PanelEmptyState: View {
    let systemImage: String
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            Text(verbatim: title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            if let message {
                Text(verbatim: message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 36)
    }
}
