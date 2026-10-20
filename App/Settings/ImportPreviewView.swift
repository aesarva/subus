import SubusCore
import SwiftUI

struct ImportPreviewView: View {
    let preview: ImportPreview
    let onAdd: () -> Void
    let onReplace: () -> Void
    let onCancel: () -> Void

    @State private var confirmingReplace = false

    private var found: Int { preview.library.subscriptions.count }
    private var errorLines: [Int] { Array(Set(preview.errors.map(\.line))).sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Self.summary(found: found, errorLines: errorLines)).font(.headline)
            if !errorLines.isEmpty {
                Text("Rows with errors are skipped.").font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button("Cancel", role: .cancel, action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Replace All") { confirmingReplace = true }.disabled(found == 0)
                Button("Add to Existing", action: onAdd).keyboardShortcut(.defaultAction).disabled(found == 0)
            }
        }
        .padding(20)
        .frame(width: 520)
        .alert("Replace all data?", isPresented: $confirmingReplace) {
            Button("Replace All", role: .destructive, action: onReplace)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All current subscriptions, categories and payment methods will be replaced by the file's contents. A backup of the current data stays in the data folder until the next change.")
        }
    }

    static func summary(found: Int, errorLines: [Int]) -> String {
        let head = String(localized: "Found \(found) subscriptions")
        guard !errorLines.isEmpty else { return head }
        let shown = errorLines.prefix(10).map(String.init).joined(separator: ", ") + (errorLines.count > 10 ? "…" : "")
        let tail = String(localized: "\(errorLines.count) with errors (lines \(shown))")
        return "\(head), \(tail)"
    }
}
