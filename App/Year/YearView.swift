import SubusCore
import SwiftUI

/// The Year window's content: the data banners, the summary, and under it the grid on the left and the side pane
/// on the right — or, when there is nothing to draw, the state that says why. The plan comes from `YearPlanCache`,
/// rebuilt only when the library, settings, rates, day, filter or locale change.
struct YearView: View {
    let model: AppModel
    @Bindable var state: YearState
    let onEdit: (UUID) -> Void
    let onAdd: () -> Void

    /// The room under the summary, shared by the grid card and the side pane.
    @State private var room = CGSize(width: 1060, height: 540)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let padding: CGFloat = 20
    static let spacing: CGFloat = 20
    static let cardPadding: CGFloat = 16

    init(model: AppModel, state: YearState, onEdit: @escaping (UUID) -> Void, onAdd: @escaping () -> Void) {
        self.model = model
        self.state = state
        self.onEdit = onEdit
        self.onAdd = onAdd
    }

    var body: some View {
        let today = model.today
        let inputs = inputs(today: today)
        let plan = state.cache.plan(inputs)
        let version = state.cache.version
        let screen = YearScreenState.resolve(plan: plan, library: model.library, isUnreadable: model.isUnreadable)
        NavigationStack(path: $state.path) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(DataBanners.make(model: model)) { $0 }
                content(screen, plan: plan, inputs: inputs, today: today)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                if state.windowWidth != width { state.windowWidth = width }
            }
            .yearToolbar(model: model, state: state, period: plan.range)
            .navigationDestination(for: UUID.self) { id in
                SubscriptionPage(model: model, id: id, onEdit: onEdit)
                    .yearBackButton(state: state)
            }
        }
        // The plan holds both weeks and months, so the selection carries over without a rebuild.
        .onChange(of: state.mode) { old, new in
            state.selection = YearSelection.carry(state.selection, from: old, to: new, plan: plan, today: today)
        }
        // A rebuilt plan keeps the selected cell when its date is still in the period, else takes the current one.
        .onChange(of: version, initial: true) {
            let carried = YearSelection.carry(state.selection, from: state.mode, to: state.mode, plan: plan, today: today)
            if carried != state.selection { state.selection = carried }
        }
        .onChange(of: model.library, initial: true) { _, library in
            let pruned = state.filter.pruned(to: library)
            if pruned != state.filter { state.filter = pruned }
            // A subscription deleted while its page is open: back to the year.
            let ids = Set(library.subscriptions.map(\.id))
            if !state.path.allSatisfy(ids.contains) { state.navigate(reduceMotion: reduceMotion) { $0.path.removeAll() } }
        }
        .onChange(of: screen, initial: true) { _, screen in
            if screen == .noChargesThisYear { state.pane = .all }
        }
    }

    private func inputs(today: LocalDate) -> YearPlanCache.Inputs {
        YearPlanCache.Inputs(library: model.library, filter: state.filter, today: today,
                             baseCurrency: model.settings.baseCurrency, rates: model.rates, localeTick: state.localeTick)
    }

    @ViewBuilder
    private func content(_ screen: YearScreenState, plan: YearPlan, inputs: YearPlanCache.Inputs,
                         today: LocalDate) -> some View {
        switch screen {
        case .unreadable:
            // The data file was not read: the banner says so, and an empty year is not drawn as a new library.
            Spacer(minLength: 0)
        case .noSubscriptions:
            PanelEmptyState(title: String(localized: "No subscriptions yet"),
                            message: String(localized: "Add one and Subus shows how many days are left until each charge."),
                            actionTitle: String(localized: "Add your first subscription"), action: onAdd)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .nothingMatches:
            summary(plan)
                .padding(.horizontal, Self.padding)
                .padding(.top, 16)
            PanelEmptyState(systemImage: "magnifyingglass", title: String(localized: "Nothing found"), message: nil,
                            actionTitle: String(localized: "Reset filters"), action: { state.filter = YearFilter() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .noChargesThisYear, .grid:
            VStack(alignment: .leading, spacing: 16) {
                summary(plan)
                main(plan: plan, inputs: inputs, today: today, emptyYear: screen == .noChargesThisYear)
            }
            .padding(.horizontal, Self.padding)
            .padding(.top, 16)
            .padding(.bottom, Self.padding)
        }
    }

    private func summary(_ plan: YearPlan) -> some View {
        YearSummary(plan: plan, ratesDate: model.rates?.date, excludedNames: names(plan.excludedSubscriptionIDs))
    }

    /// The grid card takes what the side pane leaves, and the side pane takes what a full-size grid leaves
    /// (320 pt at least): past 56 pt cells a wider window widens the pane.
    private func main(plan: YearPlan, inputs: YearPlanCache.Inputs, today: LocalDate, emptyYear: Bool) -> some View {
        let mode = state.mode
        let weekColumns = plan.weekColumns().count
        let fullGrid = YearGrid.contentWidth(weekColumns: weekColumns, mode: .weeks, width: .infinity) + Self.cardPadding * 2
        let side = min(460, max(YearSidePane.minWidth, room.width - Self.spacing - fullGrid))
        let gridRoom = max(0, room.width - Self.spacing - side)
        let cellRoom = gridRoom - Self.cardPadding * 2
        let note: CGFloat = emptyYear ? 30 : 0
        // The card's padding, the legend and its spacing, and a little air under the card.
        let cellHeight = room.height - Self.cardPadding * 2 - 2 - 28 - 12 - note
        let selection = YearSelection.carry(state.selection, from: mode, to: mode, plan: plan, today: today)
        let period = (mode == .weeks ? plan.weeks : plan.months).first { $0.id == selection }
        return HStack(alignment: .top, spacing: Self.spacing) {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 14) {
                    if emptyYear {
                        Text("No charges in the next 12 months")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    YearGrid(plan: plan, mode: mode,
                             selection: Binding(get: { selection }, set: { state.selection = $0 }),
                             today: today, width: cellRoom, height: cellHeight,
                             onOpen: { id in state.navigate(reduceMotion: reduceMotion) { $0.path.append(id) } })
                    YearLegend(mode: mode)
                }
                .frame(width: YearGrid.contentWidth(weekColumns: weekColumns, mode: mode, width: cellRoom),
                       alignment: .leading)
                .padding(Self.cardPadding)
                .padding(.top, 2)
                .background(YearCard())
            }
            .scrollIndicators(.automatic)
            .frame(width: gridRoom, alignment: .topLeading)
            YearSidePane(model: model, state: state, plan: plan, period: period,
                         rows: { state.cache.rows(inputs, sort: state.sort) }, today: today)
                .frame(width: side)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { room = $0 }
    }

    private func names(_ ids: [UUID]) -> [String] {
        ids.compactMap { id in model.library.subscriptions.first { $0.id == id }?.name }
    }
}

/// The grid's surface: #FBFBF9 / #232325 at a 16 pt radius, edged by a hairline.
struct YearCard: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(Color(scheme == .dark ? YearRamp.cardDark : YearRamp.cardLight))
            .overlay(shape.strokeBorder(Color.primary.opacity(scheme == .dark ? 0.12 : 0.08), lineWidth: 0.5))
    }
}

/// The plan and the All subscriptions rows, built once per change of their inputs: selecting a cell,
/// hovering or switching the pane redraws the window without building the year again.
@MainActor
final class YearPlanCache {
    struct Inputs: Equatable {
        let library: Library
        let filter: YearFilter
        let today: LocalDate
        let baseCurrency: String
        let rates: RateTable?
        /// `firstWeekday` and the formatters follow the locale.
        let localeTick: Int
    }

    /// Bumped on every rebuild of the plan.
    private(set) var version = 0
    private var planKey: Inputs?
    private var plan: YearPlan?
    private var rowsKey: (Inputs, YearSort)?
    private var rows: [YearSubscriptionRow] = []

    func plan(_ inputs: Inputs) -> YearPlan {
        if let plan, planKey == inputs { return plan }
        let built = YearPlan.build(library: inputs.library, filter: inputs.filter, today: inputs.today,
                                   calendar: .subus(), baseCurrency: inputs.baseCurrency,
                                   converter: CurrencyConverter(table: inputs.rates))
        plan = built
        planKey = inputs
        version += 1
        return built
    }

    func rows(_ inputs: Inputs, sort: YearSort) -> [YearSubscriptionRow] {
        if let key = rowsKey, key.0 == inputs, key.1 == sort { return rows }
        rows = YearPlan.subscriptionRows(library: inputs.library, filter: inputs.filter, today: inputs.today,
                                         baseCurrency: inputs.baseCurrency,
                                         converter: CurrencyConverter(table: inputs.rates), sort: sort)
        rowsKey = (inputs, sort)
        return rows
    }
}

/// "Charged in the next 12 months", the sum at 28 pt (with "+ N without a rate" when part of it has no rate),
/// and a caption: the number of charges, the monthly average and the rate date, then the trials at their
/// future price and the subscriptions left out for want of a rate, named in that note's tooltip.
/// A forecast by schedule, unlike the panel's normalised "… / year".
struct YearSummary: View {
    let plan: YearPlan
    let ratesDate: LocalDate?
    /// The subscriptions left out of the sum for want of a rate, named in the tooltip.
    let excludedNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(localized: "Charged in the next 12 months"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: totalText)
                    .font(.system(size: 28, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if case .partial(_, let missing) = plan.total.display {
                    Text(verbatim: "+ " + YearFormat.withoutRate(missing))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: firstLine)
                if !notes.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                            let text = Text(verbatim: (index > 0 ? " · " : "") + note.text)
                            if let help = note.help { text.help(help) } else { text }
                        }
                    }
                }
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
    }

    private var totalText: String {
        switch plan.total.display {
        case .zero: Formatters.total(plan.total.amount)
        case .amount(let m), .partial(let m, _): Formatters.total(m)
        case .unavailable: "—"
        }
    }

    private var firstLine: String {
        var parts = [String(localized: "\(plan.charges.count) charges")]
        switch plan.total.display {
        case .amount(let m), .partial(let m, _):
            let monthly = Money(m.amount / 12, m.currency)
            parts.append(String(localized: "≈ \(Formatters.total(monthly)) / month"))
        case .zero, .unavailable:
            break
        }
        if let ratesDate { parts.append(String(localized: "CBR rate on \(Formatters.dayMonth(ratesDate))")) }
        return parts.joined(separator: " · ")
    }

    /// The second line's notes; only the one about subscriptions without a rate carries a tooltip.
    private var notes: [(text: String, help: String?)] {
        var result: [(text: String, help: String?)] = []
        let trials = plan.trialSubscriptionIDs.count
        if trials > 0 { result.append((String(localized: "includes \(trials) trials at their future price"), nil)) }
        let excluded = plan.excludedSubscriptionIDs.count
        if excluded > 0 {
            result.append((String(localized: "excluding \(excluded) subscriptions (no rate)"),
                           excludedNames.joined(separator: ", ")))
        }
        return result
    }
}
