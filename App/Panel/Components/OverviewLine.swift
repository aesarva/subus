import SubusCore
import SwiftUI

/// The 60-day line: today's ring at the left, a station per charge, the leg to the next one in full ink.
struct OverviewLine: View {
    let items: [UpcomingItem]
    let today: LocalDate
    let focus: Set<ChargeKey>
    let onHover: (Set<ChargeKey>, Bool) -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Days the horizon is still offset after a day change; steps 1 → ½ → 0.
    @State private var shift: CGFloat = 0
    @State private var slide: Task<Void, Never>?

    static let height: CGFloat = 60
    /// Today's ring sits this far in, so it lines up with the strip map's spine.
    static let railStart: CGFloat = 10
    private static let railEndInset: CGFloat = 8
    private static let railY: CGFloat = 25
    private static let mergeDistance: CGFloat = 14
    /// Outer radii of today's ring and of a station; the leg in between is never shorter than `minLeg`.
    private static let ringRadius: CGFloat = 7.5
    private static let stationRadius: CGFloat = 6.5
    private static let minLeg: CGFloat = 12

    struct Cluster {
        var items: [UpcomingItem]
        var x0: CGFloat
        var x1: CGFloat
        var keys: Set<ChargeKey> { Set(items.map(\.id)) }
        var midX: CGFloat { (x0 + x1) / 2 }
        var isSingle: Bool { items.count == 1 }
    }

    struct LineLayout {
        /// Charges due today: drawn as today's ring itself, not as a station.
        var today: Cluster?
        /// Stations from tomorrow on, merged where closer than 14 pt.
        var stations: [Cluster]
        var next: Cluster? { today ?? stations.first }
        var all: [Cluster] { (today.map { [$0] } ?? []) + stations }
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = Self.layout(items, width: proxy.size.width, shift: shift)
            Canvas { context, size in
                draw(in: &context, size: size, layout: layout)
            }
            .overlay(alignment: .topLeading) {
                ForEach(Array(layout.all.enumerated()), id: \.offset) { _, cluster in
                    hitTarget(cluster)
                }
            }
        }
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .onChange(of: today) { old, new in step(from: old, to: new) }
    }

    // MARK: Geometry

    static func dayWidth(_ width: CGFloat) -> CGFloat {
        (width - railStart - railEndInset) / CGFloat(Upcoming.horizonDays)
    }

    /// x = days × railWidth / 60, except that no station comes closer to today's ring than a visible leg.
    static func layout(_ items: [UpcomingItem], width: CGFloat, shift: CGFloat = 0) -> LineLayout {
        let dw = dayWidth(width)
        let nearest = railStart + ringRadius + minLeg + stationRadius
        let due = items.filter { $0.days <= 0 }
        var stations: [Cluster] = []
        for item in items.filter({ $0.days > 0 }).sorted(by: { $0.days < $1.days }) {
            let x = max(railStart + (CGFloat(item.days) + shift) * dw, nearest)
            if let last = stations.indices.last, x - stations[last].x1 < mergeDistance {
                stations[last].items.append(item)
                stations[last].x1 = x
            } else {
                stations.append(Cluster(items: [item], x0: x, x1: x))
            }
        }
        let today = due.isEmpty ? nil : Cluster(items: due, x0: railStart, x1: railStart)
        return LineLayout(today: today, stations: stations)
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, layout: LineLayout) {
        let stroke = LinePalette.stroke(contrast)
        let rail = LinePalette.rail(scheme)
        let start = Self.railStart, end = size.width - Self.railEndInset, y = Self.railY
        let ink = Color.primary
        let dw = Self.dayWidth(size.width)
        let focused = layout.all.first { !focus.isDisjoint(with: $0.keys) }

        context.drawLayer { layer in
            var line = Path()
            line.move(to: CGPoint(x: start, y: y))
            line.addLine(to: CGPoint(x: end, y: y))
            layer.stroke(line, with: .color(rail), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            drawTicks(in: &layer, dayWidth: dw, rail: rail)

            if layout.today == nil, let next = layout.stations.first {
                var leg = Path()
                leg.move(to: CGPoint(x: start, y: y))
                leg.addLine(to: CGPoint(x: next.x0, y: y))
                layer.stroke(leg, with: .color(ink), style: StrokeStyle(lineWidth: stroke + 2, lineCap: .round))
            }

            // You are here; when something is due today the ring is that station, with the accent centre.
            let todayLifted = layout.today.map { !focus.isDisjoint(with: $0.keys) } ?? false
            let r = (todayLifted ? Self.ringRadius + 2 : Self.ringRadius) - stroke / 2
            let ring = Path(ellipseIn: CGRect(x: start - r, y: y - r, width: r * 2, height: r * 2))
            layer.blendMode = .clear
            layer.fill(ring, with: .color(.black))
            layer.blendMode = .normal
            layer.stroke(ring, with: .color(ink), lineWidth: stroke)
            if layout.today != nil {
                let dot = r - stroke / 2 - 1.5
                layer.fill(Path(ellipseIn: CGRect(x: start - dot, y: y - dot, width: dot * 2, height: dot * 2)),
                           with: .color(LinePalette.accent))
            }

            let anyLifted = layout.all.contains { !focus.isDisjoint(with: $0.keys) }
            for cluster in layout.stations {
                let lifted = !focus.isDisjoint(with: cluster.keys)
                drawStation(cluster, StationState(lifted: lifted, anyLifted: anyLifted), in: &layer)
            }
        }

        // Text keeps its size and full opacity, whatever recedes; the count is secondary ink, never the reserved one.
        for cluster in layout.stations where !cluster.isSingle {
            let count = context.resolve(Text(verbatim: "\(cluster.items.count)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.secondary))
            context.draw(count, at: CGPoint(x: cluster.midX, y: y), anchor: .center)
        }
        drawMonthLabels(in: &context, dayWidth: dw, end: end)
        if let labelled = focused ?? layout.next {
            drawLabel(labelled, listAll: focused != nil, in: &context, end: end)
        }
    }

    /// A single charge is a station ring; a cluster is an interchange capsule around its count, knocked out of
    /// the rail, in its line colour when all its charges share one, otherwise in the rail colour. It keeps its
    /// size when it recedes (only its stroke thins) so the count stays legible. Full ink stays reserved for
    /// today's ring, the leg and the next station's label.
    private func drawStation(_ cluster: Cluster, _ state: StationState, in context: inout GraphicsContext) {
        let y = Self.railY
        let indices = Set(cluster.items.map(\.lineColor))
        let color = indices.count == 1 ? LinePalette.line(cluster.items[0].lineColor, scheme) : LinePalette.rail(scheme)
        if cluster.isSingle {
            context.drawStation(at: CGPoint(x: cluster.x0, y: y), color: color, state, contrast: contrast)
            return
        }
        let stroke = state.stroke(contrast)
        func capsule(height h: CGFloat, inset: CGFloat) -> Path {
            let r = h / 2 - inset
            let w = max(cluster.x1 - cluster.x0 + r * 2, h + 2 - inset * 2)
            return Path(roundedRect: CGRect(x: cluster.midX - w / 2, y: y - r, width: w, height: r * 2), cornerRadius: r)
        }
        let h: CGFloat = state == .lifted ? 21 : 18
        context.blendMode = .clear
        context.fill(capsule(height: h + (state == .lifted ? 4 : 0), inset: 0), with: .color(.black))
        context.blendMode = .normal
        context.stroke(capsule(height: h, inset: stroke / 2), with: .color(color), lineWidth: stroke)
        if state == .lifted {
            context.stroke(capsule(height: h + 4, inset: 0.5), with: .color(Color(nsColor: .labelColor)), lineWidth: 1)
        }
    }

    private var weekStarts: [(day: Int, isMonthStart: Bool)] {
        let calendar = Calendar.subus()
        return (1...Upcoming.horizonDays).compactMap { d in
            let date = today.adding(days: d)
            let weekday = calendar.component(.weekday, from: date.date(hour: 12, minute: 0, calendar: calendar))
            return date.day == 1 || weekday == calendar.firstWeekday ? (d, date.day == 1) : nil
        }
    }

    private func drawTicks(in context: inout GraphicsContext, dayWidth dw: CGFloat, rail: Color) {
        let top = Self.railY + 8
        for tick in weekStarts {
            let x = Self.railStart + (CGFloat(tick.day) + shift) * dw
            var path = Path()
            path.move(to: CGPoint(x: x, y: top))
            path.addLine(to: CGPoint(x: x, y: top + (tick.isMonthStart ? 8 : 4)))
            context.stroke(path, with: .color(rail), lineWidth: tick.isMonthStart ? 1.5 : 1)
        }
    }

    /// Month names start at their tick; one that would run past the rail end ends at its tick, or is left out.
    private func drawMonthLabels(in context: inout GraphicsContext, dayWidth dw: CGFloat, end: CGFloat) {
        let top = Self.railY + 18
        func resolve(_ date: LocalDate) -> GraphicsContext.ResolvedText {
            context.resolve(Text(verbatim: Formatters.monthAbbreviation(date))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.secondary))
        }
        func width(_ t: GraphicsContext.ResolvedText) -> CGFloat {
            t.measure(in: CGSize(width: CGFloat.infinity, height: 20)).width
        }
        var placed: [(x0: CGFloat, x1: CGFloat, text: GraphicsContext.ResolvedText)] = []
        for tick in weekStarts where tick.isMonthStart {
            let text = resolve(today.adding(days: tick.day))
            let x = Self.railStart + (CGFloat(tick.day) + shift) * dw - 0.75
            let w = width(text)
            let x0 = x + w <= end ? x : x - w + 1.5
            if let last = placed.last, x0 < last.x1 + 8 { continue }
            placed.append((x0, x0 + w, text))
        }
        let current = resolve(today)
        let left = Self.railStart - Self.ringRadius
        if placed.first.map({ $0.x0 > left + width(current) + 8 }) ?? true {
            placed.insert((left, left + width(current), current), at: 0)
        }
        for label in placed {
            context.draw(label.text, at: CGPoint(x: label.x0, y: top), anchor: .topLeading)
        }
    }

    /// The next station's label at rest; under hover or the arrow keys, the focused station with all its charges.
    private func drawLabel(_ cluster: Cluster, listAll: Bool, in context: inout GraphicsContext, end: CGFloat) {
        let first = cluster.items[0]
        var names = listAll ? cluster.items.map(\.subscription.name).joined(separator: ", ") : first.subscription.name
        let suffix = !listAll && cluster.items.count > 1 ? " +\(cluster.items.count - 1)" : ""
        let left = Self.railStart - Self.ringRadius
        func make() -> GraphicsContext.ResolvedText { labelText("\(first.charge.date.day) · \(names)\(suffix)", in: context) }
        func width(_ t: GraphicsContext.ResolvedText) -> CGFloat {
            t.measure(in: CGSize(width: CGFloat.infinity, height: 20)).width
        }
        var resolved = make()
        while width(resolved) > end - left, names.count > 1 {
            names = String(names.dropLast(2)) + "…"
            resolved = make()
        }
        let w = width(resolved)
        let x = min(max(cluster.midX - w / 2, left), end - w)
        context.draw(resolved, at: CGPoint(x: x, y: 0), anchor: .topLeading)
    }

    private func labelText(_ s: String, in context: GraphicsContext) -> GraphicsContext.ResolvedText {
        context.resolve(Text(verbatim: s).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.primary))
    }

    // MARK: Hover

    private func hitTarget(_ cluster: Cluster) -> some View {
        let keys = cluster.keys
        let w = max(22, cluster.x1 - cluster.x0 + 22)
        return Color.clear
            .frame(width: w, height: 28)
            .contentShape(Rectangle())
            .onHover { inside in onHover(keys, inside) }
            .help(cluster.items.map { item in
                "\(item.subscription.name) · \(Formatters.money(item.charge.amount)) · \(Formatters.shortDate(item.charge.date))"
            }.joined(separator: "\n"))
            .position(x: cluster.midX, y: Self.railY)
    }

    // MARK: Motion

    /// The horizon slides one day left in two 90 ms steps, without easing; instant under Reduce Motion.
    private func step(from old: LocalDate, to new: LocalDate) {
        slide?.cancel()
        let delta = CGFloat(old.days(until: new))
        guard !reduceMotion, delta == 1 else {
            shift = 0
            return
        }
        shift = delta
        slide = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            shift = delta / 2
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            shift = 0
        }
    }

    // MARK: Accessibility

    private var accessibilityText: String {
        guard let next = items.min(by: { $0.days < $1.days }) else {
            return String(localized: "Next 60 days: no charges")
        }
        return String(localized: """
            Next 60 days: \(items.count) charges; next \(Formatters.relativeDays(next.days)): \
            \(next.subscription.name), \(Formatters.money(next.charge.amount))
            """)
    }
}
