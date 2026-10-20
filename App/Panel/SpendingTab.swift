import SubusCore
import SwiftUI

/// One price increase row: unique even when a subscription rose twice in the year.
struct IncreaseKey: Hashable {
    let subscriptionID: UUID
    let on: LocalDate
}

/// One bar: a category or a payment method and its share of the month total.
struct SpendingBar: Identifiable {
    /// nil — no category or no payment method.
    let id: UUID?
    let name: String
    /// The line colour index; nil rides the rail colour.
    let lineIndex: Int?
    let monthly: Money
    let share: Double
}

/// "Spending": the month total with its notes, the month split by category and by payment method
/// in line-colour bars, and the price increases of the past year. Only the sections scroll.
struct SpendingTab: View {
    let model: AppModel
    let state: PanelState
    let actions: PanelActions

    var body: some View {
        let today = model.today
        let live = model.library.subscriptions.filter { $0.isLive(today: today) }
        if model.library.subscriptions.isEmpty {
            PanelEmptyState(systemImage: "calendar.badge.plus", title: String(localized: "No subscriptions yet"),
                            message: String(localized: "Add one and Subus shows how many days are left until each charge."),
                            actionTitle: String(localized: "Add your first subscription"), action: actions.onAdd)
        } else if live.isEmpty {
            PanelEmptyState(systemImage: "pause.circle", title: String(localized: "All subscriptions are paused"),
                            message: nil, actionTitle: String(localized: "Show all"),
                            action: { state.tab = .all })
        } else {
            let summary = model.summary
            SummaryHeader(summary: summary, liveCount: live.count, daysToNext: nil)
            sections(summary)
                .layoutValue(key: ScrollingPart.self, value: true)
        }
    }

    private func sections(_ summary: SpendingSummary) -> some View {
        let categories = Self.categoryBars(model, summary)
        let methods = Self.methodBars(model, summary)
        let increases = SummaryBuilder.priceIncreases(library: model.library, today: model.today)
        let logos = model.logosDirectory ?? FileManager.default.temporaryDirectory
        return ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    if !categories.isEmpty {
                        SpendingSectionHead(title: String(localized: "By category"))
                        ForEach(categories) { SpendingBarRow(bar: $0) }
                    }
                    if !methods.isEmpty {
                        SpendingSectionHead(title: String(localized: "By payment method"))
                        ForEach(methods) { SpendingBarRow(bar: $0) }
                    }
                    if !increases.isEmpty {
                        SpendingSectionHead(title: String(localized: "Price increases in the past year"))
                        ForEach(increases, id: \.key) { increase in
                            if let s = model.library.subscriptions.first(where: { $0.id == increase.subscriptionID }) {
                                IncreaseRow(subscription: s, increase: increase, logosDirectory: logos, today: model.today,
                                            lifted: state.spendingFocus == increase.key,
                                            onHover: { key, inside in state.hoverSpendingRow(key, inside: inside) },
                                            onOpen: actions.onOpen)
                                    .id(increase.key)
                            }
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.automatic)
            .onChange(of: state.spendingSelection) { _, key in
                if let key { proxy.scrollTo(key) }
            }
            .onAppear {
                if let key = state.spendingSelection { proxy.scrollTo(key) }
            }
        }
    }

    // MARK: Content

    /// Row order for ↑/↓: the price increases; the bars are not interactive.
    static func keys(_ model: AppModel) -> [IncreaseKey] {
        SummaryBuilder.priceIncreases(library: model.library, today: model.today).map(\.key)
    }

    static func categoryBars(_ model: AppModel, _ summary: SpendingSummary) -> [SpendingBar] {
        bars(summary.byCategory, total: summary.monthly) { id in
            model.category(id).map { ($0.name, $0.colorIndex) }
        } unassigned: { String(localized: "No category") }
    }

    /// Hidden while no live subscription has a payment method: one "No payment method" bar says nothing.
    static func methodBars(_ model: AppModel, _ summary: SpendingSummary) -> [SpendingBar] {
        let result = bars(summary.byPaymentMethod, total: summary.monthly) { id in
            model.paymentMethod(id).map { ($0.label, $0.colorIndex) }
        } unassigned: { String(localized: "No payment method") }
        return result.contains { $0.id != nil } ? result : []
    }

    /// Slices whose category or method no longer exists join the unassigned one.
    private static func bars(_ slices: [Slice], total: Money, resolve: (UUID?) -> (String, Int)?,
                             unassigned: () -> String) -> [SpendingBar] {
        guard total.amount > 0 else { return [] }
        var amounts: [UUID?: Decimal] = [:], names: [UUID?: (String, Int?)] = [:], order: [UUID?] = []
        for slice in slices where slice.monthly.amount > 0 {
            let resolved = resolve(slice.id)
            let id = resolved == nil ? nil : slice.id
            if amounts[id] == nil {
                order.append(id)
                names[id] = resolved.map { ($0.0, $0.1) } ?? (unassigned(), nil)
            }
            amounts[id, default: 0] += slice.monthly.amount
        }
        let totalValue = NSDecimalNumber(decimal: total.amount).doubleValue
        return order
            .map { id in
                let amount = amounts[id] ?? 0
                return SpendingBar(id: id, name: names[id]?.0 ?? unassigned(), lineIndex: names[id]?.1,
                                   monthly: Money(amount, total.currency),
                                   share: NSDecimalNumber(decimal: amount).doubleValue / totalValue)
            }
            .sorted { $0.monthly.amount != $1.monthly.amount ? $0.monthly.amount > $1.monthly.amount : $0.name < $1.name }
    }

    /// "38%", or "<1%" for a share that is not zero but rounds to it.
    static func shareText(_ share: Double) -> String {
        if share > 0, share < 0.005 { return "<" + 0.01.formatted(.percent.precision(.fractionLength(0))) }
        return share.formatted(.percent.precision(.fractionLength(0)))
    }

    static func spokenShare(_ share: Double) -> String {
        if share > 0, share < 0.005 {
            return String(localized: "less than \(0.01.formatted(.percent.precision(.fractionLength(0))))")
        }
        return share.formatted(.percent.precision(.fractionLength(0)))
    }
}

extension PriceIncrease {
    var key: IncreaseKey { IncreaseKey(subscriptionID: subscriptionID, on: on) }

    /// The rise as a fraction of the old price; nil when the old price was zero.
    var fraction: Double? {
        guard from.amount > 0 else { return nil }
        return NSDecimalNumber(decimal: (to.amount - from.amount) / from.amount).doubleValue
    }
}

/// A section's head: tracked caps like the strip map's group heads.
private struct SpendingSectionHead: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A station in the line colour, the name, the monthly amount and its share; under them a line
/// as long as the share, drawn over the quiet rail.
private struct SpendingBarRow: View {
    let bar: SpendingBar

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    static let station: CGFloat = 13
    static let gap: CGFloat = 9

    var body: some View {
        let color = LinePalette.line(bar.lineIndex, scheme)
        let stroke = LinePalette.stroke(contrast)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: Self.gap) {
                Circle()
                    .strokeBorder(color, lineWidth: stroke)
                    .frame(width: Self.station, height: Self.station)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                Text(verbatim: bar.name)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(verbatim: Formatters.total(bar.monthly))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .fixedSize()
                    .layoutPriority(1)
                Text(verbatim: SpendingTab.shareText(bar.share))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 34, alignment: .trailing)
                    .fixedSize()
                    .layoutPriority(1)
            }
            ShareLine(share: bar.share, color: color, track: LinePalette.rail(scheme),
                      trackOpacity: contrast == .increased ? 0.45 : 0.28)
                .padding(.leading, Self.station + Self.gap)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([bar.name, Formatters.total(bar.monthly) + " " + Formatters.spokenCycle(.monthly),
                             SpendingTab.spokenShare(bar.share)].joined(separator: ", "))
    }
}

/// A 6 pt line: the share's length in the line colour over the full-width rail.
private struct ShareLine: View {
    let share: Double
    let color: Color
    let track: Color
    let trackOpacity: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            // A sliver still shows: never shorter than its own height.
            let length = share > 0 ? max(6, width * min(share, 1)) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(track.opacity(trackOpacity))
                Capsule().fill(color).frame(width: length)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// One price increase: logo tile, name and since when; the old and new price and the rise, tight to the margin.
private struct IncreaseRow: View {
    let subscription: Subscription
    let increase: PriceIncrease
    let logosDirectory: URL
    let today: LocalDate
    let lifted: Bool
    let onHover: (IncreaseKey, Bool) -> Void
    let onOpen: (UUID) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button { onOpen(subscription.id) } label: {
            HStack(spacing: 10) {
                LogoView(subscription: subscription, size: 24, logosDirectory: logosDirectory)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: subscription.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: since)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: Formatters.money(increase.from) + " → " + Formatters.money(increase.to))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    if let rise {
                        Text(verbatim: rise)
                            .font(.system(size: 11, weight: steep ? .semibold : .regular).monospacedDigit())
                            .foregroundStyle(steep ? LinePalette.accentText : Color.secondary)
                    }
                }
                .fixedSize()
                .layoutPriority(1)
            }
            .padding(.horizontal, 16)
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
            case .active: onHover(increase.key, true)
            case .ended: onHover(increase.key, false)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var since: String {
        String(localized: "since \(Formatters.date(increase.on, today: today))")
    }

    /// A rise of 10 % or more carries the accent; the words say it too.
    private var steep: Bool { (increase.fraction ?? 0) >= 0.1 }

    private var rise: String? {
        increase.fraction.map { "+" + $0.formatted(.percent.precision(.fractionLength(0))) }
    }

    private var accessibilityText: String {
        var parts = [subscription.name,
                     String(localized: "from \(Formatters.money(increase.from)) to \(Formatters.money(increase.to))")]
        if let rise { parts.append(rise) }
        parts.append(since)
        return parts.joined(separator: ", ")
    }
}
