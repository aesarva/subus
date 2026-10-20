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
        savePanel(ext: "json", type: .json) { [self] url in
            do {
                var logos: [String: Data] = [:]
                var missing = 0
                for s in model.library.subscriptions {
                    switch s.logo {
                    case .image(let name), .siteIcon(let name):
                        if let directory = model.logosDirectory, Logo.isSafeFileName(name),
                           let data = try? Data(contentsOf: directory.appendingPathComponent(name)) {
                            logos[name] = data
                        } else {
                            log.error("Logo not exported: \(name, privacy: .public)")
                            missing += 1
                        }
                    case .monogram: break
                    }
                }
                try Transfer.exportJSON(model.library, logos: logos).write(to: url, options: .atomic)
                if missing > 0 {
                    fail(String(localized: "Exported. \(missing) logos couldn't be included."), nil)
                } else {
                    report(String(localized: "Exported to “\(url.lastPathComponent)”."))
                }
            } catch {
                fail(String(localized: "Couldn't export: \(error.localizedDescription)"), error)
            }
        }
    }

    func exportCSV() {
        savePanel(ext: "csv", type: .commaSeparatedText) { [self] url in
            do {
                try Data(Transfer.exportCSV(model.library).utf8).write(to: url, options: .atomic)
                report(String(localized: "Exported to “\(url.lastPathComponent)”."))
            } catch {
                fail(String(localized: "Couldn't export: \(error.localizedDescription)"), error)
            }
        }
    }

    private func savePanel(ext: String, type: UTType, completion: @escaping (URL) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = "Subus-\(Self.dateStamp()).\(ext)"
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        present(panel) { if $0 == .OK, let url = panel.url { completion(url) } }
    }

    /// Sheet on the Settings window when there is one, so the panel can't hide behind it.
    private func present(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
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
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        present(panel) { [self] response in
            if response == .OK, let url = panel.url { read(url) }
        }
    }

    private func read(_ url: URL) {
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
        var result = Transfer.apply(item.preview, to: model.library, mode: mode)
        let (written, failedNames) = writeLogos(result.logos)
        var lettered: [String] = []
        if !failedNames.isEmpty {
            for i in result.library.subscriptions.indices {
                switch result.library.subscriptions[i].logo {
                case .image(let name), .siteIcon(let name):
                    if failedNames.contains(name) {
                        result.library.subscriptions[i].logo = .monogram(colorIndex: nil)
                        lettered.append(result.library.subscriptions[i].name)
                    }
                case .monogram: break
                }
            }
        }
        if model.replaceLibrary(result.library) {
            if lettered.isEmpty {
                report(String(localized: "Imported \(item.preview.library.subscriptions.count) subscriptions."))
            } else {
                fail(String(localized: "Imported. \(lettered.count) logos couldn't be saved and were replaced with letters.")
                     + "\n" + Self.nameList(lettered), nil)
            }
        } else {
            for file in written {
                if let previous = file.previous {
                    try? previous.write(to: file.url, options: .atomic)
                } else if !file.existed {
                    try? FileManager.default.removeItem(at: file.url)
                }
            }
            fail(model.saveError ?? String(localized: "Couldn't import."), nil)
        }
    }

    private struct WrittenLogo {
        var url: URL
        var previous: Data?
        var existed: Bool
    }

    /// Returns each written file with what it replaced (so a failed import can undo it), and the names that couldn't be written.
    private func writeLogos(_ logos: [String: Data]) -> (written: [WrittenLogo], failed: Set<String>) {
        var written: [WrittenLogo] = []
        var failed = Set<String>()
        for (name, data) in logos {
            guard Logo.isSafeFileName(name), let directory = model.logosDirectory else {
                failed.insert(name)
                continue
            }
            let url = directory.appendingPathComponent(name)
            let existed = FileManager.default.fileExists(atPath: url.path)
            let previous = existed ? try? Data(contentsOf: url) : nil
            do {
                try data.write(to: url, options: .atomic)
                written.append(WrittenLogo(url: url, previous: previous, existed: existed))
            } catch {
                log.error("Logo write failed: \(error.localizedDescription, privacy: .public)")
                failed.insert(name)
            }
        }
        return (written, failed)
    }

    /// Up to three names, then "+N".
    static func nameList(_ names: [String]) -> String {
        let shown = names.prefix(3).joined(separator: ", ")
        return names.count > 3 ? "\(shown) +\(names.count - 3)" : shown
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
