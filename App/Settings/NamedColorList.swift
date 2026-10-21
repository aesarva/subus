import SubusCore
import SwiftUI

/// What one row of a categories or payment-methods list needs; both kinds share one editor.
struct NamedColorItem: Identifiable {
    var id: UUID
    var name: String
    var colorIndex: Int
}

struct NamedColorList: View {
    let items: [NamedColorItem]
    let addTitle: String
    let usage: (UUID) -> Int
    let deleteMessage: (Int) -> String
    let error: String?
    let onRename: (UUID, String) -> Bool
    /// nil hides the colour column: payment methods carry no line colour in the UI.
    let onRecolor: ((UUID, Int) -> Void)?
    let onDelete: (UUID) -> Void
    let onAdd: () -> Void

    @State private var confirming: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        if let onRecolor {
                            SwatchButton(index: item.colorIndex) { onRecolor(item.id, $0) }
                        }
                        NameField(name: item.name) { onRename(item.id, $0) }
                        Button {
                            if usage(item.id) == 0 { onDelete(item.id) } else { confirming = item.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help(String(localized: "Delete"))
                        .accessibilityLabel(Text("Delete"))
                    }
                }
            }
            .listStyle(.bordered)
            .frame(height: 260)

            HStack {
                Button(action: onAdd) { Label(addTitle, systemImage: "plus") }
                if let error {
                    Text(error).font(.callout).foregroundStyle(.red).lineLimit(2)
                }
                Spacer()
            }
        }
        .alert(confirming.map { deleteMessage(usage($0)) } ?? "", isPresented: Binding(
            get: { confirming != nil }, set: { if !$0 { confirming = nil } })) {
            Button("Delete", role: .destructive) {
                if let id = confirming { onDelete(id) }
                confirming = nil
            }
            Button("Cancel", role: .cancel) { confirming = nil }
        }
    }
}

/// Edits locally and commits on Return or when focus leaves, so typing never writes the file.
private struct NameField: View {
    let name: String
    let commit: (String) -> Bool
    @State private var text: String
    @FocusState private var focused: Bool

    init(name: String, commit: @escaping (String) -> Bool) {
        self.name = name
        self.commit = commit
        _text = State(initialValue: name)
    }

    var body: some View {
        TextField("Name", text: $text)
            .labelsHidden()
            .textFieldStyle(.plain)
            .focused($focused)
            .onSubmit(finish)
            .onChange(of: focused) { _, isFocused in if !isFocused { finish() } }
            .onChange(of: name) { _, value in if !focused { text = value } }
            .onDisappear(perform: finish)
    }

    private func finish() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            text = name
        } else if trimmed != name {
            text = commit(trimmed) ? trimmed : name
        }
    }
}

private struct SwatchButton: View {
    let index: Int
    let pick: (Int) -> Void
    @State private var open = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button { open = true } label: {
            Circle().fill(LinePalette.line(.preset(index), scheme)).frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .help(Self.colorName(index))
        .accessibilityLabel(Text("Color: \(Self.colorName(index))"))
        .popover(isPresented: $open, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                ForEach(0..<Category.paletteCount, id: \.self) { i in
                    Button {
                        pick(i)
                        open = false
                    } label: {
                        Circle().fill(LinePalette.line(.preset(i), scheme)).frame(width: 20, height: 20)
                            .overlay {
                                if i == index { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) }
                            }
                    }
                    .buttonStyle(.plain)
                    .help(Self.colorName(i))
                    .accessibilityLabel(Text(Self.colorName(i)))
                }
            }
            .padding(12)
        }
    }

    static func colorName(_ i: Int) -> String {
        [String(localized: "Magenta"), String(localized: "Green"), String(localized: "Blue"), String(localized: "Red"),
         String(localized: "Violet"), String(localized: "Cyan"), String(localized: "Brown"),
         String(localized: "Yellow")][((i % Category.paletteCount) + Category.paletteCount) % Category.paletteCount]
    }
}
