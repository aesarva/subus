import AppKit
import SwiftUI

/// Native `NSSearchField` (magnifier and clear button); `.searchable` has no place to live in a popover.
/// The field registers itself so the panel can focus it when the user starts typing.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let onRegister: (NSSearchField) -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.changed(_:))
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setAccessibilityLabel(prompt)
        onRegister(field)
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        onRegister(field)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSearchField, context: Context) -> CGSize? {
        let intrinsic = nsView.intrinsicContentSize
        return CGSize(width: proposal.width ?? 160, height: intrinsic.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        init(parent: SearchField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField { update(field.stringValue) }
        }

        /// The clear button sends the action without a text change notification.
        @objc func changed(_ sender: NSSearchField) { update(sender.stringValue) }

        private func update(_ value: String) {
            if parent.text != value { parent.text = value }
        }
    }
}
