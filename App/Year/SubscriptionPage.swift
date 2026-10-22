import SubusCore
import SwiftUI

/// A subscription's page, pushed over the year in the same window: who and how much, its next 12 months as a week
/// grid with a station in each week it charges and the list of those charges beside it, then the price history
/// and the details. It reads the subscription from the model on every draw, so an edit shows at once; a deleted
/// one leaves the page to `YearView`, which goes back to the year.
struct SubscriptionPage: View {
    let model: AppModel
    let id: UUID
    let onEdit: (UUID) -> Void

    /// The week picked in the grid, by its start; its charges are lit in the list.
    @State private var selection: LocalDate?
    @State private var room: CGFloat = 1060

    private static let padding: CGFloat = 20
    private static let spacing: CGFloat = 20

    init(model: AppModel, id: UUID, onEdit: @escaping (UUID) -> Void) {
        self.model = model
        self.id = id
        self.onEdit = onEdit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(DataBanners.make(model: model)) { $0 }
            if let s = subscription {
                page(s)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var subscription: Subscription? { model.library.subscriptions.first { $0.id == id } }
    private var today: LocalDate { model.today }
    private var base: String { model.settings.baseCurrency }

    private func page(_ s: Subscription) -> some View {
        let converter = CurrencyConverter(table: model.rates)
        let year = SubscriptionYear.build(s, today: today, baseCurrency: base, converter: converter)
        var library = model.library
        library.subscriptions = [s]
        let plan = YearPlan.build(library: library, filter: YearFilter(), today: today, calendar: .subus(),
                                  baseCurrency: base, converter: converter)
        // The grid takes what the charges column leaves, as on the year; at the window's minimum 14 columns still fit.
        let columns = plan.weekColumns()
        let weekColumns = columns.count, weekRows = columns.map(\.weeks.count).max() ?? 0
        let card = YearView.cardPadding * 2
        let fullGrid = YearGrid.contentWidth(weekColumns: weekColumns, weekRows: weekRows, mode: .weeks, width: .infinity)
            + card
        let side = min(420, max(280, room - Self.spacing - fullGrid))
        let left = max(0, room - Self.spacing - side)
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 24) {
                    SubscriptionPageHeader(model: model, subscription: s, onEdit: onEdit)
                    if year.charges.isEmpty {
                        VStack(alignment: .leading, spacing: 24) {
                            yearSection(s, year: year, plan: plan, weekColumns: weekColumns, weekRows: weekRows,
                                        cellRoom: 0)
                            SubscriptionPageFacts(model: model, subscription: s)
                        }
                        .frame(maxWidth: 640, alignment: .leading)
                    } else {
                        HStack(alignment: .top, spacing: Self.spacing) {
                            VStack(alignment: .leading, spacing: 24) {
                                yearSection(s, year: year, plan: plan, weekColumns: weekColumns, weekRows: weekRows,
                                            cellRoom: left - card)
                                SubscriptionPageFacts(model: model, subscription: s)
                            }
                            .frame(width: left, alignment: .leading)
                            charges(year, plan: plan)
                                .frame(width: side, alignment: .leading)
                        }
                    }
                }
                .padding(Self.padding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
            // The first selection is the page's own, made on appear: the page stays at its top.
            .onChange(of: selection) { old, week in
                guard old != nil, let week, let period = plan.weeks.first(where: { $0.id == week }),
                      let first = period.charges.first else { return }
                proxy.scrollTo(first.charge.date)
            }
            // The arrows walk from a selected week: the page opens on the week of the next charge, which is this
            // week when it charges, so its charge is lit at once.
            .onAppear {
                guard selection == nil, let next = year.charges.first?.charge.date else { return }
                selection = plan.weeks.first { $0.start <= next && next <= $0.end }?.id
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { room = $0 - Self.padding * 2 }
    }

    // MARK: In the next 12 months

    @ViewBuilder
    private func yearSection(_ s: Subscription, year: SubscriptionYear, plan: YearPlan, weekColumns: Int, weekRows: Int,
                             cellRoom: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if year.charges.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("No charges in the next year")
                        .font(.system(size: 13, weight: .medium))
                    if let next = year.next {
                        Text(verbatim: String(localized: "next — \(Formatters.date(next.date, today: today))"))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(YearView.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(YearCard())
            } else {
                let sum = sum(year)
                // The year's own words over the figure, as the year's summary: no eyebrow.
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Charged in the next 12 months"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: sum.main)
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                        if let approx = sum.approx {
                            Text(verbatim: approx)
                                .font(.system(size: 13).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(verbatim: String(localized: "\(year.charges.count) charges"))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .padding(.bottom, 6)
                YearGrid(plan: plan, mode: .weeks, selection: $selection, today: today, width: cellRoom,
                         highlight: .init(lineColor: model.category(s.categoryID)?.color))
                    .frame(width: YearGrid.contentWidth(weekColumns: weekColumns, weekRows: weekRows, mode: .weeks,
                                                        width: cellRoom),
                           alignment: .leading)
                    .padding(YearView.cardPadding)
                    .padding(.top, 2)
                    .background(YearCard())
            }
        }
    }

    /// The year's sum in the subscription's own currency with "≈ base" beside it; in the base currency alone
    /// when the charges are in it, or in several currencies.
    private func sum(_ year: SubscriptionYear) -> (main: String, approx: String?) {
        let currencies = Set(year.charges.map(\.charge.amount.currency))
        guard currencies.count == 1, let currency = currencies.first, currency != base else {
            return (YearFormat.money(year.total), nil)
        }
        let own = Money(year.charges.reduce(Decimal(0)) { $0 + $1.charge.amount.amount }, currency)
        let converted = year.total.display == .unavailable ? nil : "≈ " + YearFormat.money(year.total)
        return (Formatters.total(own), converted)
    }

    // MARK: Charges

    private func charges(_ year: SubscriptionYear, plan: YearPlan) -> some View {
        let lit = plan.weeks.first { $0.id == selection }
        return VStack(alignment: .leading, spacing: 8) {
            PageSectionHead(title: String(localized: "Charges"))
            VStack(spacing: 0) {
                ForEach(year.charges, id: \.charge.date) { c in
                    let date = c.charge.date
                    ChargeLine(charge: c, today: today, base: base,
                               isNext: year.next?.date == date, isNewPrice: year.firstAtNewPrice.contains(date),
                               isLit: lit.map { $0.start <= date && date <= $0.end } ?? false) {
                        selection = plan.weeks.first { $0.start <= date && date <= $0.end }?.id
                    }
                    .id(date)
                }
            }
            .padding(.horizontal, -8)
        }
    }
}

/// "‹ Year" in the toolbar's navigation place, with Esc and ⌘[. The year's selection and scroll live in
/// `YearState` and its views, so they are as they were on return; under Reduce Motion the page leaves at once.
private struct YearBackButton: ViewModifier {
    @Bindable var state: YearState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: back) {
                        Label(String(localized: "Year"), systemImage: "chevron.left")
                    }
                    .labelStyle(.titleAndIcon)
                    .keyboardShortcut(.escape, modifiers: [])
                    .help(String(localized: "Back (Esc)"))
                }
            }
            // A second shortcut needs a second button: ⌘[, out of sight and out of VoiceOver's way.
            .background {
                Button(action: back) { EmptyView() }
                    .keyboardShortcut("[", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }

    private func back() {
        state.navigate(reduceMotion: reduceMotion) { if !$0.path.isEmpty { $0.path.removeLast() } }
    }
}

extension View {
    func yearBackButton(state: YearState) -> some View { modifier(YearBackButton(state: state)) }
}
