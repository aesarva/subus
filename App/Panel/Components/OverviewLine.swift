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

    struct Cluster {
        var items: [UpcomingItem]
        var x0: CGFloat
        var x1: CGFloat
        var keys: Set<ChargeKey> { Set(items.map(\.id)) }
        var midX: CGFloat { (x0 + x1) / 2 }
        var isSingle: Bool { items.count == 1 }
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clusters = Self.clusters(items, width: width, shift: shift)
            Canvas { context, size in
                draw(in: &context, size: size, clusters: clusters)
            }
            .overlay(alignment: .topLeading) {
                ForEach(Array(clusters.enumerated()), id: \.offset) { _, cluster in
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

    static func clusters(_ items: [UpcomingItem], width: CGFloat, shift: CGFloat = 0) -> [Cluster] {
        let dw = dayWidth(width)
        var result: [Cluster] = []
        for item in items.sorted(by: { $0.days < $1.days }) {
            let x = railStart + (CGFloat(item.days) + shift) * dw
            if let last = result.indices.last, x - result[last].x1 < mergeDistance {
                result[last].items.append(item)
                result[last].x1 = x
            } else {
                result.append(Cluster(items: [item], x0: x, x1: x))
            }
        }
        return result
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, clusters: [Cluster]) {
        let stroke = LinePalette.stroke(contrast)
        let rail = LinePalette.rail(scheme)
        let start = Self.railStart, end = size.width - Self.railEndInset, y = Self.railY
        let ink = Color.primary
        let dw = Self.dayWidth(size.width)

        context.drawLayer { layer in
            var line = Path()
            line.move(to: CGPoint(x: start, y: y))
            line.addLine(to: CGPoint(x: end, y: y))
            layer.stroke(line, with: .color(rail), style: StrokeStyle(lineWidth: stroke, lineCap: .round))

            drawCalendar(in: &layer, dayWidth: dw, rail: rail)

            if let next = clusters.first, next.x0 > start {
                var leg = Path()
                leg.move(to: CGPoint(x: start, y: y))
                leg.addLine(to: CGPoint(x: next.x0, y: y))
                layer.stroke(leg, with: .color(ink), style: StrokeStyle(lineWidth: stroke + 2, lineCap: .round))
            }

            for cluster in clusters {
                let lifted = !focus.isDisjoint(with: cluster.keys)
                layer.opacity = focus.isEmpty || lifted ? 1 : 0.35
                drawStation(cluster, lifted: lifted, in: &layer, stroke: stroke)
            }
            layer.opacity = 1

            let nextIsToday = clusters.first.map { $0.x0 <= start + 0.5 } ?? false
            let here = nextIsToday ? 11.5 : 6.0
            let ring = Path(ellipseIn: CGRect(x: start - here, y: y - here, width: here * 2, height: here * 2))
            layer.blendMode = .clear
            layer.fill(ring, with: .color(.black))
            layer.blendMode = .normal
            layer.stroke(ring, with: .color(ink), lineWidth: stroke)
            if nextIsToday, let first = clusters.first {
                drawStation(first, lifted: false, in: &layer, stroke: stroke)
            }
        }

        if let next = clusters.first {
            drawNextLabel(next, in: &context, width: size.width)
        }
    }

    private func drawStation(_ cluster: Cluster, lifted: Bool, in context: inout GraphicsContext, stroke: CGFloat) {
        let y = Self.railY
        let indices = Set(cluster.items.map(\.lineIndex))
        let color = indices.count == 1 ? LinePalette.line(cluster.items[0].lineIndex, scheme) : Color.primary
        let path: Path
        if cluster.isSingle {
            let r = (lifted ? 17 : 13) / 2 - stroke / 2
            path = Path(ellipseIn: CGRect(x: cluster.x0 - r, y: y - r, width: r * 2, height: r * 2))
        } else {
            let h: CGFloat = lifted ? 21 : 18
            let r = h / 2 - stroke / 2
            let w = max(cluster.x1 - cluster.x0 + r * 2, h + 2 - stroke)
            let rect = CGRect(x: cluster.midX - w / 2, y: y - r, width: w, height: r * 2)
            path = Path(roundedRect: rect, cornerRadius: r)
        }
        context.blendMode = .clear
        context.fill(path, with: .color(.black))
        context.blendMode = .normal
        context.stroke(path, with: .color(color), lineWidth: stroke)
        if !cluster.isSingle {
            let count = context.resolve(Text(verbatim: "\(cluster.items.count)")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.primary))
            context.draw(count, at: CGPoint(x: cluster.midX, y: y), anchor: .center)
        }
    }

    private func drawCalendar(in context: inout GraphicsContext, dayWidth dw: CGFloat, rail: Color) {
        let calendar = Calendar.subus()
        let tickTop = Self.railY + 8
        var monthStarts: [(x: CGFloat, date: LocalDate)] = []
        for d in 1...Upcoming.horizonDays {
            let date = today.adding(days: d)
            let x = Self.railStart + (CGFloat(d) + shift) * dw
            let isMonthStart = date.day == 1
            let weekday = calendar.component(.weekday, from: date.date(hour: 12, minute: 0, calendar: calendar))
            guard isMonthStart || weekday == calendar.firstWeekday else { continue }
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: tickTop))
            tick.addLine(to: CGPoint(x: x, y: tickTop + (isMonthStart ? 8 : 4)))
            context.stroke(tick, with: .color(rail), lineWidth: isMonthStart ? 1.5 : 1)
            if isMonthStart { monthStarts.append((x, date)) }
        }

        var labels = monthStarts.map { (x: $0.x - 0.75, date: $0.date, anchor: UnitPoint.topLeading) }
        let first = (x: Self.railStart - 6, date: today, anchor: UnitPoint.topLeading)
        if labels.first.map({ $0.x - first.x > 40 }) ?? true { labels.insert(first, at: 0) }
        for label in labels {
            let text = context.resolve(Text(verbatim: Formatters.monthAbbreviation(label.date))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.secondary))
            context.draw(text, at: CGPoint(x: label.x, y: tickTop + 10), anchor: label.anchor)
        }
    }

    private func drawNextLabel(_ cluster: Cluster, in context: inout GraphicsContext, width: CGFloat) {
        let first = cluster.items[0]
        let others = cluster.items.count - 1
        let suffix = others > 0 ? " +\(others)" : ""
        let maxWidth = width * 0.7
        var name = first.subscription.name
        var resolved = labelText("\(first.charge.date.day) · \(name)\(suffix)", in: context)
        while resolved.measure(in: CGSize(width: CGFloat.infinity, height: 20)).width > maxWidth, name.count > 1 {
            name = String(name.dropLast(2)) + "…"
            resolved = labelText("\(first.charge.date.day) · \(name)\(suffix)", in: context)
        }
        let w = resolved.measure(in: CGSize(width: CGFloat.infinity, height: 20)).width
        let x = min(max(cluster.x0 - w / 2, 0), width - w)
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
