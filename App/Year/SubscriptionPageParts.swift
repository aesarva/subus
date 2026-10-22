import AppKit
import SubusCore
import SwiftUI

/// The page's head: the 56 pt logo, the name at 22 pt with its tag, the price and its monthly equivalent,
/// a scheduled change, and on the right Edit and Manage subscription.
struct SubscriptionPageHeader: View {
    let model: AppModel
    let subscription: Subscription
    let onEdit: (UUID) -> Void

    var body: some View {
        let s = subscription, today = model.today, price = s.currentPrice(today: today)
        HStack(alignment: .top, spacing: 16) {
            LogoView(subscription: s, size: 56, logosDirectory: model.logosDirectory ?? FileManager.default.temporaryDirectory)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(verbatim: s.name)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let tag { tag }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: Formatters.perCycle(price, s.cycle))
                        .font(.system(size: 15, weight: .medium).monospacedDigit())
                    if s.cycle != .monthly {
                        let monthly = CostNormalizer.monthly(price, cycle: s.cycle)
                        Text(verbatim: String(localized: "≈ \(Formatters.money(monthly)) / month"))
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                if let next = s.nextPriceChange(today: today) {
                    let amount = Formatters.money(next.price), date = Formatters.date(next.effectiveFrom, today: today)
                    Text(verbatim: String(localized: "→ \(amount) from \(date)"))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "Changes to \(amount) from \(date)"))
                }
            }
            Spacer(minLength: 16)
            HStack(spacing: 8) {
                Button(String(localized: "Edit")) { onEdit(s.id) }
                if let url = s.manageURL, URLNormalizer.isWeb(url) {
                    Button { NSWorkspace.shared.open(url) } label: {
                        HStack(spacing: 4) {
                            Text("Manage subscription")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                    }
                    .help(url.host() ?? url.absoluteString)
                }
            }
            .controlSize(.large)
            .fixedSize()
        }
    }

    /// Ended, inactive, or in its trial — the panel card's tags.
    private var tag: AnyView? {
        let s = subscription, today = model.today
        if s.isEnded(today: today) { return AnyView(OutlineTag(text: String(localized: "Ended"), color: .secondary)) }
        if !s.isActive {
            return AnyView(OutlineTag(text: String(localized: "status.inactive", defaultValue: "Inactive"), color: .secondary))
        }
        if YearFilter.isTrial(s, today: today) { return AnyView(TrialTag()) }
        return nil
    }
}

/// One charge of the year: the date and weekday with "next" or "new price", the amount and "≈ base".
/// Lit when its week is picked in the grid; a click picks that week.
struct ChargeLine: View {
    let charge: YearCharge
    let today: LocalDate
    let base: String
    let isNext: Bool
    let isNewPrice: Bool
    let isLit: Bool
    let onPick: () -> Void

    @State private var hovered = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let amount = Formatters.money(charge.charge.amount)
        let approx = charge.charge.amount.currency != base ? charge.converted.map { "≈ " + Formatters.total($0) } : nil
        let tags = (isNext ? [String(localized: "next")] : []) + (isNewPrice ? [String(localized: "new price")] : [])
        Button(action: onPick) {
            HStack(spacing: 8) {
                Text(verbatim: Formatters.shortDate(charge.charge.date, today: today))
                    .font(.system(size: 13).monospacedDigit())
                    .lineLimit(1)
                ForEach(tags, id: \.self) { OutlineTag(text: $0, color: .secondary) }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: amount)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    if let approx {
                        Text(verbatim: approx)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(minHeight: 38)
            .background {
                if isLit || hovered {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(isLit ? (scheme == .dark ? 0.14 : 0.08) : (scheme == .dark ? 0.08 : 0.04)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainRowButtonStyle())
        .onHover { hovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(([Formatters.shortDate(charge.charge.date, today: today), amount] + [approx].compactMap { $0 } + tags)
            .joined(separator: ", "))
        .accessibilityAddTraits(isLit ? [.isButton, .isSelected] : .isButton)
    }
}

/// The price history — each change as "old → new · from date · +N %", a rise of 10 % or more in the accent
/// text — and the details: category, card, cycle, dates, website and the notes in full.
struct SubscriptionPageFacts: View {
    let model: AppModel
    let subscription: Subscription

    var body: some View {
        let steps = SubscriptionYear.priceSteps(subscription)
        VStack(alignment: .leading, spacing: 24) {
            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    PageSectionHead(title: String(localized: "Price history"))
                    ForEach(Array(steps.enumerated()).reversed(), id: \.offset) { _, step in priceStep(step) }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                PageSectionHead(title: String(localized: "Details"))
                details
            }
        }
    }

    private func priceStep(_ step: PriceStep) -> some View {
        let today = model.today
        let steep = (step.percent ?? 0) >= 10
        let rise = step.percent.map { p in
            (p > 0 ? "+" : "") + (p / 100).formatted(.percent.precision(.fractionLength(0)))
        }
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: Formatters.money(step.from) + " → " + Formatters.money(step.to))
            Text(verbatim: " · " + String(localized: "from \(YearFormat.factDate(step.on, today: today))"))
                .foregroundStyle(.secondary)
            if let rise {
                Text(verbatim: " · " + rise)
                    .fontWeight(steep ? .semibold : .regular)
                    .foregroundStyle(steep ? LinePalette.accentText : Color.secondary)
            }
        }
        .font(.system(size: 13).monospacedDigit())
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        let s = subscription, today = model.today
        return Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
            if let category = model.category(s.categoryID) {
                row(String(localized: "Category")) {
                    HStack(spacing: 6) {
                        StationRing(lineColor: category.color)
                        Text(verbatim: category.name)
                    }
                }
            }
            if let method = model.paymentMethod(s.paymentMethodID) {
                row(String(localized: "Card")) { Text(verbatim: method.label) }
            }
            row(String(localized: "Billing cycle")) {
                let cycle = Formatters.cycle(s.cycle)
                Text(verbatim: cycle.prefix(1).uppercased(with: .current) + cycle.dropFirst())
            }
            // The editor's own label: with a trial the start is not a charge.
            row(s.trialEndDate == nil ? String(localized: "First charge") : String(localized: "Start date")) {
                Text(verbatim: YearFormat.factDate(s.startDate, today: today))
            }
            if let trial = s.trialEndDate {
                row(trial > today ? String(localized: "Trial ends") : String(localized: "Trial ended")) {
                    Text(verbatim: YearFormat.factDate(trial, today: today))
                }
            }
            if let end = s.endDate {
                row(end < today ? String(localized: "Ended") : String(localized: "Ends")) {
                    Text(verbatim: YearFormat.factDate(end, today: today))
                }
            }
            if let url = s.websiteURL, URLNormalizer.isWeb(url) {
                row(String(localized: "Website")) {
                    Link(url.host() ?? url.absoluteString, destination: url)
                }
            }
            if !s.notes.isEmpty {
                row(String(localized: "Notes")) {
                    Text(verbatim: s.notes)
                        .textSelection(.enabled)
                        .frame(maxWidth: 520, alignment: .leading)
                }
            }
        }
        .font(.system(size: 13).monospacedDigit())
    }

    private func row(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        GridRow {
            Text(verbatim: label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            value()
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A section's head on the page: tracked caps, as the panel card's.
struct PageSectionHead: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
