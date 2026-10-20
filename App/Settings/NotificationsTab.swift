import AppKit
import SubusCore
import SwiftUI

struct NotificationsTab: View {
    let model: AppModel
    let notifier: UserNotifier
    @State private var time = Date()
    @State private var commit: Task<Void, Never>?

    var body: some View {
        Form {
            Section("Remind me") {
                FlowLayout(spacing: 6) {
                    ForEach(model.settings.reminderDays, id: \.self) { chip($0) }
                    addMenu
                }
                .padding(.vertical, 2)
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            }

            Section {
                HStack {
                    Label(model.notificationsAuthorized ? "Notifications are allowed" : "Notifications are off for Subus",
                          systemImage: model.notificationsAuthorized ? "checkmark.circle" : "exclamationmark.triangle")
                    Spacer()
                    if !model.notificationsAuthorized {
                        Button("Open System Settings") { Self.openNotificationSettings() }
                    }
                }
                HStack {
                    Spacer()
                    Button("Send Test Notification") {
                        notifier.sendTest()
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            await model.refreshAuthorization()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear { time = timeDate() }
        .onChange(of: time) { _, _ in scheduleCommit() }
        .onDisappear(perform: commitTime)
        .task { await model.refreshAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.refreshAuthorization() }
        }
    }

    private func chip(_ days: Int) -> some View {
        HStack(spacing: 4) {
            Text(Self.label(days)).monospacedDigit()
            Button {
                model.update { $0.reminderDays.removeAll { $0 == days } }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Remove \(Self.label(days))"))
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(.quaternary))
    }

    private var addMenu: some View {
        let available = (0...30).filter { !model.settings.reminderDays.contains($0) }
        return Menu {
            ForEach(available, id: \.self) { days in
                Button(Self.label(days)) {
                    model.update { $0.reminderDays = AppSettings.normalizedDays($0.reminderDays + [days]) }
                }
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(available.isEmpty)
    }

    static func label(_ days: Int) -> String {
        days == 0 ? String(localized: "On the day") : String(localized: "\(days) days before")
    }

    private func timeDate() -> Date {
        Calendar.subus().date(from: DateComponents(hour: model.settings.reminderHour, minute: model.settings.reminderMinute)) ?? Date()
    }

    /// Typing digits in the picker changes the time many times; one replan follows the last change.
    private func scheduleCommit() {
        commit?.cancel()
        commit = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { commitTime() }
        }
    }

    private func commitTime() {
        commit?.cancel()
        let parts = Calendar.subus().dateComponents([.hour, .minute], from: time)
        model.update {
            $0.reminderHour = parts.hour ?? $0.reminderHour
            $0.reminderMinute = parts.minute ?? $0.reminderMinute
        }
    }

    private static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Lays children out left to right and wraps to the next line when the row is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
    }
}
