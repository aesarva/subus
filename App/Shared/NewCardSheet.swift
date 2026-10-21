import AppKit
import SubusCore
import SwiftUI

/// Creates a payment method from a card picked through AutoFill (or its last four digits) and a bank name,
/// or picks the one already labelled so. Only the label is stored; the number never leaves the field.
struct NewCardSheet: View {
    let model: AppModel
    let onCreated: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var card: CardFieldState
    @State private var bank: String
    @State private var ended = false
    @State private var hasText = false
    @State private var error: String?

    init(model: AppModel, card: CardFieldState = CardFieldState(), bank: String = "",
         onCreated: @escaping (UUID) -> Void) {
        self.model = model
        self.onCreated = onCreated
        _card = State(initialValue: card)
        _bank = State(initialValue: bank)
    }

    private var label: String { PaymentLabel.compose(bank: bank, last4: card.last4, network: card.network) }
    private var unreadable: Bool { ended && card.last4 == nil && hasText }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Card").font(.headline).padding([.horizontal, .top], 20)
            Form {
                LabeledContent("Card number") {
                    VStack(alignment: .trailing, spacing: 4) {
                        CardNumberField(state: $card, hasText: $hasText, onEnd: { ended = true })
                            .frame(width: 180)
                        if unreadable {
                            Text("Enter the last 4 digits or choose a card").font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                TextField("Bank or service", text: $bank, prompt: Text(verbatim: "Т-Банк"))
                LabeledContent("Label") {
                    Text(label.isEmpty ? "—" : label).foregroundStyle(label.isEmpty ? .secondary : .primary)
                }
                Section {
                } footer: {
                    Text("macOS suggests your saved cards. Subus keeps only the last 4 digits.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: endEditingThenAdd)
                    .keyboardShortcut(.defaultAction)
                    .disabled(label.isEmpty)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460)
    }

    /// A number still being typed is read first, so the label includes it.
    private func endEditingThenAdd() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        DispatchQueue.main.async { add() }
    }

    private func add() {
        let label = label
        var id: UUID?
        error = model.editLibrary { id = $0.addPaymentMethod(label: label) }
        guard error == nil, let id else { return }
        onCreated(id)
        dismiss()
    }
}
