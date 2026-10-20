import SubusCore
import SwiftUI

/// One group of the strip map: its head, its stations and the converted sum that closes it.
struct StripGroup: Identifiable {
    let group: UpcomingGroup
    let items: [UpcomingItem]
    /// nil when nothing in the group could be converted.
    let total: Money?
    let notConverted: Int
    var id: UpcomingGroup { group }
}

/// The strip map: a vertical spine at x = 26 with a station per row, rows grouped under tracked heads.
struct StripMap: View {
    let groups: [StripGroup]
    let logosDirectory: URL
    let focus: Set<ChargeKey>
    let onHover: (ChargeKey, Bool) -> Void
    let onOpen: (UUID) -> Void

    static let spineX: CGFloat = 26
    static let textLeading: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(groups) { group in
                Text(Self.title(group.group))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.7)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .padding(.leading, Self.textLeading)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
                ForEach(group.items) { item in
                    StripRow(item: item, logosDirectory: logosDirectory, lifted: focus.contains(item.id),
                             onHover: onHover, onOpen: onOpen)
                        .id(item.id)
                }
                if let sum = Self.sumText(group) {
                    Text(verbatim: sum)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 16)
                        .padding(.bottom, 2)
                }
            }
        }
        .padding(.bottom, 8)
        .backgroundPreferenceValue(StationAnchors.self) { stations in
            GeometryReader { proxy in
                StripCanvas(stations: stations.map { ($0.key, proxy[$0.bounds], $0.lineIndex) }, focus: focus)
            }
        }
    }

    static func title(_ g: UpcomingGroup) -> String {
        switch g {
        case .todayTomorrow: String(localized: "Today & tomorrow")
        case .thisWeek: String(localized: "This week")
        case .thisMonth: String(localized: "This month")
        case .later: String(localized: "Later")
        }
    }

    /// A sum only adds information when it adds up several charges or converts a foreign one.
    static func sumText(_ g: StripGroup) -> String? {
        guard g.items.count > 1 || g.notConverted > 0 || g.total?.currency != g.items.first?.charge.amount.currency
        else { return nil }
        switch (g.total, g.notConverted) {
        case (let total?, 0): return String(localized: "≈ \(Formatters.total(total))")
        case (let total?, let n): return String(localized: "≈ \(Formatters.total(total)) + \(n) not converted")
        case (nil, let n): return String(localized: "\(n) not converted")
        }
    }
}

private struct StationAnchor {
    let key: ChargeKey
    let bounds: Anchor<CGRect>
    let lineIndex: Int?
}

private struct StationAnchors: PreferenceKey {
    static let defaultValue: [StationAnchor] = []
    static func reduce(value: inout [StationAnchor], nextValue: () -> [StationAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

/// Row highlight, spine and stations, drawn behind the rows so text keeps full opacity.
private struct StripCanvas: View {
    let stations: [(key: ChargeKey, rect: CGRect, lineIndex: Int?)]
    let focus: Set<ChargeKey>

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Canvas { context, _ in
            let stroke = LinePalette.stroke(contrast)
            let x = StripMap.spineX
            let anyLifted = stations.contains { focus.contains($0.key) }

            for s in stations where focus.contains(s.key) {
                let rect = s.rect.insetBy(dx: 6, dy: 1)
                context.fill(Path(roundedRect: rect, cornerRadius: 6),
                             with: .color(Color.primary.opacity(scheme == .dark ? 0.11 : 0.07)))
            }

            context.drawLayer { layer in
                if let first = stations.first, let last = stations.last {
                    var spine = Path()
                    spine.move(to: CGPoint(x: x, y: first.rect.midY))
                    spine.addLine(to: CGPoint(x: x, y: last.rect.midY))
                    layer.opacity = anyLifted ? LinePalette.recede : 1
                    layer.stroke(spine, with: .color(LinePalette.rail(scheme)),
                                 style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                }
                for s in stations {
                    let lifted = focus.contains(s.key)
                    layer.opacity = !anyLifted || lifted ? 1 : LinePalette.recede
                    let r = (lifted ? 17 : 13) / 2 - stroke / 2
                    let ring = Path(ellipseIn: CGRect(x: x - r, y: s.rect.midY - r, width: r * 2, height: r * 2))
                    layer.blendMode = .clear
                    layer.fill(ring, with: .color(.black))
                    layer.blendMode = .normal
                    layer.stroke(ring, with: .color(LinePalette.line(s.lineIndex, scheme)), lineWidth: stroke)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// One charge: logo tile, name with an optional Trial tag, relative date line, amount tight to the margin.
private struct StripRow: View {
    let item: UpcomingItem
    let logosDirectory: URL
    let lifted: Bool
    let onHover: (ChargeKey, Bool) -> Void
    let onOpen: (UUID) -> Void

    var body: some View {
        Button { onOpen(item.subscription.id) } label: {
            HStack(spacing: 10) {
                LogoView(subscription: item.subscription, size: 24, logosDirectory: logosDirectory)
                VStack(alignment: .leading, spacing: 2) {
                    name
                    // When the payment label does not fit after the date, it takes its own line whole.
                    ViewThatFits(in: .horizontal) {
                        dateLine(withPayment: true).lineLimit(1)
                        VStack(alignment: .leading, spacing: 1) {
                            dateLine(withPayment: false).lineLimit(1)
                            if let label = item.paymentLabel { Text(verbatim: label).lineLimit(1) }
                        }
                        dateLine(withPayment: true).lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(verbatim: Formatters.money(item.charge.amount))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .fixedSize()
                    .layoutPriority(1)
            }
            .padding(.leading, StripMap.textLeading)
            .padding(.trailing, 16)
            .padding(.vertical, 5)
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(StripRowButtonStyle())
        .onContinuousHover { phase in
            switch phase {
            case .active: onHover(item.id, true)
            case .ended: onHover(item.id, false)
            }
        }
        .anchorPreference(key: StationAnchors.self, value: .bounds) {
            [StationAnchor(key: item.id, bounds: $0, lineIndex: item.lineIndex)]
        }
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var name: some View {
        let title = Text(verbatim: item.subscription.name).font(.system(size: 13, weight: .semibold))
        if item.charge.isFirstAfterTrial {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    title.lineLimit(1)
                    TrialTag()
                }
                VStack(alignment: .leading, spacing: 3) {
                    title.lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    TrialTag()
                }
            }
        } else {
            title.lineLimit(2).truncationMode(.tail).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func dateLine(withPayment: Bool) -> Text {
        let relative = Text(verbatim: Formatters.relativeDays(item.days))
        var rest = " · " + Formatters.shortDate(item.charge.date)
        if withPayment, let label = item.paymentLabel { rest += " · " + label }
        let soon = item.days <= 1
        return (soon ? relative.foregroundStyle(LinePalette.accent).fontWeight(.semibold) : relative) + Text(verbatim: rest)
    }

    private var accessibilityText: String {
        var parts = [item.subscription.name, Formatters.relativeDays(item.days), Formatters.shortDate(item.charge.date),
                     Formatters.money(item.charge.amount)]
        if let category = item.categoryName { parts.append(category) }
        if item.charge.isFirstAfterTrial { parts.append(String(localized: "trial")) }
        return parts.joined(separator: ", ")
    }
}

/// "Trial" outline tag: carried by its text, the violet line colour only underlines it.
struct TrialTag: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let color = LinePalette.line(LinePalette.violet, scheme)
        Text("Trial")
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

/// Renders the label as is: pressing never dims text.
private struct StripRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
