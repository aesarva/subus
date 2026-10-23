import SwiftUI

/// Native segmented control across the panel width: Upcoming · All · Spending.
struct TabSwitcher: View {
    @Binding var selection: PanelTab

    var body: some View {
        SegmentedControl(labels: PanelTab.allCases.map(\.title), selectedIndex: Binding(
            get: { PanelTab.allCases.firstIndex(of: selection) ?? 0 },
            set: { selection = PanelTab.allCases[$0] }))
            .accessibilityLabel(String(localized: "Section"))
            .padding(.horizontal, 16)
            .padding(.top, 12)
    }
}
