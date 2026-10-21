import SubusCore
import SwiftUI

/// The Year window's toolbar, left to right: the title with the period, Weeks / Months, then the search field.
/// The category chips and the Filters menu (Task 6) go between the mode switch and the search.
struct YearToolbar: ViewModifier {
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
            }
            .searchable(text: $state.filter.query)
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
    func yearToolbar(state: YearState, period: ClosedRange<LocalDate>) -> some View {
        modifier(YearToolbar(state: state, period: period))
    }
}
