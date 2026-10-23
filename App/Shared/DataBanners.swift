import AppKit
import SubusCore
import SwiftUI

/// The banners about the data file, shared by the panel and the Year window: a failed save (or an unreadable
/// file), then recovered data. Each carries its one action.
enum DataBanners {
    @MainActor static func make(model: AppModel) -> [IdentifiedBanner] {
        var result: [IdentifiedBanner] = []
        if let error = model.saveError {
            let folder = model.dataDirectory
            result.append(IdentifiedBanner(id: "save", banner: PanelBanner(
                systemImage: "exclamationmark.triangle.fill", tint: Color(nsColor: .systemRed), message: error,
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
        return result
    }
}

/// A banner with a stable identity for `ForEach`.
struct IdentifiedBanner: View, Identifiable {
    let id: String
    let banner: PanelBanner
    var body: some View { banner }
}
