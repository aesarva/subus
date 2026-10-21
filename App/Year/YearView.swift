import SubusCore
import SwiftUI

/// The Year window's content: the toolbar, the summary, and under it the grid on the left and the side pane
/// on the right. The plan is rebuilt from the model on every change of the library, settings, rates, day,
/// filter or locale, all read here through Observation.
struct YearView: View {
    let model: AppModel
    @Bindable var state: YearState
    let onEdit: (UUID) -> Void
    let onAdd: () -> Void

    init(model: AppModel, state: YearState, onEdit: @escaping (UUID) -> Void, onAdd: @escaping () -> Void) {
        self.model = model
        self.state = state
        self.onEdit = onEdit
        self.onAdd = onAdd
    }

    var body: some View {
        let _ = state.localeTick
        let today = model.today
        let plan = YearPlan.build(library: model.library, filter: state.filter, today: today, calendar: .subus(),
                                  baseCurrency: model.settings.baseCurrency,
                                  converter: CurrencyConverter(table: model.rates))
        NavigationStack(path: $state.path) {
            VStack(alignment: .leading, spacing: 16) {
                YearSummary(plan: plan, ratesDate: model.rates?.date, excludedNames: names(plan.excludedSubscriptionIDs))
                HStack(alignment: .top, spacing: 16) {
                    // Task 6: the week or month grid, in its card, with the legend under it.
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Task 6: the side pane — the selected cell or all subscriptions.
                    Color.clear
                        .frame(minWidth: 320, idealWidth: 340, maxWidth: 380, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .yearToolbar(state: state, period: plan.range)
            // Task 7: `.navigationDestination(for: UUID.self)` pushes the subscription page.
        }
        // The plan holds both weeks and months, so the selection carries over without a rebuild.
        .onChange(of: state.mode) { old, new in
            state.selection = YearSelection.carry(state.selection, from: old, to: new, plan: plan, today: today)
        }
    }

    private func names(_ ids: [UUID]) -> [String] {
        ids.compactMap { id in model.library.subscriptions.first { $0.id == id }?.name }
    }
}

/// "Charged in the next 12 months", the sum at 28 pt, and a caption: the number of charges, the monthly
/// average and the rate date, then the trials at their future price and the subscriptions left out for want
/// of a rate. A forecast by schedule, unlike the panel's normalised "… / year".
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
            Text(verbatim: totalText)
                .font(.system(size: 28, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(captionLines, id: \.self) { line in
                    Text(verbatim: line).fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .accessibilityElement(children: .combine)
        .help(excludedNames.joined(separator: ", "))
    }

    private var totalText: String {
        switch plan.total.display {
        case .zero: Formatters.total(plan.total.amount)
        case .amount(let m), .partial(let m, _): Formatters.total(m)
        case .unavailable: "—"
        }
    }

    private var captionLines: [String] {
        var first = [String(localized: "\(plan.charges.count) charges")]
        switch plan.total.display {
        case .amount(let m), .partial(let m, _):
            let monthly = Money(m.amount / 12, m.currency)
            first.append(String(localized: "≈ \(Formatters.total(monthly)) / month"))
        case .zero, .unavailable:
            break
        }
        if let ratesDate { first.append(String(localized: "CBR rate on \(Formatters.dayMonth(ratesDate))")) }

        var second: [String] = []
        let trials = plan.trialSubscriptionIDs.count
        if trials > 0 { second.append(String(localized: "includes \(trials) trials at their future price")) }
        let excluded = plan.excludedSubscriptionIDs.count
        if excluded > 0 { second.append(String(localized: "excluding \(excluded) subscriptions (no rate)")) }
        return [first.joined(separator: " · ")] + (second.isEmpty ? [] : [second.joined(separator: " · ")])
    }
}
