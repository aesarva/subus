import SubusCore
import SwiftUI

/// Creates a category, or picks the one already named so, and hands its id back. On a failed write it
/// stays open with the error and hands nothing back.
struct NewCategorySheet: View {
    let model: AppModel
    let onCreated: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var color: CategoryColor
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    init(model: AppModel, name: String = "", color: CategoryColor? = nil, onCreated: @escaping (UUID) -> Void) {
        self.model = model
        self.onCreated = onCreated
        _name = State(initialValue: name)
        _color = State(initialValue: color ?? .preset(model.library.categories.count % Category.paletteCount))
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New Category").font(.headline).padding([.horizontal, .top], 20)
            Form {
                TextField("Name", text: $name)
                    .focused($nameFocused)
                LabeledContent("Color") {
                    HStack(spacing: 12) {
                        StationRing(lineColor: color)
                        CategoryColorPicker(color: $color)
                    }
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
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 560)
        .onAppear { nameFocused = true }
    }

    private func add() {
        var id: UUID?
        error = model.editLibrary { id = $0.addCategory(name: trimmed, color: color) }
        guard error == nil, let id else { return }
        onCreated(id)
        dismiss()
    }
}
