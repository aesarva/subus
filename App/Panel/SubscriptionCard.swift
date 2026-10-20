import AppKit
import SubusCore
import SwiftUI

/// The pinned bar over a card: "‹ Back" to the tab it came from (Esc does the same).
struct CardBackBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Label(String(localized: "Back"), systemImage: "chevron.left")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 13, weight: .medium))
            .help(String(localized: "Back (Esc)"))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }
}

/// A subscription's card, pushed inside the panel: who and how much, the next charges on a short line,
/// the facts, the price history, and the actions. Its children flow into the panel's `CappedColumn`:
/// the body scrolls, the action bar is pinned.
struct SubscriptionCard: View {
    let model: AppModel
    @Bindable var state: PanelState
    let subscription: Subscription
    let actions: PanelActions
    let onDeleted: () -> Void

    /// Bumped when a toggle could not be saved, so the switch is rebuilt from the model's value.
    @State private var activeRevision = 0
    @Environment(\.colorScheme) private var scheme

    private var today: LocalDate { model.today }
    private var category: SubusCore.Category? { model.category(subscription.categoryID) }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                header
                nextCharges
                facts
                priceHistory
            }
            .padding(.bottom, 14)
        }
        .scrollIndicators(.automatic)
        .layoutValue(key: ScrollingPart.self, value: true)
        actionBar
    }

    // MARK: Header

    private var header: some View {
        let s = subscription
        return HStack(alignment: .top, spacing: 12) {
            LogoView(subscription: s, size: 40, logosDirectory: model.logosDirectory ?? FileManager.default.temporaryDirectory)
            VStack(alignment: .leading, spacing: 3) {
                name
                Text(verbatim: Formatters.perCycle(s.price, s.cycle))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
                if s.cycle != .monthly {
                    let monthly = CostNormalizer.monthly(s.price, cycle: s.cycle)
                    Text(verbatim: String(localized: "≈ \(Formatters.money(monthly)) / month"))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let url = s.manageURL {
                    Button { NSWorkspace.shared.open(url) } label: {
                        HStack(spacing: 3) {
                            Text("Manage subscription")
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .semibold))
                                .accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .medium))
                    .help(url.host() ?? url.absoluteString)
                    .padding(.top, 5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    @ViewBuilder private var name: some View {
        let title = Text(verbatim: subscription.name).font(.system(size: 17, weight: .semibold))
        if let tag {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    title.lineLimit(1)
                    tag
                }
                VStack(alignment: .leading, spacing: 4) {
                    title.lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    tag
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        } else {
            title.lineLimit(3).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Ended, paused, or in its trial: carried by text, the outline only frames it.
    private var tag: AnyView? {
        let s = subscription
        if s.isEnded(today: today) { return AnyView(OutlineTag(text: String(localized: "Ended"), color: .secondary)) }
        if !s.isActive { return AnyView(OutlineTag(text: String(localized: "Paused"), color: .secondary)) }
        if let trial = s.trialEndDate, trial >= today { return AnyView(TrialTag()) }
        return nil
    }

    // MARK: Next charges

    @ViewBuilder private var nextCharges: some View {
        let charges = Upcoming.nextCharges(for: subscription, today: today, count: 3)
        SectionHead(title: String(localized: "Next charges"))
        if charges.isEmpty {
            Text("No upcoming charges")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(charges.enumerated()), id: \.element.date) { index, charge in
                    ChargeStop(charge: charge, today: today, lineIndex: category?.colorIndex,
                               isFirst: index == 0, isLast: index == charges.count - 1)
                }
            }
        }
    }

    // MARK: Facts

    @ViewBuilder private var facts: some View {
        let rows = factRows
        if !rows.isEmpty {
            SectionHead(title: String(localized: "Details"))
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 7) {
                ForEach(rows, id: \.label) { row in
                    GridRow {
                        Text(verbatim: row.label)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        row.value
                            .font(.system(size: 13).monospacedDigit())
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
    }

    private struct Fact {
        let label: String
        let value: AnyView
    }

    private var factRows: [Fact] {
        let s = subscription
        var rows: [Fact] = []
        func text(_ label: String, _ value: String) {
            rows.append(Fact(label: label, value: AnyView(Text(verbatim: value))))
        }
        if let category {
            rows.append(Fact(label: String(localized: "Category"), value: AnyView(HStack(spacing: 6) {
                Circle()
                    .fill(LinePalette.line(category.colorIndex, scheme))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(verbatim: category.name)
            })))
        }
        if let method = model.paymentMethod(s.paymentMethodID) {
            text(String(localized: "Payment"), method.label)
        }
        text(String(localized: "Started"), Formatters.date(s.startDate, today: today))
        if let trial = s.trialEndDate {
            text(trial >= today ? String(localized: "Trial ends") : String(localized: "Trial ended"),
                 Formatters.date(trial, today: today))
        }
        if let end = s.endDate {
            text(end < today ? String(localized: "Ended") : String(localized: "Ends"), Formatters.date(end, today: today))
        }
        return rows
    }

    // MARK: Price history

    @ViewBuilder private var priceHistory: some View {
        let history = subscription.priceHistory
        if history.count > 1 {
            SectionHead(title: String(localized: "Price history"))
            VStack(alignment: .leading, spacing: 7) {
                ForEach(history.reversed(), id: \.effectiveFrom) { change in
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: Formatters.date(change.effectiveFrom, today: today))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(verbatim: Formatters.money(change.price))
                            .font(.system(size: 13).monospacedDigit())
                            .fixedSize()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
    }

    // MARK: Actions

    private var actionBar: some View {
        let id = subscription.id
        return VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                Toggle(isOn: Binding(
                    get: { subscription.isActive },
                    set: { active in
                        // A refused save leaves the model as it was: the switch follows it, the banner explains.
                        if !model.setActive(id, active) { activeRevision += 1 }
                    })) {
                    Text("Active")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .id(activeRevision)
                Spacer(minLength: 4)
                Button(String(localized: "Edit")) { actions.onEdit(id) }
                    .foregroundStyle(.primary)
                Button(String(localized: "Delete…")) { state.confirmingDelete = true }
                    .foregroundStyle(Color(nsColor: .systemRed))
            }
            .buttonStyle(.borderless)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .confirmationDialog(String(localized: "Delete “\(subscription.name)”?"), isPresented: $state.confirmingDelete,
                            titleVisibility: .visible) {
            Button(String(localized: "Delete"), role: .destructive) {
                if model.delete(id) { onDeleted() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}

/// A card section's head: tracked caps like the strip map's group heads.
private struct SectionHead: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One of the next charges: a station on a short spine in the category's line colour.
/// Today and tomorrow carry the accent, in the station's centre and in the words.
private struct ChargeStop: View {
    let charge: Charge
    let today: LocalDate
    let lineIndex: Int?
    let isFirst: Bool
    let isLast: Bool

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let days = today.days(until: charge.date)
        let soon = days <= 1
        // The trial is in the header's tag and the "Trial ends" fact; the stops stay plain.
        HStack(alignment: .center, spacing: 8) {
            dateLine(days: days, soon: soon)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(verbatim: Formatters.money(charge.amount))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(.leading, StripMap.textLeading)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
        .frame(minHeight: 34)
        .background(alignment: .leading) {
            Canvas { context, size in draw(in: &context, size: size, accent: soon) }
                .frame(width: StripMap.textLeading)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(days: days))
    }

    private func dateLine(days: Int, soon: Bool) -> Text {
        let relative = Text(verbatim: Formatters.relativeDays(days))
            .font(.system(size: 13, weight: soon ? .semibold : .regular))
        let date = Text(verbatim: " · " + Formatters.shortDate(charge.date, today: today))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        return (soon ? relative.foregroundStyle(LinePalette.accent) : relative) + date
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, accent: Bool) {
        let stroke = LinePalette.stroke(contrast)
        let color = LinePalette.line(lineIndex, scheme)
        let x = StripMap.spineX, y = size.height / 2
        context.drawLayer { layer in
            if !(isFirst && isLast) {
                var spine = Path()
                spine.move(to: CGPoint(x: x, y: isFirst ? y : 0))
                spine.addLine(to: CGPoint(x: x, y: isLast ? y : size.height))
                layer.stroke(spine, with: .color(color), lineWidth: stroke)
            }
            let r = 13 / 2 - stroke / 2
            let ring = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            layer.blendMode = .clear
            layer.fill(ring, with: .color(.black))
            layer.blendMode = .normal
            layer.stroke(ring, with: .color(color), lineWidth: stroke)
            if accent {
                let dot = r - stroke / 2 - 1
                layer.fill(Path(ellipseIn: CGRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2)),
                           with: .color(LinePalette.accent))
            }
        }
    }

    private func accessibilityText(days: Int) -> String {
        [Formatters.relativeDays(days), Formatters.shortDate(charge.date, today: today),
         Formatters.money(charge.amount)].joined(separator: ", ")
    }
}

/// An outline tag in the Trial tag's form, for states that are not a line colour: Ended, Paused.
private struct OutlineTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(color, lineWidth: 1))
            .fixedSize()
    }
}
