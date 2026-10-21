import AppKit
import SubusCore
import SwiftUI

/// The Year window's toolbar, left to right: the title with the period, Weeks / Months, the category chips,
/// the Filters menu, then the search field.
struct YearToolbar: ViewModifier {
    let model: AppModel
    @Bindable var state: YearState
    let period: ClosedRange<LocalDate>

    func body(content: Content) -> some View {
        content
            .navigationTitle(String(localized: "Year"))
            .navigationSubtitle(Self.periodText(period))
            .toolbar {
                ToolbarItem {
                    Picker(String(localized: "Group by"), selection: $state.mode) {
                        Text(String(localized: "Weeks")).tag(YearMode.weeks)
                        Text(String(localized: "Months")).tag(YearMode.months)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                // Nothing to filter in an empty (or unread) library.
                if !model.library.subscriptions.isEmpty {
                    ToolbarItem {
                        YearCategoryChips(model: model, state: state, room: chipRoom)
                    }
                    ToolbarItem {
                        YearFiltersMenu(model: model, state: state)
                    }
                }
            }
            .searchable(text: $state.filter.query)
    }

    /// What the window leaves for the chips once the title, the mode switch, the Filters menu and the search
    /// field have theirs.
    private var chipRoom: CGFloat {
        let m = YearToolbarMetrics.self
        let title = max(m.text(String(localized: "Year"), size: 13, weight: .bold), m.text(Self.periodText(period), size: 11))
        let modes = m.text(String(localized: "Weeks")) + m.text(String(localized: "Months")) + m.modesChrome
        let count = state.filter.activeCount
        let filters = m.text(String(localized: "Filters") + (count > 0 ? " · \(count)" : "")) + m.filtersChrome
        let search = state.filter.query.isEmpty ? m.searchCollapsed : m.searchExpanded
        let reserved = m.leading + title + m.titleGap + modes + filters + search + 3 * m.groupSpacing
        return state.windowWidth - reserved
    }

    /// "22 Oct 2026 — 21 Oct 2027": both ends carry the year, since the period always crosses one.
    static func periodText(_ period: ClosedRange<LocalDate>) -> String {
        let calendar = Calendar.subus()
        let style = Date.FormatStyle(locale: .current, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated).year()
        let start = period.lowerBound.date(hour: 12, minute: 0, calendar: calendar)
        let end = period.upperBound.date(hour: 12, minute: 0, calendar: calendar)
        return start.formatted(style) + " — " + end.formatted(style)
    }
}

extension View {
    func yearToolbar(model: AppModel, state: YearState, period: ClosedRange<LocalDate>) -> some View {
        modifier(YearToolbar(model: model, state: state, period: period))
    }
}

/// Widths of the toolbar's parts, measured from their titles in the system font: enough to tell which chips fit.
/// The constants are the chrome around the titles, measured on the macOS 26 toolbar at 1100 pt.
@MainActor
enum YearToolbarMetrics {
    /// The traffic lights and the space before the title.
    static let leading: CGFloat = 108
    static let titleGap: CGFloat = 29
    /// The segmented control's padding around its two titles.
    static let modesChrome: CGFloat = 48
    /// The Filters menu's icon, chevron and padding.
    static let filtersChrome: CGFloat = 52
    static let searchCollapsed: CGFloat = 41
    static let searchExpanded: CGFloat = 165
    static let groupSpacing: CGFloat = 9
    /// A chip group's own padding, a chip's padding, the space between chips, a "More" chevron.
    static let groupPadding: CGFloat = 12
    static let buttonPadding: CGFloat = 6
    static let chipSpacing: CGFloat = 2
    static let chevron: CGFloat = 14

    static func text(_ string: String, size: CGFloat = NSFont.systemFontSize, weight: NSFont.Weight = .regular) -> CGFloat {
        ceil((string as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight)]).width)
    }

    /// A toolbar button with its title.
    static func button(_ title: String) -> CGFloat { text(title) + 2 * buttonPadding }
}
