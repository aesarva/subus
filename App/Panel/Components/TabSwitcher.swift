import AppKit
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

/// `NSSegmentedControl` filling its width; SwiftUI's segmented picker keeps its intrinsic width on macOS.
private struct SegmentedControl: NSViewRepresentable {
    let labels: [String]
    @Binding var selectedIndex: Int

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: labels, trackingMode: .selectOne,
                                         target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        control.segmentDistribution = .fillEqually
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        for (i, label) in labels.enumerated() where control.label(forSegment: i) != label {
            control.setLabel(label, forSegment: i)
        }
        control.selectedSegment = selectedIndex
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        return CGSize(width: max(proposal.width ?? intrinsic.width, intrinsic.width), height: intrinsic.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject {
        var parent: SegmentedControl
        init(parent: SegmentedControl) { self.parent = parent }
        @objc func changed(_ sender: NSSegmentedControl) { parent.selectedIndex = sender.selectedSegment }
    }
}
