import SwiftUI

/// "+ Add" · "Total 12 · inactive 2" · Settings.
struct PanelFooter: View {
    let total: Int
    let inactive: Int
    let onAdd: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Button(action: onAdd) {
                    Label(String(localized: "Add"), systemImage: "plus")
                }
                .help(String(localized: "Add Subscription (⌘N)"))
                Spacer(minLength: 4)
                if total > 0 {
                    Text(verbatim: countText)
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                }
                .help(String(localized: "Settings (⌘,)"))
                .accessibilityLabel(String(localized: "Settings"))
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
    }

    private var countText: String {
        let all = String(localized: "Total \(total)")
        return inactive > 0 ? all + " · " + String(localized: "inactive \(inactive)") : all
    }
}
