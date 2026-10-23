import SubusCore
import SwiftUI

/// "fewer charges ■ ■ ■ ■ ■ more", each swatch over its threshold in the current mode.
struct YearLegend: View {
    let mode: YearMode

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    /// The swatch, the gap and the threshold under it.
    static let height: CGFloat = swatch + 3 + 14
    private static let swatch: CGFloat = 12

    var body: some View {
        let labels = Self.thresholds(mode)
        // Every swatch stands over the middle of a column as wide as the widest threshold.
        let column = max(Self.swatch, labels.map { YearToolbarMetrics.text($0, size: 11) }.max() ?? 0) + 4
        HStack(alignment: .top, spacing: 4) {
            Text("fewer charges")
                .frame(height: Self.swatch)
            HStack(alignment: .top, spacing: 2) {
                ForEach(Array(labels.enumerated()), id: \.offset) { level, label in
                    VStack(spacing: 3) {
                        swatch(level)
                        Text(verbatim: label)
                            .monospacedDigit()
                            .fixedSize()
                    }
                    .frame(width: column)
                }
            }
            Text("more")
                .frame(height: Self.swatch)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private func swatch(_ level: Int) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(YearRamp.tone(level: level, dark: scheme == .dark, increasedContrast: contrast == .increased)))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
            .frame(width: Self.swatch, height: Self.swatch)
            .accessibilityHidden(true)
    }

    /// One threshold per level: "0", "1", "2", "3", "4+" for weeks, "0", "1–3", "4–6", "7–9", "10+" for months,
    /// from the plan's thresholds.
    static func thresholds(_ mode: YearMode) -> [String] {
        let t = mode == .weeks ? YearPlan.weekLevels : YearPlan.monthLevels
        let ranges = zip(t, t.dropFirst()).map { $1 - $0 == 1 ? "\($0)" : "\($0)–\($1 - 1)" }
        return ["0"] + ranges + ["\(t.last!)+"]
    }
}
