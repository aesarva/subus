import SwiftUI

/// A calm centred state: what is going on, and the one thing to do about it.
/// Without a symbol it carries the world's own mark: the "you are here" ring on a short bare rail.
struct PanelEmptyState: View {
    var systemImage: String? = nil
    let title: String
    let message: String?
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.secondary)
                } else {
                    YouAreHere()
                }
            }
            .padding(.bottom, 4)
            .accessibilityHidden(true)
            Text(verbatim: title)
                .font(.system(size: 13, weight: .semibold))
                .multilineTextAlignment(.center)
            if let message {
                Text(verbatim: message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 36)
    }
}

/// Today's ring from the overview line, in ink, with nothing on the rail after it.
private struct YouAreHere: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    private static let size = CGSize(width: 64, height: 20)
    private static let ringRadius: CGFloat = 7.5

    var body: some View {
        Canvas { context, size in
            let stroke = LinePalette.stroke(contrast)
            let y = size.height / 2, x = Self.ringRadius + 1
            let r = Self.ringRadius - stroke / 2
            let ring = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
            context.drawLayer { layer in
                var rail = Path()
                rail.move(to: CGPoint(x: x, y: y))
                rail.addLine(to: CGPoint(x: size.width - stroke / 2, y: y))
                layer.stroke(rail, with: .color(LinePalette.rail(scheme)),
                             style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                layer.blendMode = .clear
                layer.fill(ring, with: .color(.black))
                layer.blendMode = .normal
                layer.stroke(ring, with: .color(.primary), lineWidth: stroke)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}
