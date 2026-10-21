import SubusCore
import SwiftUI

/// "Upcoming": the totals header, the 60-day overview line and the strip map of charges.
/// Its children flow into the panel's `CappedColumn`; only the strip map scrolls.
struct UpcomingTab: View {
    let model: AppModel
    let state: PanelState
    let actions: PanelActions
    /// The row with keyboard focus (Tab under full keyboard access); kept the same row as the selection.
    @FocusState private var focusedRow: ChargeKey?

    var body: some View {
        let today = model.today
        let live = model.library.subscriptions.filter { $0.isLive(today: today) }
        if model.library.subscriptions.isEmpty {
            PanelEmptyState(title: String(localized: "No subscriptions yet"),
                            message: String(localized: "Add one and Subus shows how many days are left until each charge."),
                            actionTitle: String(localized: "Add your first subscription"), action: actions.onAdd)
        } else if live.isEmpty {
            PanelEmptyState(title: String(localized: "All subscriptions are paused"),
                            message: nil, actionTitle: String(localized: "Show all"),
                            action: { state.tab = .all })
        } else {
            let sections = model.sections
            let items = model.upcomingItems(sections.flatMap(\.charges))
            SummaryHeader(summary: model.summary, liveCount: live.count, daysToNext: model.daysToNearest)
            OverviewLine(items: items, today: today, focus: state.focus,
                         onHover: { keys, inside in state.hoverStation(keys, inside: inside) })
                .padding(.horizontal, 16)
                .padding(.top, 4)
            if items.isEmpty {
                quietLine
            } else {
                strip(groups(sections, items: items))
                    .layoutValue(key: ScrollingPart.self, value: true)
            }
        }
    }

    private var quietLine: some View {
        let text: String
        if let nearest = model.nearestCharge {
            let name = nearest.0.name, date = Formatters.shortDate(nearest.1.date)
            text = String(localized: "No charges in the next 30 days — next: \(name), \(date)")
        } else {
            text = String(localized: "No upcoming charges")
        }
        return Text(verbatim: text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    private func strip(_ groups: [StripGroup]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                StripMap(groups: groups, logosDirectory: model.logosDirectory ?? FileManager.default.temporaryDirectory,
                         focus: state.focus, focusedRow: $focusedRow,
                         onHover: { key, inside in state.hoverRow(key, inside: inside) },
                         onOpen: actions.onOpen)
            }
            .scrollIndicators(.automatic)
            .onChange(of: state.selection) { _, key in
                if let key { proxy.scrollTo(key) }
                if focusedRow != nil, focusedRow != key { focusedRow = key }
            }
            .onChange(of: focusedRow) { _, key in
                if let key, state.selection != key { state.selection = key }
            }
            // Back from a card: the row it was opened from comes into view again, and takes the focus back.
            .onAppear {
                let restore = state.restoreRowFocus
                state.restoreRowFocus = false
                guard let key = state.selection else { return }
                proxy.scrollTo(key)
                Task { @MainActor in
                    proxy.scrollTo(key)
                    if restore { focusedRow = key }
                }
            }
            .onChange(of: state.stationHover) { _, keys in
                if let key = groups.lazy.flatMap(\.items).first(where: { keys.contains($0.id) })?.id {
                    proxy.scrollTo(key)
                }
            }
        }
    }

    private func groups(_ sections: [UpcomingSection], items: [UpcomingItem]) -> [StripGroup] {
        let converter = CurrencyConverter(table: model.rates)
        let base = model.settings.baseCurrency
        let byKey = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return sections.map { section in
            let rows = section.charges.compactMap { byKey[ChargeKey($0)] }
            var total = Decimal(0), converted = 0
            for row in rows {
                if let m = converter.convert(row.charge.amount, to: base) {
                    total += m.amount
                    converted += 1
                }
            }
            return StripGroup(group: section.group, items: rows,
                              total: converted > 0 ? Money(total, base) : nil, notConverted: rows.count - converted)
        }
    }
}

extension UpcomingTab {
    /// Row order for ↑/↓.
    static func keys(_ model: AppModel) -> [ChargeKey] {
        model.sections.flatMap(\.charges).map(ChargeKey.init)
    }
}
