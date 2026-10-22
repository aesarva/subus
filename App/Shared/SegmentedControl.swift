import AppKit
import SwiftUI

/// `NSSegmentedControl` in SwiftUI. Filling, it spreads its segments over the width it is offered (the panel's
/// tabs; SwiftUI's segmented picker keeps its intrinsic width on macOS); otherwise it keeps its intrinsic width
/// (the Year window's toolbar), drawn by AppKit either way.
struct SegmentedControl: NSViewRepresentable {
    let labels: [String]
    @Binding var selectedIndex: Int
    var fills = true

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: labels, trackingMode: .selectOne,
                                         target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        if fills {
            control.segmentDistribution = .fillEqually
            control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        } else {
            control.segmentDistribution = .fit
        }
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
        guard fills else { return intrinsic }
        return CGSize(width: max(proposal.width ?? intrinsic.width, intrinsic.width), height: intrinsic.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject {
        var parent: SegmentedControl
        init(parent: SegmentedControl) { self.parent = parent }
        @objc func changed(_ sender: NSSegmentedControl) { parent.selectedIndex = sender.selectedSegment }
    }
}
