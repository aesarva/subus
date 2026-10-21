import Foundation

/// Нейтральная шкала тона клеток окна «Год» (спецификация §4.2) и цвет текста на каждой ступени.
public enum YearRamp {
    public static let cardLight = SRGBColor(hex: "#FBFBF9")!
    public static let cardDark = SRGBColor(hex: "#232325")!

    private static let tones: [[String]] = [
        ["#E8E8E4", "#CFCFCA", "#A3A39D", "#5E5E5A", "#1D1D1F"],
        ["#2C2C2E", "#48484A", "#6E6E73", "#A1A1A6", "#F2F2F0"],
        ["#DADAD4", "#B3B3AD", "#808079", "#45453F", "#000000"],
        ["#3A3A3C", "#5A5A5E", "#8E8E93", "#C7C7CC", "#FFFFFF"],
    ]

    private static let texts: [[String]] = [
        ["#1D1D1F", "#1D1D1F", "#1D1D1F", "#FFFFFF", "#FFFFFF"],
        ["#F2F2F0", "#F2F2F0", "#F2F2F0", "#1C1C1E", "#1C1C1E"],
        ["#000000", "#000000", "#000000", "#FFFFFF", "#FFFFFF"],
        ["#FFFFFF", "#FFFFFF", "#000000", "#000000", "#000000"],
    ]

    private static func row(dark: Bool, increasedContrast: Bool) -> Int {
        (increasedContrast ? 2 : 0) + (dark ? 1 : 0)
    }

    public static func tone(level: Int, dark: Bool, increasedContrast: Bool) -> SRGBColor {
        SRGBColor(hex: tones[row(dark: dark, increasedContrast: increasedContrast)][min(max(level, 0), 4)])!
    }

    public static func text(level: Int, dark: Bool, increasedContrast: Bool) -> SRGBColor {
        SRGBColor(hex: texts[row(dark: dark, increasedContrast: increasedContrast)][min(max(level, 0), 4)])!
    }
}

/// Режим сетки окна «Год»; хранится в `UserDefaults` по ключу `yearMode`.
public enum YearMode: String, Sendable {
    case weeks, months
}

/// Выбор клетки (по `id` периода) и его перенос при смене режима.
public enum YearSelection {
    private static func periods(_ plan: YearPlan, _ mode: YearMode) -> [YearPeriod] {
        mode == .weeks ? plan.weeks : plan.months
    }

    /// Клетка, содержащая `today`; если плана нет вокруг сегодня, первая клетка.
    public static func current(in plan: YearPlan, mode: YearMode, today: LocalDate) -> LocalDate {
        let all = periods(plan, mode)
        return (all.first { $0.start <= today && today <= $0.end } ?? all.first)?.id ?? today
    }

    /// `id` клетки нового режима, ближайшей к выбранной в прежнем; без выбора или без соответствия — текущая.
    public static func carry(_ selected: LocalDate?, from: YearMode, to: YearMode, plan: YearPlan,
                             today: LocalDate) -> LocalDate {
        let fallback = current(in: plan, mode: to, today: today)
        guard let selected else { return fallback }
        switch (from, to) {
        case (.weeks, .weeks), (.months, .months):
            return periods(plan, to).contains { $0.id == selected } ? selected : fallback
        case (.weeks, .months):
            // Неделя рисуется в колонке своего `monthKey`, поэтому переносим в тот же месяц.
            let key = plan.weeks.first { $0.id == selected }?.monthKey ?? MonthKey(selected)
            return plan.months.first { $0.monthKey == key }?.id ?? fallback
        case (.months, .weeks):
            guard let month = plan.months.first(where: { $0.id == selected }) else { return fallback }
            if month.start <= today && today <= month.end { return current(in: plan, mode: .weeks, today: today) }
            return plan.weeks.first { $0.monthKey == month.monthKey }?.id ?? fallback
        }
    }
}

/// Что показывает окно «Год»; порядок проверок совпадает с порядком вариантов.
public enum YearScreenState: Equatable {
    case unreadable, noSubscriptions, nothingMatches, noChargesThisYear, grid

    public static func resolve(plan: YearPlan, library: Library, isUnreadable: Bool) -> YearScreenState {
        if isUnreadable { return .unreadable }
        if library.subscriptions.isEmpty { return .noSubscriptions }
        if plan.matchedSubscriptionIDs.isEmpty { return .nothingMatches }
        if plan.charges.isEmpty { return .noChargesThisYear }
        return .grid
    }
}
