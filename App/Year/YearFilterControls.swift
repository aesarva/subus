import SubusCore
import SwiftUI

/// The category chips in the toolbar: "All", one per category that has subscriptions, and "No category" when
/// some have none. Several may be on; "All" turns them off. When the chips do not fit the room the toolbar
/// leaves, the last ones move into a "More" menu, and then all of them into one "Categories" menu. The room is
/// worked out from the window (`YearToolbarMetrics`), because a toolbar item is laid out at its ideal width and
/// the system overflow menu, not `ViewThatFits`, would otherwise take the chips.
struct YearCategoryChips: View {
    let model: AppModel
    @Bindable var state: YearState
    /// The width left for the chips by the other toolbar items.
    let room: CGFloat

    private struct Chip: Identifiable {
        let id: UUID?
        let name: String
        let color: CategoryColor?
    }

    var body: some View {
        let chips = chips
        if let visible = Self.visibleCount(chips.map(\.name), room: room) {
            row(chips, visible: visible)
        } else {
            categoriesMenu(chips)
        }
    }

    /// The chips after "All" that fit: all of them, else the first four to one and "More"; nil — none fit,
    /// so one "Categories" menu takes their place.
    static func visibleCount(_ names: [String], room: CGFloat) -> Int? {
        let spacing = YearToolbarMetrics.chipSpacing
        let all = YearToolbarMetrics.button(String(localized: "All"))
        let more = YearToolbarMetrics.button(String(localized: "More")) + YearToolbarMetrics.chevron
        let widths = names.map { YearToolbarMetrics.button($0) + StationRing.diameter + 5 }  // ring and its gap
        for visible in [names.count] + [4, 3, 2, 1].filter({ $0 < names.count }) {
            let overflow = visible < names.count
            let items = CGFloat(1 + visible + (overflow ? 1 : 0))
            let used = all + widths.prefix(visible).reduce(0, +) + (overflow ? more : 0) + spacing * (items - 1)
            if used + YearToolbarMetrics.groupPadding <= room { return visible }
        }
        return nil
    }

    /// Categories in library order: those with subscriptions, and any chip still on.
    private var chips: [Chip] {
        let subscriptions = model.library.subscriptions
        let selected = state.filter.categoryIDs
        var result = model.library.categories
            .filter { c in selected.contains(c.id) || subscriptions.contains { $0.categoryID == c.id } }
            .map { Chip(id: $0.id, name: $0.name, color: $0.color) }
        if selected.contains(nil) || subscriptions.contains(where: { $0.categoryID == nil }) {
            result.append(Chip(id: nil, name: String(localized: "No category"), color: nil))
        }
        return result
    }

    private func row(_ chips: [Chip], visible: Int) -> some View {
        HStack(spacing: 4) {
            Toggle(String(localized: "All"), isOn: allBinding)
                .toggleStyle(.button)
            ForEach(chips.prefix(visible)) { chip in
                Toggle(isOn: binding(chip.id)) {
                    HStack(spacing: 5) {
                        StationRing(lineColor: chip.color)
                        Text(verbatim: chip.name)
                    }
                }
                .toggleStyle(.button)
            }
            if visible < chips.count {
                Menu(String(localized: "More")) {
                    ForEach(chips.dropFirst(visible)) { chip in
                        Toggle(chip.name, isOn: binding(chip.id))
                    }
                }
                .fixedSize()
            }
        }
        .fixedSize()
    }

    private func categoriesMenu(_ chips: [Chip]) -> some View {
        Menu(String(localized: "Categories")) {
            Toggle(String(localized: "All"), isOn: allBinding)
            Divider()
            ForEach(chips) { chip in
                Toggle(chip.name, isOn: binding(chip.id))
            }
        }
        .fixedSize()
    }

    private var allBinding: Binding<Bool> {
        Binding(get: { state.filter.categoryIDs.isEmpty },
                set: { if $0 { state.filter.categoryIDs = [] } })
    }

    private func binding(_ id: UUID?) -> Binding<Bool> {
        state.memberBinding(\.categoryIDs, id)
    }
}

/// The Filters menu: cards, billing cycle, currency, trials, inactive, and a reset. Its title counts
/// the conditions in effect.
struct YearFiltersMenu: View {
    let model: AppModel
    @Bindable var state: YearState

    var body: some View {
        let library = model.library, today = model.today
        let count = state.filter.activeCount
        Menu {
            Section(String(localized: "Cards")) {
                ForEach(library.paymentMethods) { method in
                    Toggle(method.label, isOn: binding(\.paymentMethodIDs, method.id))
                }
                if library.subscriptions.contains(where: { $0.paymentMethodID == nil }) {
                    Toggle(String(localized: "No card"), isOn: binding(\.paymentMethodIDs, nil))
                }
            }
            Section(String(localized: "Billing cycle")) {
                Toggle(String(localized: "Monthly"), isOn: binding(\.cycles, .monthly))
                Toggle(String(localized: "Yearly"), isOn: binding(\.cycles, .yearly))
                Toggle(String(localized: "cycle.other", defaultValue: "Other"), isOn: binding(\.cycles, .other))
            }
            let currencies = Set(library.subscriptions.map { $0.currentPrice(today: today).currency })
                .union(state.filter.currencies).sorted()
            if currencies.count > 1 || !state.filter.currencies.isEmpty {
                Section(String(localized: "Currency")) {
                    ForEach(currencies, id: \.self) { code in
                        Toggle(code, isOn: binding(\.currencies, code))
                    }
                }
            }
            Divider()
            Toggle(String(localized: "Trials at future price"), isOn: $state.filter.includeTrials)
            Toggle(String(localized: "Show inactive"), isOn: $state.filter.showInactive)
            Divider()
            Button(String(localized: "Reset filters")) { state.filter.resetConditions() }
                .disabled(state.filter == state.filter.withConditionsReset)
        } label: {
            Label {
                Text(verbatim: count > 0 ? String(localized: "Filters") + " · \(count)" : String(localized: "Filters"))
            } icon: {
                Image(systemName: count > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .labelStyle(.titleAndIcon)
        }
        .fixedSize()
        .help(String(localized: "Filters"))
    }

    private func binding<T: Hashable>(_ keyPath: WritableKeyPath<YearFilter, Set<T>>, _ value: T) -> Binding<Bool> {
        state.memberBinding(keyPath, value)
    }
}

extension YearFilter {
    /// Every condition back to its default; the search text stays.
    var withConditionsReset: YearFilter {
        var result = YearFilter()
        result.query = query
        return result
    }

    mutating func resetConditions() { self = withConditionsReset }
}

extension YearState {
    /// A switch for one member of one of the filter's sets.
    func memberBinding<T: Hashable>(_ keyPath: WritableKeyPath<YearFilter, Set<T>>, _ value: T) -> Binding<Bool> {
        Binding(get: { self.filter[keyPath: keyPath].contains(value) },
                set: { on in
                    if on { self.filter[keyPath: keyPath].insert(value) } else { self.filter[keyPath: keyPath].remove(value) }
                })
    }
}
