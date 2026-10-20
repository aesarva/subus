import AppKit
import Observation
import OSLog
import SubusCore
import SwiftUI
import UniformTypeIdentifiers

/// A parsed file waiting for the user to choose how to apply it.
struct PendingImport: Identifiable {
    let id = UUID()
    var preview: ImportPreview
}

@MainActor @Observable
final class DataController {
    private let model: AppModel
    private let log = Logger(subsystem: "io.github.aesarva.Subus", category: "store")
    var pending: PendingImport?
    var message: String?
    var failed = false

    init(model: AppModel) { self.model = model }

    // MARK: Export

    func exportJSON() {
        guard let url = savePanel(ext: "json", type: .json) else { return }
        do {
            var logos: [String: Data] = [:]
            if let directory = model.logosDirectory {
                for s in model.library.subscriptions {
                    switch s.logo {
                    case .image(let name), .siteIcon(let name):
                        if Logo.isSafeFileName(name), let data = try? Data(contentsOf: directory.appendingPathComponent(name)) {
                            logos[name] = data
                        }
                    case .monogram: break
                    }
                }
            }
            try Transfer.exportJSON(model.library, logos: logos).write(to: url, options: .atomic)
            report(String(localized: "Exported to “\(url.lastPathComponent)”."))
        } catch {
            fail(String(localized: "Couldn't export: \(error.localizedDescription)"), error)
        }
    }

    func exportCSV() {
        guard let url = savePanel(ext: "csv", type: .commaSeparatedText) else { return }
        do {
            try Data(Transfer.exportCSV(model.library).utf8).write(to: url, options: .atomic)
            report(String(localized: "Exported to “\(url.lastPathComponent)”."))
        } catch {
            fail(String(localized: "Couldn't export: \(error.localizedDescription)"), error)
        }
    }

    private func savePanel(ext: String, type: UTType) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = "Subus-\(Self.dateStamp()).\(ext)"
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func dateStamp(_ date: Date = Date()) -> String {
        LocalDate.today(now: date, calendar: .subus()).iso
    }

    // MARK: Import

    func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let preview: ImportPreview
            if url.pathExtension.lowercased() == "csv" {
                guard let text = String(data: data, encoding: .utf8) else {
                    return fail(String(localized: "This file isn't UTF-8 text."), nil)
                }
                preview = Transfer.parseCSV(text, now: Date())
            } else {
                preview = try Transfer.parseJSON(data)
            }
            message = nil
            pending = PendingImport(preview: preview)
        } catch TransferError.newerSchema {
            fail(String(localized: "This file was made by a newer version of Subus."), nil)
        } catch TransferError.notSubusFile {
            fail(String(localized: "This isn't a Subus file."), nil)
        } catch {
            fail(String(localized: "Couldn't read the file: \(error.localizedDescription)"), error)
        }
    }

    func apply(_ item: PendingImport, mode: ImportMode) {
        pending = nil
        let result = Transfer.apply(item.preview, to: model.library, mode: mode)
        let written = writeLogos(result.logos)
        if model.replaceLibrary(result.library) {
            report(String(localized: "Imported \(item.preview.library.subscriptions.count) subscriptions."))
        } else {
            for (url, previous) in written {
                if let previous { try? previous.write(to: url, options: .atomic) } else { try? FileManager.default.removeItem(at: url) }
            }
            fail(model.saveError ?? String(localized: "Couldn't import."), nil)
        }
    }

    /// Returns each written file with the bytes it replaced (nil when it was new), so a failed import can undo them.
    private func writeLogos(_ logos: [String: Data]) -> [(URL, Data?)] {
        guard let directory = model.logosDirectory else { return [] }
        var written: [(URL, Data?)] = []
        for (name, data) in logos where Logo.isSafeFileName(name) {
            let url = directory.appendingPathComponent(name)
            let previous = try? Data(contentsOf: url)
            do {
                try data.write(to: url, options: .atomic)
                written.append((url, previous))
            } catch {
                log.error("Logo write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        return written
    }

    func showDataFolder() {
        guard let directory = model.dataDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }

    private func report(_ text: String) { message = text; failed = false }

    private func fail(_ text: String, _ error: Error?) {
        if let error { log.error("\(error.localizedDescription, privacy: .public)") }
        message = text
        failed = true
    }
}

struct DataTab: View {
    let model: AppModel
    @State private var data: DataController

    init(model: AppModel) {
        self.model = model
        _data = State(initialValue: DataController(model: model))
    }

    var body: some View {
        Form {
            Section("Export") {
                HStack {
                    Button("Export JSON…") { data.exportJSON() }
                    Button("Export CSV…") { data.exportCSV() }
                    Spacer()
                }
                Text("JSON is a full backup with logos. CSV opens in Numbers and Excel; it leaves out price history, logos and notification switches.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Import") {
                HStack {
                    Button("Import…") { data.chooseImport() }
                    Spacer()
                }
                Text("Reads a Subus JSON backup or a CSV file. You'll see what was found before anything changes.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Button("Show Data Folder") { data.showDataFolder() }.disabled(model.dataDirectory == nil)
                    Spacer()
                }
                if let message = data.message {
                    Text(message).font(.callout).foregroundStyle(data.failed ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .sheet(item: $data.pending) { item in
            ImportPreviewView(preview: item.preview,
                              onAdd: { data.apply(item, mode: .add) },
                              onReplace: { data.apply(item, mode: .replace) },
                              onCancel: { data.pending = nil })
        }
    }
}
