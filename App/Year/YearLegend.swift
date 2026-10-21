import SubusCore
import SwiftUI

/// "fewer charges ■■■■■ more", and the thresholds of the mode on the right.
struct YearLegend: View {
    let mode: YearMode

    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 4) {
            Text("fewer charges")
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(YearRamp.tone(level: level, dark: scheme == .dark,
                                                  increasedContrast: contrast == .increased)))
                        .overlay {
                            if contrast == .increased {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                            }
                        }
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
            Text("more")
            Spacer(minLength: 12)
            Text(verbatim: Self.thresholds(mode))
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    /// "0 · 1 · 2 · 3 · 4+" for weeks, "1–3 · 4–6 · 7–9 · 10+" for months, from the plan's thresholds.
    static func thresholds(_ mode: YearMode) -> String {
        switch mode {
        case .weeks:
            let t = YearPlan.weekLevels
            return (["0"] + t.dropLast().map(String.init) + ["\(t.last!)+"]).joined(separator: " · ")
        case .months:
            let t = YearPlan.monthLevels
            let ranges = zip(t, t.dropFirst()).map { "\($0)–\($1 - 1)" }
            return (ranges + ["\(t.last!)+"]).joined(separator: " · ")
        }
    }
}
