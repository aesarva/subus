import SubusCore
import SwiftUI

/// The year as a commit calendar: weeks in month columns (1–5 cells each, 12–14 columns) or months in four
/// columns of tiles. A cell's tone counts its charges; this week or month is ringed in the accent and the
/// selected cell in ink, both outside the cell. Click selects; arrows walk the grid; Return opens the
/// selected cell's first subscription. With a `highlight` it draws one subscription's year: every cell at step 0
/// and a station of the subscription's line in each week it charges.
struct YearGrid: View {
    /// One subscription's grid: its line colour, `nil` riding the rail.
    struct Highlight {
        let lineColor: CategoryColor?
    }

    let plan: YearPlan
    let mode: YearMode
    @Binding var selection: LocalDate?
    let today: LocalDate
    /// The room the cells may take: week cells grow from 36 to 56 pt with the width and the height; month tiles grow
    /// with both.
    let width: CGFloat
    var height: CGFloat = .infinity
    var highlight: Highlight? = nil
    /// Return opens the selected cell's first subscription; without it Return passes on.
    var onOpen: ((UUID) -> Void)? = nil

    @FocusState private var focused: Bool

    static let gap: CGFloat = 6
    static let tileGap: CGFloat = 10

    var body: some View {
        let columns = mode == .weeks ? plan.weekColumns() : []
        Group {
            switch mode {
            case .weeks: weeks(columns)
            case .months: months
            }
        }
        .focusable()
        // The selection ring carries the focus: no system rectangle over the month labels and the rings.
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow, .return]) { press in
            handle(press.key, columns: columns)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(mode == .weeks ? String(localized: "Year by weeks") : String(localized: "Year by months"))
    }

    // MARK: Weeks

    /// The height of a month label over its column; the gap follows it.
    static let labelHeight: CGFloat = 14

    /// A week cell for the room: a square as large as both the columns and the rows allow, 36–56 pt.
    static func cell(width: CGFloat, height: CGFloat = .infinity, columns: Int, rows: Int) -> CGSize {
        guard columns > 0 else { return CGSize(width: 36, height: 36) }
        let widthFit = (width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let heightFit = height.isFinite && rows > 0 ? (height - labelHeight - gap * CGFloat(rows)) / CGFloat(rows) : .infinity
        let side = min(56, max(36, min(widthFit, heightFit).rounded(.down)))
        return CGSize(width: side, height: side)
    }

    /// The grid's own width for its cells, so the card and the legend under it hug the grid.
    /// `weekColumns` and `weekRows` are the plan's `weekColumns()` count and its longest column, counted once by the caller.
    static func contentWidth(weekColumns columns: Int, weekRows rows: Int, mode: YearMode, width: CGFloat,
                             height: CGFloat = .infinity) -> CGFloat {
        switch mode {
        case .weeks:
            return cell(width: width, height: height, columns: columns, rows: rows).width * CGFloat(columns)
                + gap * CGFloat(max(columns - 1, 0))
        case .months:
            return tileWidth(width: width) * 4 + tileGap * 3
        }
    }

    private func weeks(_ columns: [(month: MonthKey, weeks: [YearPeriod])]) -> some View {
        let size = Self.cell(width: width, height: height, columns: columns.count,
                             rows: columns.map(\.weeks.count).max() ?? 0)
        return HStack(alignment: .top, spacing: Self.gap) {
            ForEach(columns, id: \.month) { column in
                VStack(spacing: Self.gap) {
                    Text(verbatim: YearFormat.monthLabel(column.month, today: today))
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .frame(width: size.width, height: Self.labelHeight)
                        .accessibilityHidden(true)
                    ForEach(column.weeks) { week in
                        cell(week, cornerRadius: 7) {
                            Color.clear.frame(width: size.width, height: size.height)
                        }
                    }
                }
                // Rings reach past the gap: the column holding them draws over its neighbours.
                .zIndex(column.weeks.contains { $0.id == selection || isCurrent($0) } ? 1 : 0)
            }
        }
    }

    // MARK: Months

    static func tileWidth(width: CGFloat) -> CGFloat {
        min(180, max(120, ((width - tileGap * 3) / 4).rounded(.down)))
    }

    private var months: some View {
        let tile = Self.tileWidth(width: width)
        let rows = stride(from: 0, to: plan.months.count, by: 4).map { Array(plan.months[$0..<min($0 + 4, plan.months.count)]) }
        let fit = (height - Self.tileGap * CGFloat(max(rows.count - 1, 0))) / CGFloat(max(rows.count, 1))
        // Tiles take the height the rows leave, up to nearly square.
        let tileHeight = min(144, max(96, min(tile * 0.9, fit).rounded(.down)))
        return VStack(alignment: .leading, spacing: Self.tileGap) {
            ForEach(rows, id: \.first!.id) { row in
                HStack(spacing: Self.tileGap) {
                    ForEach(row) { month in
                        cell(month, cornerRadius: 14) {
                            MonthTile(month: month, today: today)
                                .frame(width: tile, height: tileHeight, alignment: .topLeading)
                        }
                    }
                }
                .zIndex(row.contains { $0.id == selection || isCurrent($0) } ? 1 : 0)
            }
        }
    }

    // MARK: Cell

    private func isCurrent(_ p: YearPeriod) -> Bool { p.start <= today && today <= p.end }

    private func cell(_ period: YearPeriod, cornerRadius: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        let current = isCurrent(period), selected = period.id == selection
        return Button {
            selection = period.id
            focused = true
        } label: {
            content()
                .background(YearCellFill(level: highlight == nil ? period.level : 0, cornerRadius: cornerRadius))
                .overlay {
                    if let highlight, period.count > 0 { YearCellStation(lineColor: highlight.lineColor) }
                }
                .overlay(YearCellRings(current: current, selected: selected, focused: focused, cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(PlainRowButtonStyle())
        .help(YearFormat.tooltip(period, mode: mode))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(YearFormat.spoken(period, mode: mode))
        .accessibilityValue(current ? (mode == .weeks ? String(localized: "this week") : String(localized: "this month")) : "")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Keys

    private func handle(_ key: KeyEquivalent, columns: [(month: MonthKey, weeks: [YearPeriod])]) -> KeyPress.Result {
        let periods = mode == .weeks ? plan.weeks : plan.months
        // Nothing selected yet: the walk starts from this week or month.
        guard let index = periods.firstIndex(where: { $0.id == selection }) ?? periods.firstIndex(where: isCurrent)
        else { return .ignored }
        if key == .return {
            guard let onOpen, let id = periods[index].charges.first?.charge.subscriptionID else { return .ignored }
            onOpen(id)
            return .handled
        }
        let target: Int
        switch (mode, key) {
        case (.weeks, .upArrow), (.months, .leftArrow): target = index - 1
        case (.weeks, .downArrow), (.months, .rightArrow): target = index + 1
        case (.weeks, .leftArrow): target = neighbourColumn(of: index, step: -1, in: columns)
        case (.weeks, .rightArrow): target = neighbourColumn(of: index, step: 1, in: columns)
        case (.months, .upArrow): target = index - 4
        case (.months, .downArrow): target = index + 4
        default: return .ignored
        }
        guard periods.indices.contains(target) else { return .handled }
        selection = periods[target].id
        return .handled
    }

    /// The same row of the next or previous month column, or its last cell when that column is shorter.
    private func neighbourColumn(of index: Int, step: Int, in columns: [(month: MonthKey, weeks: [YearPeriod])]) -> Int {
        var start = 0
        for (c, column) in columns.enumerated() {
            if index < start + column.weeks.count {
                let row = index - start
                let other = c + step
                guard columns.indices.contains(other) else { return index }
                let otherStart = step < 0 ? start - columns[other].weeks.count : start + column.weeks.count
                return otherStart + min(row, columns[other].weeks.count - 1)
            }
            start += column.weeks.count
        }
        return index
    }
}

/// The cell's tone on the neutral ramp; under Increase Contrast the stronger ramp and a 1 pt separator edge.
private struct YearCellFill: View {
    let level: Int
    let cornerRadius: CGFloat

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color(YearRamp.tone(level: level, dark: scheme == .dark, increasedContrast: contrast == .increased)))
            .overlay {
                if contrast == .increased { shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1) }
            }
    }
}

/// A charge in one subscription's grid: its 13 pt station on the card ground, with a 1 pt halo of that ground.
private struct YearCellStation: View {
    let lineColor: CategoryColor?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(scheme == .dark ? YearRamp.cardDark : YearRamp.cardLight))
                .frame(width: StationRing.diameter + 2, height: StationRing.diameter + 2)
            StationRing(lineColor: lineColor)
        }
        .allowsHitTesting(false)
    }
}

/// Rings outside the cell, through a gap of the card ground: this week or month in the accent
/// (gap 1.5, ring 2.5), the selection in ink (gap 2, ring 2); both — the ink ring 1.5 pt behind the accent one.
/// While the grid has the keyboard focus the selection ring takes the focus colour, opaque, in place of the ink.
struct YearCellRings: View {
    let current: Bool
    let selected: Bool
    var focused = false
    let cornerRadius: CGFloat

    var body: some View {
        let selection = focused ? Color(nsColor: Self.focusColor) : Color.primary
        ZStack {
            if current {
                ring(gap: 1.5, width: 2.5, color: LinePalette.accent)
                if selected { ring(gap: 1.5 + 2.5 + 1.5, width: 1.5, color: selection) }
            } else if selected {
                ring(gap: 2, width: 2, color: selection)
            }
        }
        .allowsHitTesting(false)
    }

    /// The system's focus colour at full opacity: at its own 50 % it falls under 3:1 on the card ground;
    /// opaque it holds 4.8:1 in light and 6:1 in dark with the blue accent.
    private static let focusColor = NSColor(name: nil) { appearance in
        var color = NSColor.keyboardFocusIndicatorColor
        appearance.performAsCurrentDrawingAppearance {
            color = NSColor.keyboardFocusIndicatorColor.usingColorSpace(.sRGB) ?? color
        }
        return color.withAlphaComponent(1)
    }

    private func ring(gap: CGFloat, width: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius + gap + width, style: .continuous)
            .strokeBorder(color, lineWidth: width)
            .padding(-(gap + width))
    }
}

/// A month tile: the month (with "from 21" / "to 20" when the period cuts it), the number of charges at 26 pt,
/// the word for them, and the sum. Every text takes the ramp's text colour for the tile's step.
private struct MonthTile: View {
    let month: YearPeriod
    let today: LocalDate

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Text(verbatim: YearFormat.monthLabel(month.monthKey, today: today, everyMonth: true))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                if let cut {
                    Text(verbatim: cut).font(.system(size: 11))
                }
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            Text(verbatim: "\(month.count)")
                .font(.system(size: 26, weight: .semibold).monospacedDigit())
            Text(verbatim: YearFormat.chargesWord(month.count))
                .font(.system(size: 12))
            Text(verbatim: sum)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Color(YearRamp.text(level: month.level, dark: scheme == .dark,
                                             increasedContrast: contrast == .increased)))
    }

    /// "from 21" for the first month, "to 20" for the last.
    private var cut: String? {
        guard month.isPartial else { return nil }
        if month.start != month.id { return String(localized: "from \(String(month.start.day))") }
        return String(localized: "to \(String(month.end.day))")
    }

    /// The tile's sum leaves out what has no rate; the tooltip names how many.
    private var sum: String {
        if case .partial(let amount, _) = month.total.display { return Formatters.total(amount) }
        return YearFormat.money(month.total)
    }
}
