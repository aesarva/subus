import AppKit
import SubusCore
import SwiftUI

/// The card-number field. macOS offers saved cards through AutoFill (`.creditCardNumber`); whatever arrives
/// is reduced by `CardFieldParser`. The raw text stays inside AppKit: the binding only ever holds what was
/// read from it (last four digits and network) or nothing, and `hasText` says whether something unread is typed.
/// The field has a field editor of its own with undo off, so no other field shares or inherits its text.
struct CardNumberField: NSViewRepresentable {
    @Binding var state: CardFieldState
    @Binding var hasText: Bool
    var onEnd: () -> Void = {}

    func makeNSView(context: Context) -> CardTextField {
        let field = CardTextField()
        field.contentType = .creditCardNumber
        field.placeholderString = "0000"
        field.stringValue = state.text
        field.delegate = context.coordinator
        context.coordinator.raw = state
        return field
    }

    func updateNSView(_ field: CardTextField, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleNSView(_ field: CardTextField, coordinator: Coordinator) {
        field.abortEditing()
        field.wipeEditor()
        field.stringValue = ""
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CardNumberField
        var raw = CardFieldState()

        init(parent: CardNumberField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? CardTextField else { return }
            apply(CardFieldParser.edited(raw, to: field.stringValue, inserted: field.takeInsertedLength()), to: field)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? CardTextField else { return }
            apply(CardFieldParser.ended(raw), to: field)
            parent.onEnd()
        }

        private func apply(_ next: CardFieldState, to field: CardTextField) {
            if next.text != field.stringValue { field.replaceText(with: next.text) }
            raw = next
            parent.state = next.last4 == nil ? CardFieldState() : next
            parent.hasText = !next.text.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}

final class CardTextField: NSTextField {
    override class var cellClass: AnyClass? {
        get { CardFieldCell.self }
        set {}
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        cell?.allowsUndo = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// The length of what the last edit inserted, read once by the coordinator.
    func takeInsertedLength() -> Int? { (cell as? CardFieldCell)?.editor.takeInsertedLength() }

    /// Replaces the text in the field and, while editing, in its own field editor.
    func replaceText(with text: String) {
        (currentEditor() as? NSTextView)?.string = text
        stringValue = text
    }

    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        wipeEditor()
    }

    func wipeEditor() { (cell as? CardFieldCell)?.wipe() }
}

/// Hands the field a private field editor that never records undo. The editor carries the card content type
/// itself, so AutoFill still offers saved cards, and has no spelling, replacement or completion of its own.
final class CardFieldCell: NSTextFieldCell {
    let editor: CardFieldEditor = {
        let editor = CardFieldEditor()
        editor.isFieldEditor = true
        return editor
    }()

    override func fieldEditor(for controlView: NSView) -> NSTextView? {
        editor.configureForCard()
        return editor
    }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let text = super.setUpFieldEditorAttributes(textObj)
        (text as? CardFieldEditor)?.configureForCard()
        return text
    }

    func wipe() {
        editor.undoManager?.removeAllActions(withTarget: editor)
        editor.string = ""
    }
}

/// The private field editor; it notes how long each insertion is, so AutoFill replacing typed text is seen.
final class CardFieldEditor: NSTextView {
    private var insertedLength: Int?

    func configureForCard() {
        allowsUndo = false
        contentType = .creditCardNumber
        isContinuousSpellCheckingEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticTextCompletionEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        inlinePredictionType = .no
    }

    override func shouldChangeText(in affectedCharRange: NSRange, replacementString: String?) -> Bool {
        insertedLength = replacementString?.count
        return super.shouldChangeText(in: affectedCharRange, replacementString: replacementString)
    }

    func takeInsertedLength() -> Int? {
        defer { insertedLength = nil }
        return insertedLength
    }
}
