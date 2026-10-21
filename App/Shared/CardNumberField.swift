import AppKit
import SubusCore
import SwiftUI

/// The card-number field. macOS offers saved cards through AutoFill (`.creditCardNumber`); whatever arrives
/// is reduced by `CardFieldParser`, so the binding never holds a parsed full number. Undo is off in the field
/// editor before the first keystroke, and the editor is wiped when the field goes away.
struct CardNumberField: NSViewRepresentable {
    @Binding var state: CardFieldState
    var onEnd: () -> Void = {}

    func makeNSView(context: Context) -> CardTextField {
        let field = CardTextField()
        field.contentType = .creditCardNumber
        field.placeholderString = "0000"
        field.stringValue = state.text
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: CardTextField, context: Context) {
        context.coordinator.parent = self
        if field.currentEditor() == nil, field.stringValue != state.text { field.stringValue = state.text }
    }

    static func dismantleNSView(_ field: CardTextField, coordinator: Coordinator) {
        if let editor = field.currentEditor() as? NSTextView { CardTextField.wipe(editor) }
        field.abortEditing()
        field.stringValue = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CardNumberField

        init(parent: CardNumberField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let next = CardFieldParser.edited(parent.state, to: field.stringValue)
            if next.text != field.stringValue { replace(field, with: next.text) }
            parent.state = next
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let next = CardFieldParser.ended(parent.state)
            if next.text != field.stringValue { field.stringValue = next.text }
            parent.state = next
            parent.onEnd()
        }

        private func replace(_ field: NSTextField, with text: String) {
            if let editor = field.currentEditor() as? NSTextView {
                editor.string = text
                editor.undoManager?.removeAllActions(withTarget: editor)
                if let storage = editor.textStorage { editor.undoManager?.removeAllActions(withTarget: storage) }
            }
            field.stringValue = text
        }
    }
}

final class CardTextField: NSTextField {
    /// The shared field editor gets undo switched off before anything is typed or filled in here.
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        (currentEditor() as? NSTextView)?.allowsUndo = false
        return accepted
    }

    /// The field editor serves the sheet's other fields next, so it leaves clean and with undo back on.
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        if let editor = notification.object as? NSTextView {
            Self.wipe(editor)
            editor.allowsUndo = true
        }
    }

    static func wipe(_ editor: NSTextView) {
        editor.undoManager?.removeAllActions(withTarget: editor)
        if let storage = editor.textStorage { editor.undoManager?.removeAllActions(withTarget: storage) }
        editor.string = ""
    }
}
