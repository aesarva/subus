import SubusCore
import SwiftUI

/// One row on All: what the row draws and what VoiceOver reads.
struct AllItem: Identifiable {
    let subscription: Subscription
    let categoryName: String?
    /// The category's line colour index; nil rides the rail colour.
    let lineIndex: Int?
    /// Set when the subscription's end date has passed.
    let endedOn: LocalDate?
    var id: UUID { subscription.id }
}

/// What All shows for the current search and category filter.
struct AllRows {
    var live: [AllItem]
    var inactive: [AllItem]
    /// The Inactive section is open: by choice, or because nothing live is left to show.
    var inactiveShown: Bool
    var isEmpty: Bool { live.isEmpty && inactive.isEmpty }
    /// Row order for ↑/↓.
    var order: [UUID] { (live + (inactiveShown ? inactive : [])).map(\.id) }
}

/// "All": a search field and a category filter over every live subscription, alphabetically,
/// then the collapsed Inactive section (paused and ended ones). Rows are the strip map's, without the spine.
struct AllTab: View {
    let model: AppModel
    @Bindable var state: PanelState
    let actions: PanelActions
    /// The row with keyboard focus (Tab under full keyboard access); kept the same row as the selection.
    @FocusState private var focusedRow: UUID?

    var body: some View {
        if model.library.subscriptions.isEmpty {
            PanelEmptyState(title: String(localized: "No subscriptions yet"),
                            message: String(localized: "Add one and Subus shows how many days are left until each charge."),
                            actionTitle: String(localized: "Add your first subscription"), action: actions.onAdd)
        } else {
            controls
            let rows = Self.rows(model, state)
            if rows.isEmpty {
                noResults
            } else {
                list(rows)
                    .layoutValue(key: ScrollingPart.self, value: true)
            }
        }
    }

    // MARK: Content

    static func rows(_ model: AppModel, _ state: PanelState) -> AllRows {
        let today = model.today
        let query = state.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filter = state.categoryFilter.flatMap { id in model.library.categories.contains { $0.id == id } ? id : nil }
        let matching = model.library.subscriptions
            .filter { s in
                (filter == nil || s.categoryID == filter)
                    && (query.isEmpty || s.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil)
            }
            .sorted { a, b in
                let order = a.name.localizedStandardCompare(b.name)
                return order == .orderedSame ? a.id.uuidString < b.id.uuidString : order == .orderedAscending
            }
            .map { s in
                let category = model.category(s.categoryID)
                return AllItem(subscription: s, categoryName: category?.name, lineIndex: category?.colorIndex,
                               endedOn: s.isEnded(today: today) ? s.endDate : nil)
            }
        let live = matching.filter { $0.subscription.isLive(today: today) }
        let inactive = matching.filter { !$0.subscription.isLive(today: today) }
        return AllRows(live: live, inactive: inactive, inactiveShown: state.inactiveExpanded || live.isEmpty)
    }

    private var controls: some View {
        HStack(spacing: 8) {
            SearchField(text: $state.search, prompt: String(localized: "Search"),
                        onRegister: { [state] field in if state.searchField !== field { state.searchField = field } })
            Picker(String(localized: "Category"), selection: $state.categoryFilter) {
                Text("All categories").tag(UUID?.none)
                Divider()
                ForEach(model.library.categories) { category in
                    Text(verbatim: category.name).tag(UUID?.some(category.id))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .help(String(localized: "Category"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder private var noResults: some View {
        let query = state.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = model.category(state.categoryFilter)?.name
        if !query.isEmpty {
            PanelEmptyState(systemImage: "magnifyingglass",
                            title: String(localized: "No subscriptions match “\(query)”"),
                            message: category.map { String(localized: "Searching in “\($0)” only.") },
                            actionTitle: String(localized: "Clear search"), action: { state.search = "" })
        } else {
            PanelEmptyState(systemImage: "line.3.horizontal.decrease.circle",
                            title: String(localized: "No subscriptions in “\(category ?? "")”"),
                            message: nil, actionTitle: String(localized: "Show all categories"),
                            action: { state.categoryFilter = nil })
        }
    }

    private func list(_ rows: AllRows) -> some View {
        let logos = model.logosDirectory ?? FileManager.default.temporaryDirectory
        let today = model.today
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows.live) { item in
                        row(item, logos: logos, today: today)
                    }
                    if !rows.inactive.isEmpty {
                        inactiveHead(count: rows.inactive.count, collapsible: !rows.live.isEmpty,
                                     expanded: rows.inactiveShown)
                        if rows.inactiveShown {
                            ForEach(rows.inactive) { item in
                                row(item, logos: logos, today: today)
                            }
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.automatic)
            .onChange(of: state.allSelection) { _, id in
                if let id { proxy.scrollTo(id) }
                if focusedRow != nil, focusedRow != id { focusedRow = id }
            }
            .onChange(of: focusedRow) { _, id in
                if let id, state.allSelection != id { state.allSelection = id }
            }
            // Back from a card: the row it was opened from comes into view again, and takes the focus back.
            .onAppear {
                let restore = state.restoreRowFocus
                state.restoreRowFocus = false
                guard let id = state.allSelection else { return }
                proxy.scrollTo(id)
                Task { @MainActor in
                    proxy.scrollTo(id)
                    if restore { focusedRow = id }
                }
            }
        }
    }

    private func row(_ item: AllItem, logos: URL, today: LocalDate) -> some View {
        AllRow(item: item, logosDirectory: logos, today: today, lifted: state.allFocus == item.id,
               onHover: { id, inside in state.hoverAllRow(id, inside: inside) }, onOpen: actions.onOpen)
            .focused($focusedRow, equals: item.id)
            .id(item.id)
    }

    /// The disclosure head of the Inactive section; when nothing live is shown it is always open.
    @ViewBuilder
    private func inactiveHead(count: Int, collapsible: Bool, expanded: Bool) -> some View {
        let title = HStack(spacing: 5) {
            Text("Inactive")
                .tracking(0.7)
                .textCase(.uppercase)
            Text(verbatim: "\(count)")
                .monospacedDigit()
            if collapsible {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .padding(.leading, 16)
        .padding(.top, 10)
        .contentShape(Rectangle())

        if collapsible {
            Button { state.inactiveExpanded.toggle() } label: { title }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Inactive") + ", \(count)")
                .accessibilityValue(expanded ? String(localized: "expanded") : String(localized: "collapsed"))
                .accessibilityAddTraits(.isHeader)
        } else {
            title
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// One subscription: logo tile, name, the category with its line colour, and the price per period tight to the margin.
private struct AllRow: View {
    let item: AllItem
    let logosDirectory: URL
    let today: LocalDate
    let lifted: Bool
    let onHover: (UUID, Bool) -> Void
    let onOpen: (UUID) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let s = item.subscription
        Button { onOpen(s.id) } label: {
            HStack(spacing: 10) {
                LogoView(subscription: s, size: 24, logosDirectory: logosDirectory)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: s.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                    if item.categoryName != nil || status != nil {
                        secondary
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: Formatters.money(s.price))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    Text(verbatim: "/ " + Formatters.cycle(s.cycle))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .fixedSize()
                .layoutPriority(1)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.vertical, 5)
            .frame(minHeight: 42)
            .background {
                if lifted {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(scheme == .dark ? 0.11 : 0.07))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainRowButtonStyle())
        .onContinuousHover { phase in
            switch phase {
            case .active: onHover(s.id, true)
            case .ended: onHover(s.id, false)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var secondary: some View {
        HStack(spacing: 5) {
            if let name = item.categoryName {
                StationRing(lineIndex: item.lineIndex)
                Text(verbatim: name)
                    .lineLimit(1)
            }
            if let status {
                if item.categoryName != nil { Text(verbatim: "·") }
                Text(verbatim: status)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 11).monospacedDigit())
        .foregroundStyle(.secondary)
    }

    /// "Ended <date>", or "Inactive" for one switched off: the same word as the card's tag and toggle.
    private var status: String? {
        if let ended = item.endedOn { return String(localized: "Ended \(Formatters.date(ended, today: today))") }
        if !item.subscription.isActive { return String(localized: "status.inactive", defaultValue: "Inactive") }
        return nil
    }

    private var accessibilityText: String {
        let s = item.subscription
        var parts = [s.name, Formatters.money(s.price) + " " + Formatters.spokenCycle(s.cycle)]
        if let category = item.categoryName { parts.append(category) }
        if let status { parts.append(status) }
        return parts.joined(separator: ", ")
    }

}
