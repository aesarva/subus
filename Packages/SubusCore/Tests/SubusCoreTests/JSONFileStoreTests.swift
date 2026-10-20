import Foundation
import Testing
@testable import SubusCore

private func tempDir() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("subus-test-\(UUID().uuidString)")
}

private func sample(_ name: String, price: Decimal = 5) -> Library {
    var lib = Library.initial(categoryNames: ["Music"])
    lib.subscriptions = [Subscription(name: name, price: usd(price), cycle: .monthly, startDate: d("2026-01-01"))]
    return lib
}

private struct Boom: Error {}

private func decode(_ url: URL) throws -> Library {
    try JSONDecoder().decode(Library.self, from: Data(contentsOf: url))
}

private let fixedInitial = Library.initial(categoryNames: ["Fun"])
private let initial: @Sendable () -> Library = { fixedInitial }

struct JSONFileStoreTests {
    @Test func missingFileGivesInitial() throws {
        let dir = tempDir()
        let store = JSONFileStore(directory: dir, initial: initial)
        let r = try store.load()
        #expect(r.library == initial())
        #expect(r.recovery == nil)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    @Test func saveLoadRoundTrip() throws {
        let dir = tempDir()
        let store = JSONFileStore(directory: dir, initial: initial)
        let lib = sample("A", price: Decimal(string: "1199.99")!)
        try store.save(lib)
        let r = try store.load()
        #expect(r.library == lib)
        #expect(r.library.subscriptions[0].price.amount == Decimal(string: "1199.99")!)
    }

    @Test func saveKeepsBackup() throws {
        let dir = tempDir()
        let store = JSONFileStore(directory: dir, initial: initial)
        let a = sample("A"), b = sample("B")
        try store.save(a)
        try store.save(b)
        #expect(try decode(dir.appendingPathComponent("subscriptions.backup.json")) == a)
        #expect(try decode(store.fileURL) == b)
    }

    @Test func corruptRestoresBackup() throws {
        let dir = tempDir()
        let store = JSONFileStore(directory: dir, initial: initial, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let a = sample("A")
        try store.save(a)
        try store.save(sample("B"))
        try Data("{oops".utf8).write(to: store.fileURL)

        let r = try store.load()
        guard case .restoredFromBackup(let corrupt) = r.recovery else { Issue.record("no recovery"); return }
        #expect(try String(contentsOf: corrupt, encoding: .utf8) == "{oops")
        #expect(corrupt.lastPathComponent.hasPrefix("subscriptions.corrupt-"))
        #expect(r.library == a)

        let again = try JSONFileStore(directory: dir, initial: initial).load()
        #expect(again.library == a)
        #expect(again.recovery == nil)
    }

    @Test func corruptWithoutBackupResets() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = JSONFileStore(directory: dir, initial: initial)
        try Data("{oops".utf8).write(to: store.fileURL)
        let r = try store.load()
        guard case .resetEmpty(let corrupt) = r.recovery else { Issue.record("no recovery"); return }
        #expect(FileManager.default.fileExists(atPath: corrupt.path))
        #expect(r.library == initial())
        let again = try JSONFileStore(directory: dir, initial: initial).load()
        #expect(again.library == initial())
        #expect(again.recovery == nil)
    }

    @Test func corruptNamesDoNotCollide() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = JSONFileStore(directory: dir, initial: initial, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        var names = Set<String>()
        for text in ["{1", "{2"] {
            try Data(text.utf8).write(to: store.fileURL)
            guard case .resetEmpty(let url)? = try store.load().recovery else { Issue.record("no recovery"); return }
            names.insert(url.lastPathComponent)
            #expect(try String(contentsOf: url, encoding: .utf8) == text)
        }
        #expect(names.count == 2)
    }

    @Test func newerSchemaIsNotOverwritten() throws {
        let dir = tempDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = JSONFileStore(directory: dir, initial: initial)
        let text = #"{"schemaVersion": 99, "subscriptions": []}"#
        try Data(text.utf8).write(to: store.fileURL)
        let r = try store.load()
        guard case .resetEmpty(let corrupt) = r.recovery else { Issue.record("no recovery"); return }
        #expect(try String(contentsOf: corrupt, encoding: .utf8) == text)
    }

    @Test func failedWriteKeepsOldData() throws {
        let dir = tempDir()
        let a = sample("A")
        try JSONFileStore(directory: dir, initial: initial).save(a)
        let failing = JSONFileStore(directory: dir, initial: initial, writer: { _, _ in throw Boom() })
        #expect(throws: Boom.self) { try failing.save(sample("B")) }
        let store = JSONFileStore(directory: dir, initial: initial)
        #expect(try store.load().library == a)
        #expect(try decode(dir.appendingPathComponent("subscriptions.backup.json")) == a)
    }

    @Test func failedRecoveryWriteIsRetriedNextLaunch() throws {
        let dir = tempDir()
        let a = sample("A")
        let normal = JSONFileStore(directory: dir, initial: initial)
        try normal.save(a)
        try normal.save(sample("A2"))
        try Data("{oops".utf8).write(to: normal.fileURL)

        let failing = JSONFileStore(directory: dir, initial: initial, writer: { _, _ in throw Boom() })
        let r = try failing.load()
        #expect(r.library == a)
        guard case .restoredFromBackup = r.recovery else { Issue.record("wrong recovery \(String(describing: r.recovery))"); return }
        #expect(try String(contentsOf: normal.fileURL, encoding: .utf8) == "{oops")

        let next = try normal.load()
        #expect(next.library == a)
        guard case .restoredFromBackup = next.recovery else { Issue.record("wrong recovery"); return }
    }

    @Test func saveDoesNotBackUpCorruptMain() throws {
        let dir = tempDir()
        let a = sample("A")
        let normal = JSONFileStore(directory: dir, initial: initial)
        try normal.save(a)
        try normal.save(sample("A2"))
        try Data("{oops".utf8).write(to: normal.fileURL)
        let failing = JSONFileStore(directory: dir, initial: initial, writer: { _, _ in throw Boom() })
        #expect(throws: Boom.self) { try failing.save(sample("B")) }
        let r = try normal.load()
        #expect(r.library == a)
        guard case .restoredFromBackup = r.recovery else { Issue.record("wrong recovery"); return }
    }

    @Test func missingMainRestoresValidBackup() throws {
        let dir = tempDir()
        let a = sample("A")
        let store = JSONFileStore(directory: dir, initial: initial)
        try store.save(a)
        try store.save(a)
        try FileManager.default.removeItem(at: store.fileURL)
        let r = try store.load()
        #expect(r.library == a)
        #expect(r.recovery == nil)
        #expect(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    @Test func loadSanitizes() throws {
        let dir = tempDir()
        var lib = sample("A")
        lib.subscriptions.append(lib.subscriptions[0])
        let store = JSONFileStore(directory: dir, initial: initial)
        try store.save(lib)
        let ids = try store.load().library.subscriptions.map(\.id)
        #expect(Set(ids).count == 2)
    }
}
