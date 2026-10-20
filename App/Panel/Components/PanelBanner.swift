import SwiftUI

/// A one-line notice under the tabs: an icon, the problem in plain words and one action.
struct PanelBanner: View {
    let systemImage: String
    let tint: Color
    let message: String
    let actionTitle: String
    let action: () -> Void
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: message)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                Button(actionTitle, action: action)
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help(String(localized: "Dismiss"))
                .accessibilityLabel(String(localized: "Dismiss"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider().padding(.horizontal, 16) }
        .accessibilityElement(children: .contain)
    }
}
