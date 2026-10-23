import SubusCore
import SwiftUI

/// What one row of a categories or payment-methods list needs; both kinds share one editor.
struct NamedColorItem: Identifiable {
    var id: UUID
    var name: String
    var color: CategoryColor
}

struct NamedColorList: View {
    let items: [NamedColorItem]
    let addTitle: String
    let usage: (UUID) -> Int
    let deleteMessage: (Int) -> String
    let error: String?
    let onRename: (UUID, String) -> Bool
    /// nil hides the colour column: payment methods carry no line colour in the UI.
    let onRecolor: ((UUID, CategoryColor) -> Void)?
    let onDelete: (UUID) -> Void
    /// The New Category or New Card sheet behind the add button.
    let addSheet: AnyView

    @State private var confirming: UUID?
    @State private var adding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            List {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        if let onRecolor {
                            SwatchButton(name: item.name, color: item.color) { onRecolor(item.id, $0) }
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
                Button { adding = true } label: { Label(addTitle, systemImage: "plus") }
                if let error {
                    Text(error).font(.callout).foregroundStyle(.red).lineLimit(2)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $adding) { addSheet }
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

/// The row's colour dot; it opens a sheet rather than a popover, because the system colour panel outlives
/// a popover but not a sheet, and the colour is written once, on Done.
private struct SwatchButton: View {
    let name: String
    let color: CategoryColor
    let pick: (CategoryColor) -> Void
    @State private var open = false
    @State private var draft: CategoryColor = .preset(0)
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button {
            draft = color
            open = true
        } label: {
            Circle().fill(LinePalette.line(color, scheme)).frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
        .help(color.displayName)
        .accessibilityLabel(Text("Color: \(color.displayName)"))
        .sheet(isPresented: $open) {
            VStack(alignment: .leading, spacing: 16) {
                Text(name).font(.headline)
                HStack(spacing: 12) {
                    StationRing(lineColor: draft)
                    CategoryColorPicker(color: $draft)
                }
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { open = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Done") {
                        if draft != color { pick(draft) }
                        open = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }
}
