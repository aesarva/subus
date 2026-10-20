import AppKit
import SubusCore
import SwiftUI
import UniformTypeIdentifiers

/// Logo preview with drop, "Choose…", "Reset" and the monogram colour swatches.
struct LogoField: View {
    @Bindable var state: EditorState
    @State private var targeted = false

    private static let colorNames: [LocalizedStringResource] = [
        "Red", "Green", "Blue", "Orange", "Violet", "Cyan", "Brown", "Yellow",
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            preview
                .frame(width: 56, height: 56)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(LinePalette.accent, lineWidth: 3)
                        .opacity(targeted ? 1 : 0)
                }
                .dropDestination(for: URL.self, action: { urls, _ in
                    guard let url = urls.first else { return false }
                    state.loadImage(from: url)
                    return true
                }, isTargeted: { targeted = $0 })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Logo"))
                .accessibilityHint(Text("Drop an image here, or use Choose"))
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("Choose…", action: choose)
                    if !state.isMonogram {
                        Button("Reset") { state.resetLogo() }
                            .accessibilityHint(Text("Go back to the letter logo"))
                    }
                }
                if state.isMonogram { swatches }
                if state.imageFailed {
                    Text("Couldn't read this image")
                        .font(.caption)
                        .foregroundStyle(EditorView.errorColor)
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        if let image = state.pendingImage {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            LogoView(subscription: state.previewSubscription, size: 56,
                     logosDirectory: state.model.logosDirectory ?? URL(fileURLWithPath: "/dev/null"))
        }
    }

    private var swatches: some View {
        HStack(spacing: 6) {
            ForEach(0..<LinePalette.count, id: \.self) { index in
                let selected = state.monogramIndex == index
                Button { state.selectMonogram(index) } label: {
                    Circle()
                        .fill(LinePalette.tile(index))
                        .frame(width: 18, height: 18)
                        .padding(3)
                        .overlay { Circle().strokeBorder(Color.primary, lineWidth: 2).opacity(selected ? 1 : 0) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(Self.colorNames[index]))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Letter colour"))
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { state.loadImage(from: url) }
    }
}
