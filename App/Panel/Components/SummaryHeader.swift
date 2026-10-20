import SubusCore
import SwiftUI

/// Month total with its notes on the left; the days-to-next figure, the panel's only large number, on the right.
struct SummaryHeader: View {
    let summary: SpendingSummary
    /// Live subscriptions; when every one is excluded the total reads "—", never an unexplained 0.
    let liveCount: Int
    let daysToNext: Int?

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: monthText)
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(notes, id: \.self) { note in
                        Text(verbatim: note).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            if let days = daysToNext {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(verbatim: "\(days)")
                        .font(.system(size: 44, weight: .semibold).monospacedDigit())
                        .tracking(-1)
                        .foregroundStyle(days <= 1 ? LinePalette.accentText : Color.primary)
                        .padding(.bottom, -3)
                    Text(verbatim: Self.caption(days))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.accessibilityCaption(days))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var allExcluded: Bool { liveCount > 0 && summary.excludedCount >= liveCount }

    private var monthText: String {
        allExcluded ? "—" : String(localized: "\(Formatters.total(summary.monthly)) / month")
    }

    private var notes: [String] {
        var lines: [String] = []
        if !allExcluded { lines.append(String(localized: "\(Formatters.total(summary.yearly)) / year")) }
        if let date = summary.ratesDate { lines.append(String(localized: "CBR rate on \(Formatters.dayMonth(date))")) }
        if summary.trialCount > 0 {
            lines.append(String(localized: "includes \(summary.trialCount) trials at their future price"))
        }
        if summary.excludedCount > 0 {
            lines.append(String(localized: "excluding \(summary.excludedCount) subscriptions (no rate)"))
        }
        return lines
    }

    static func caption(_ days: Int) -> String {
        guard days > 0 else { return String(localized: "charge today") }
        // The catalog needs the number in a plural form; the figure above already shows it.
        let phrase = String(localized: "\(days) days until charge")
        return phrase.replacingOccurrences(of: "\(days)", with: "").trimmingCharacters(in: .whitespaces)
    }

    static func accessibilityCaption(_ days: Int) -> String {
        String(localized: "Next charge \(Formatters.relativeDays(days))")
    }
}
