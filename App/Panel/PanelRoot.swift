import AppKit
import Observation
import SubusCore
import SwiftUI

enum PanelTab: String, CaseIterable {
    case upcoming, all, spending

    var title: String {
        switch self {
        case .upcoming: String(localized: "Upcoming")
        case .all: String(localized: "All")
        case .spending: String(localized: "Spending")
        }
    }
}

/// Panel state that outlives one opening: the tab, the selection, hover, the All tab's filters,
/// the pushed card and session-dismissed banners.
@MainActor @Observable
final class PanelState {
    var tab: PanelTab = .upcoming
    var selection: ChargeKey?
    var rowHover: ChargeKey?
    var stationHover: Set<ChargeKey> = []
    var notificationsBannerDismissed = false
    /// The screen's visible height − 80, set on every opening.
    var maxHeight: CGFloat = 640

    // All tab; a new search or filter starts the selection over.
    var search = "" {
        didSet { if search != oldValue { allSelection = nil } }
    }
    /// nil shows every category.
    var categoryFilter: UUID? {
        didSet { if categoryFilter != oldValue { allSelection = nil } }
    }
    var inactiveExpanded = false
    var allSelection: UUID?
    var allHover: UUID?
    @ObservationIgnored weak var searchField: NSSearchField?

    /// The subscription whose card is pushed over the tab.
    var card: UUID?
    var confirmingDelete = false

    /// After a key moves the selection, hover is ignored until the pointer really moves:
    /// rows scrolling under a resting pointer must not steal the lift back.
    private var pointerQuiet = false

    /// What is lifted: the most recent input wins. Keys clear hover; a moved pointer hovers again.
    var focus: Set<ChargeKey> {
        if !stationHover.isEmpty { return stationHover }
        if let rowHover { return [rowHover] }
        return selection.map { [$0] } ?? []
    }

    /// The lifted row on All.
    var allFocus: UUID? { allHover ?? allSelection }

    func hoverStation(_ keys: Set<ChargeKey>, inside: Bool) {
        guard !pointerQuiet else { return }
        if inside { if stationHover != keys { stationHover = keys } } else if stationHover == keys { stationHover = [] }
    }

    func hoverRow(_ key: ChargeKey, inside: Bool) {
        guard !pointerQuiet else { return }
        if inside { if rowHover != key { rowHover = key } } else if rowHover == key { rowHover = nil }
    }

    func hoverAllRow(_ id: UUID, inside: Bool) {
        guard !pointerQuiet else { return }
        if inside { if allHover != id { allHover = id } } else if allHover == id { allHover = nil }
    }

    /// Called for real mouse movement (not for content scrolling under the pointer).
    func pointerMoved() {
        pointerQuiet = false
    }

    func moveSelection(by step: Int, in keys: [ChargeKey]) {
        guard !keys.isEmpty else { return }
        let current = selection.flatMap { keys.firstIndex(of: $0) }
        let next = current.map { min(max($0 + step, 0), keys.count - 1) } ?? (step > 0 ? 0 : keys.count - 1)
        selection = keys[next]
        quietPointer()
    }

    func moveAllSelection(by step: Int, in ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let current = allSelection.flatMap { ids.firstIndex(of: $0) }
        let next = current.map { min(max($0 + step, 0), ids.count - 1) } ?? (step > 0 ? 0 : ids.count - 1)
        allSelection = ids[next]
        quietPointer()
    }

    /// Pushes the card; the row it came from becomes the selection, so leaving the card returns to it.
    func openCard(_ id: UUID, upcomingKeys: [ChargeKey]) {
        switch tab {
        case .upcoming:
            if selection?.subscriptionID != id {
                selection = rowHover?.subscriptionID == id ? rowHover : upcomingKeys.first { $0.subscriptionID == id }
            }
        case .all:
            allSelection = id
        case .spending:
            break
        }
        confirmingDelete = false
        card = id
        quietPointer()
    }

    /// Pops the card back to its tab; a deleted subscription leaves nothing selected.
    func closeCard(deleted: Bool = false) {
        if deleted, let id = card {
            if selection?.subscriptionID == id { selection = nil }
            if allSelection == id { allSelection = nil }
        }
        confirmingDelete = false
        card = nil
        quietPointer()
    }

    func clearPointer() {
        rowHover = nil
        stationHover = []
        allHover = nil
    }

    private func quietPointer() {
        clearPointer()
        pointerQuiet = true
    }
}

struct PanelActions {
    var onAdd: () -> Void = {}
    var onSettings: () -> Void = {}
    var onOpen: (UUID) -> Void = { _ in }
    var onEdit: (UUID) -> Void = { _ in }
    /// After the card is popped: the panel takes keyboard focus back from the card's controls.
    var onBack: () -> Void = {}
    /// The delete confirmation is up: the panel must not close when it takes focus.
    var onModal: (Bool) -> Void = { _ in }
}

/// The menu-bar panel: tabs, banners, the tab's pinned head and scrolling body, and the pinned footer;
/// or, pushed over them, a subscription's card.
struct PanelRoot: View {
    nonisolated static let width: CGFloat = 360

    let model: AppModel
    @Bindable var state: PanelState
    let actions: PanelActions

    var body: some View {
        CappedColumn(maxHeight: state.maxHeight) {
            if let subscription = cardSubscription {
                CardBackBar(onBack: { back() })
                ForEach(banners.prefix(2)) { $0 }
                SubscriptionCard(model: model, state: state, subscription: subscription, actions: actions,
                                 onDeleted: { back(deleted: true) })
            } else {
                TabSwitcher(selection: $state.tab)
                ForEach(banners.prefix(2)) { $0 }
                switch state.tab {
                case .upcoming:
                    UpcomingTab(model: model, state: state, actions: actions)
                case .all:
                    AllTab(model: model, state: state, actions: actions)
                case .spending:
                    PanelEmptyState(systemImage: "hammer", title: String(localized: "Coming soon"), message: nil,
                                    actionTitle: nil, action: nil)
                }
                PanelFooter(total: model.library.subscriptions.count, inactive: inactiveCount,
                            onAdd: actions.onAdd, onSettings: actions.onSettings)
            }
        }
        .frame(width: Self.width)
        .onChange(of: state.confirmingDelete) { _, presented in actions.onModal(presented) }
    }

    private var cardSubscription: Subscription? {
        state.card.flatMap { id in model.library.subscriptions.first { $0.id == id } }
    }

    private func back(deleted: Bool = false) {
        state.closeCard(deleted: deleted)
        actions.onBack()
    }

    private var inactiveCount: Int {
        let today = model.today
        return model.library.subscriptions.filter { !$0.isLive(today: today) }.count
    }

    /// Priority order: save error, then recovered data, then notifications off.
    private var banners: [IdentifiedBanner] {
        var result: [IdentifiedBanner] = []
        if let error = model.saveError {
            let folder = model.dataDirectory
            result.append(IdentifiedBanner(id: "save", banner: PanelBanner(
                systemImage: "exclamationmark.triangle.fill", tint: LinePalette.accent, message: error,
                actionTitle: String(localized: "Show data folder"),
                action: { if let folder { NSWorkspace.shared.activateFileViewerSelecting([folder]) } })))
        }
        if let recovery = model.recovery {
            let (message, file): (String, URL) = switch recovery {
            case .restoredFromBackup(let file):
                (String(localized: "The data file was damaged. Subus restored the latest backup and kept the damaged copy."), file)
            case .resetEmpty(let file):
                (String(localized: "The data file was damaged and no backup was usable. Subus started over and kept the damaged copy."), file)
            }
            result.append(IdentifiedBanner(id: "recovery", banner: PanelBanner(
                systemImage: "arrow.counterclockwise.circle.fill", tint: .orange, message: message,
                actionTitle: String(localized: "Show in Finder"),
                action: { NSWorkspace.shared.activateFileViewerSelecting([file]) })))
        }
        if !model.library.subscriptions.isEmpty, !model.notificationsAuthorized, !state.notificationsBannerDismissed {
            result.append(IdentifiedBanner(id: "notifications", banner: PanelBanner(
                systemImage: "bell.slash.fill", tint: .secondary,
                message: String(localized: "Notifications are off, so Subus can't remind you before a charge."),
                actionTitle: String(localized: "Open Settings"),
                action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                },
                onDismiss: { [state] in state.notificationsBannerDismissed = true })))
        }
        return result
    }
}

private struct IdentifiedBanner: View, Identifiable {
    let id: String
    let banner: PanelBanner
    var body: some View { banner }
}

/// Marks the one child that scrolls; it gets what is left under the height cap.
struct ScrollingPart: LayoutValueKey {
    static let defaultValue = false
}

/// A column whose height is its content's, capped: pinned children keep their height and
/// the scrolling child takes the rest, so the popover never grows past the screen.
struct CappedColumn: Layout {
    var maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? PanelRoot.width
        return CGSize(width: width, height: heights(width: width, subviews: subviews).reduce(0, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (subview, height) in zip(subviews, heights(width: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height
        }
    }

    private func heights(width: CGFloat, subviews: Subviews) -> [CGFloat] {
        let ideal = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
        let pinned = zip(subviews, ideal).filter { !$0.0[ScrollingPart.self] }.map(\.1).reduce(0, +)
        let room = max(0, maxHeight - pinned)
        return zip(subviews, ideal).map { $0.0[ScrollingPart.self] ? min($0.1, room) : $0.1 }
    }
}
