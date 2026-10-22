import SubusCore
import SwiftUI

/// The right pane: Week (or Month) | All subscriptions. The first shows the selected cell — its title,
/// count and sum, and its charges by date, or, when it has none, the nearest charge after it.
/// The second lists every subscription that passes the filter, sorted. A row opens the subscription's page.
struct YearSidePane: View {
    let model: AppModel
    @Bindable var state: YearState
    let plan: YearPlan
    /// The selected week or month.
    let period: YearPeriod?
    /// The All subscriptions rows; built only while that pane shows.
    let rows: () -> [YearSubscriptionRow]
    let today: LocalDate

    static let minWidth: CGFloat = 320

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(String(localized: "Show"), selection: $state.pane) {
                Text(state.mode == .weeks ? String(localized: "Week") : String(localized: "Month")).tag(YearPane.period)
                Text("All subscriptions").tag(YearPane.all)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            switch state.pane {
            case .period: periodPane
            case .all: allPane
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var logos: URL { model.logosDirectory ?? FileManager.default.temporaryDirectory }

    private func open(_ id: UUID) { state.navigate(reduceMotion: reduceMotion) { $0.path.append(id) } }

    // MARK: Week / Month

    @ViewBuilder private var periodPane: some View {
        if let period {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: YearFormat.title(period, mode: state.mode))
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: YearFormat.countAndSum(period))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if period.charges.isEmpty {
                emptyPeriod(period)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(period.charges, id: \.charge) { charge in
                            chargeRow(charge)
                        }
                    }
                }
                .scrollIndicators(.automatic)
                .padding(.horizontal, -8)
            }
        }
    }

    @ViewBuilder private func emptyPeriod(_ period: YearPeriod) -> some View {
        Text(state.mode == .weeks ? String(localized: "No charges this week") : String(localized: "No charges this month"))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        if let next = plan.charges.first(where: { $0.charge.date > period.end }) {
            VStack(alignment: .leading, spacing: 2) {
                Text("next")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                chargeRow(next)
                    .padding(.horizontal, -8)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder private func chargeRow(_ c: YearCharge) -> some View {
        if let s = model.library.subscriptions.first(where: { $0.id == c.charge.subscriptionID }) {
            let category = model.category(s.categoryID)
            let converted = c.charge.amount.currency != model.settings.baseCurrency ? c.converted.map(Formatters.total) : nil
            let card = model.paymentMethod(s.paymentMethodID)?.label
            let yearly = CycleKind(s.cycle) == .yearly
            YearRow(subscription: s, logosDirectory: logos, lineColor: category?.color,
                    tag: c.isTrialFuturePrice ? AnyView(TrialTag()) : nil,
                    details: chargeDetails(c, s), label: card,
                    amount: Formatters.money(c.charge.amount), under: converted.map { "≈ " + $0 },
                    // "Spotify, Mon, Oct 26, card T-Bank •• 4242, $20, about RUB 1,632, once a year, trial".
                    spoken: [s.name, Formatters.shortDate(c.charge.date, today: today)]
                        + [card.map { String(localized: "card \($0)") }, Formatters.money(c.charge.amount),
                           converted.map { String(localized: "about \($0)") },
                           yearly ? String(localized: "once a year") : nil,
                           c.isTrialFuturePrice ? String(localized: "trial") : nil].compactMap { $0 },
                    onOpen: open)
        }
    }

    /// "Wed, Feb 12 · once a year"; the card follows it in the row.
    private func chargeDetails(_ c: YearCharge, _ s: Subscription) -> String {
        var parts = [Formatters.shortDate(c.charge.date, today: today)]
        if CycleKind(s.cycle) == .yearly { parts.append(String(localized: "once a year")) }
        return parts.joined(separator: " · ")
    }

    // MARK: All subscriptions

    @ViewBuilder private var allPane: some View {
        let rows = rows()
        // The filter passes only inactive or ended subscriptions, and they are hidden: say so, not an empty list.
        if rows.isEmpty, !state.filter.showInactive, !plan.matchedSubscriptionIDs.isEmpty {
            PanelEmptyState(systemImage: "pause.circle", title: String(localized: "All subscriptions are inactive"),
                            message: nil, actionTitle: String(localized: "Show inactive"),
                            action: { state.filter.showInactive = true })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            allList(rows)
        }
    }

    @ViewBuilder private func allList(_ rows: [YearSubscriptionRow]) -> some View {
        HStack {
            Text(verbatim: String(localized: "\(rows.count) subscriptions"))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Picker(String(localized: "Sort"), selection: $state.sort) {
                Text("By total").tag(YearSort.total)
                Text("By date").tag(YearSort.nextDate)
                Text("By name").tag(YearSort.name)
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    subscriptionRow(row)
                }
            }
        }
        .scrollIndicators(.automatic)
        .padding(.horizontal, -8)
    }

    private func subscriptionRow(_ row: YearSubscriptionRow) -> some View {
        let s = row.subscription
        let category = model.category(s.categoryID)
        let price = Formatters.perCycle(s.currentPrice(today: today), s.cycle)
        let next = row.year.next.map { String(localized: "next — \(Formatters.date($0.date, today: today))") }
        let status: String? = s.isEnded(today: today) ? String(localized: "Ended")
            : !s.isActive ? String(localized: "status.inactive", defaultValue: "Inactive") : nil
        let tag: AnyView? = status.map { AnyView(OutlineTag(text: $0, color: .secondary)) }
            ?? (YearFilter.isTrial(s, today: today) ? AnyView(TrialTag()) : nil)
        return YearRow(subscription: s, logosDirectory: logos, lineColor: category?.color, tag: tag,
                       details: ([price] + (category.map { [$0.name] } ?? [])).joined(separator: " · "),
                       amount: YearFormat.money(row.year.total), under: next,
                       spoken: [s.name, price, YearFormat.money(row.year.total)] + [category?.name, status, next].compactMap { $0 },
                       onOpen: open)
    }
}

/// One row of the side pane: a 28 pt logo, the name with its tag, the category ring and a details line,
/// and on the right an amount with a line under it.
private struct YearRow: View {
    let subscription: Subscription
    let logosDirectory: URL
    let lineColor: CategoryColor?
    let tag: AnyView?
    let details: String
    /// The card, after the details; it gives way first and keeps its "•• 4242".
    var label: String? = nil
    let amount: String
    let under: String?
    let spoken: [String]
    let onOpen: (UUID) -> Void

    @State private var hovered = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button { onOpen(subscription.id) } label: {
            HStack(spacing: 10) {
                LogoView(subscription: subscription, size: 28, logosDirectory: logosDirectory)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(verbatim: subscription.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let tag { tag }
                    }
                    HStack(spacing: 5) {
                        StationRing(lineColor: lineColor)
                        HStack(spacing: 0) {
                            Text(verbatim: details)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(1)
                            if let label {
                                let (head, tail) = PaymentLabel.split(label)
                                Text(verbatim: " · " + head)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                if let tail { Text(verbatim: " " + tail).fixedSize().layoutPriority(1) }
                            }
                        }
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(verbatim: amount)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    if let under {
                        Text(verbatim: under)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .fixedSize()
                .layoutPriority(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 46)
            .background {
                if hovered {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(scheme == .dark ? 0.11 : 0.06))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainRowButtonStyle())
        .onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }
}
