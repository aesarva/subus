import AppKit
import SwiftUI

/// A button showing the currency; it opens a searchable list, popular currencies first, then every other ISO code.
/// A code outside the list stays selectable.
struct CurrencyPicker: View {
    @Binding var selection: String
    @State private var choosing = false

    var body: some View {
        Button { choosing = true } label: {
            HStack(spacing: 4) {
                Text(verbatim: Self.label(selection))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 200)
        .accessibilityLabel(String(localized: "Currency"))
        .accessibilityValue(Self.label(selection))
        .popover(isPresented: $choosing, arrowEdge: .bottom) {
            CurrencySearch(selection: selection,
                           onPick: { code in
                               selection = code
                               choosing = false
                           },
                           onCancel: { choosing = false })
        }
    }

    static let popular = ["RUB", "USD", "EUR", "GBP", "KZT", "TRY", "AMD", "GEL", "UAH", "BYN", "CNY"]
    private static let others = Set(Locale.commonISOCurrencyCodes).subtracting(popular).sorted()

    /// Popular codes, then the rest; the current code joins the rest when it is in neither.
    static func currencies(including current: String) -> (popular: [String], others: [String]) {
        guard !popular.contains(current), !others.contains(current) else { return (popular, others) }
        return (popular, (others + [current]).sorted())
    }

    static func name(_ code: String) -> String { Locale.current.localizedString(forCurrencyCode: code) ?? code }

    static func label(_ code: String) -> String { "\(code) — \(name(code))" }

    /// By code or by localized name, ignoring case and diacritics.
    static func matches(_ code: String, _ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return code.range(of: q, options: options) != nil || name(code).range(of: q, options: options) != nil
    }
}

/// The popover: a search field over the list. Typing filters, ↑/↓ move the highlight, Return picks, Esc closes.
private struct CurrencySearch: View {
    let selection: String
    let onPick: (String) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var highlighted: String?

    var body: some View {
        let (popular, others) = filtered
        VStack(spacing: 0) {
            SearchField(text: $query, prompt: String(localized: "Search currencies"), autofocus: true,
                        onCommand: command)
                .padding(10)
            Divider()
            if popular.isEmpty && others.isEmpty {
                Text("No currencies match “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    // Heads are plain rows, not sections: a pinned section head would cover the highlighted row.
                    List {
                        if !popular.isEmpty {
                            head(String(localized: "Popular"))
                            ForEach(popular, id: \.self, content: row)
                        }
                        if !others.isEmpty {
                            head(String(localized: "All currencies"))
                            ForEach(others, id: \.self, content: row)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: highlighted) { _, code in
                        if let code { proxy.scrollTo(code) }
                    }
                    .onAppear {
                        if let code = highlighted, !CurrencyPicker.popular.contains(code) {
                            Task { @MainActor in proxy.scrollTo(code, anchor: .center) }
                        }
                    }
                }
            }
        }
        .frame(width: 300, height: 340)
        .onAppear { highlighted = selection }
        .onChange(of: query) { _, _ in
            let order = flat
            if highlighted.map({ !order.contains($0) }) ?? true { highlighted = order.first }
        }
    }

    private var filtered: (popular: [String], others: [String]) {
        let (popular, others) = CurrencyPicker.currencies(including: selection)
        return (popular.filter { CurrencyPicker.matches($0, query) }, others.filter { CurrencyPicker.matches($0, query) })
    }

    private var flat: [String] {
        let (popular, others) = filtered
        return popular + others
    }

    private func head(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
            .listRowSeparator(.hidden)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ code: String) -> some View {
        let lit = highlighted == code
        return Button { onPick(code) } label: {
            HStack(spacing: 8) {
                Text(verbatim: code)
                    .font(.body.monospaced().weight(.semibold))
                    .frame(width: 40, alignment: .leading)
                Text(verbatim: CurrencyPicker.name(code))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if code == selection {
                    Image(systemName: "checkmark")
                        .accessibilityLabel(String(localized: "Selected"))
                }
            }
            .foregroundStyle(lit ? Color(nsColor: .alternateSelectedControlTextColor) : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .listRowBackground(lit ? RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color(nsColor: .selectedContentBackgroundColor)).padding(.horizontal, 6) : nil)
        .accessibilityLabel(CurrencyPicker.label(code))
        .accessibilityAddTraits(code == selection ? .isSelected : [])
        .id(code)
    }

    private func command(_ selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            move(1)
        case #selector(NSResponder.moveUp(_:)):
            move(-1)
        case #selector(NSResponder.insertNewline(_:)):
            if let code = highlighted.flatMap({ flat.contains($0) ? $0 : nil }) ?? flat.first { onPick(code) }
        case #selector(NSResponder.cancelOperation(_:)):
            // Esc clears a search first, then closes.
            guard query.isEmpty else { return false }
            onCancel()
        default:
            return false
        }
        return true
    }

    private func move(_ step: Int) {
        let order = flat
        guard !order.isEmpty else { return }
        let current = highlighted.flatMap { order.firstIndex(of: $0) }
        let next = current.map { min(max($0 + step, 0), order.count - 1) } ?? (step > 0 ? 0 : order.count - 1)
        highlighted = order[next]
    }
}
