import Foundation
import os

public enum Recovery: Equatable, Sendable {
    case restoredFromBackup(corruptFile: URL)
    case resetEmpty(corruptFile: URL)
}

public struct LoadResult: Equatable, Sendable {
    public var library: Library
    public var recovery: Recovery?

    public init(library: Library, recovery: Recovery? = nil) {
        self.library = library
        self.recovery = recovery
    }
}

public protocol SubscriptionStore: Sendable {
    func load() throws -> LoadResult
    func save(_ library: Library) throws
}

public struct JSONFileStore: SubscriptionStore {
    public typealias Writer = @Sendable (Data, URL) throws -> Void

    public static let atomicWrite: Writer = { data, url in try data.write(to: url, options: .atomic) }

    private static let logger = Logger(subsystem: "io.github.aesarva.Subus", category: "store")

    private let directory: URL
    private let initial: @Sendable () -> Library
    private let writer: Writer
    private let now: @Sendable () -> Date

    public init(directory: URL, initial: @escaping @Sendable () -> Library, writer: @escaping Writer = JSONFileStore.atomicWrite,
                now: @escaping @Sendable () -> Date = Date.init) {
        self.directory = directory
        self.initial = initial
        self.writer = writer
        self.now = now
    }

    public var fileURL: URL { directory.appendingPathComponent("subscriptions.json") }
    var backupURL: URL { directory.appendingPathComponent("subscriptions.backup.json") }

    private struct SchemaProbe: Decodable {
        var schemaVersion: Int?
    }

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    /// nil when the data is not a readable library of a supported schema version.
    static func decodeLibrary(_ data: Data) -> Library? {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(SchemaProbe.self, from: data),
              (probe.schemaVersion ?? 1) <= Library.currentSchemaVersion,
              let library = try? decoder.decode(Library.self, from: data) else { return nil }
        return library.sanitized()
    }

    public func load() throws -> LoadResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            return LoadResult(library: initial().sanitized(), recovery: nil)
        }
        let data = try Data(contentsOf: fileURL)
        if let library = Self.decodeLibrary(data) { return LoadResult(library: library, recovery: nil) }

        let corrupt = corruptURL()
        try fm.moveItem(at: fileURL, to: corrupt)
        Self.logger.error("Data file is unreadable or newer than supported; moved to \(corrupt.lastPathComponent, privacy: .public)")

        if let backupData = try? Data(contentsOf: backupURL), let library = Self.decodeLibrary(backupData) {
            persistRecovered(backupData)
            return LoadResult(library: library, recovery: .restoredFromBackup(corruptFile: corrupt))
        }
        let fresh = initial().sanitized()
        if let encoded = try? Self.makeEncoder().encode(fresh) { persistRecovered(encoded) }
        return LoadResult(library: fresh, recovery: .resetEmpty(corruptFile: corrupt))
    }

    public func save(_ library: Library) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.makeEncoder().encode(library)
        if fm.fileExists(atPath: fileURL.path) {
            let current = try Data(contentsOf: fileURL)
            if !current.isEmpty { try Self.atomicWrite(current, backupURL) }
        }
        try writer(data, fileURL)
    }

    private func persistRecovered(_ data: Data) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try writer(data, fileURL)
        } catch {
            Self.logger.error("Could not write recovered data file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func corruptURL() -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = f.string(from: now())
        var url = directory.appendingPathComponent("subscriptions.corrupt-\(stamp).json")
        var n = 0
        while FileManager.default.fileExists(atPath: url.path) {
            n += 1
            url = directory.appendingPathComponent("subscriptions.corrupt-\(stamp)-\(n).json")
        }
        return url
    }
}
