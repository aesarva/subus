import Foundation

public protocol RateProvider: Sendable {
    func fetchRates() async throws -> RateTable
}

public struct CBRRateProvider: RateProvider {
    public static let url = URL(string: "https://www.cbr.ru/scripts/XML_daily.asp")!

    private let http: any HTTPClient
    private let now: @Sendable () -> Date

    public init(http: any HTTPClient, now: @escaping @Sendable () -> Date = Date.init) {
        self.http = http
        self.now = now
    }

    public func fetchRates() async throws -> RateTable {
        let (data, _) = try await http.get(Self.url, timeout: 10, maxBytes: 1_048_576)
        return try CBRParser.parse(data, fetchedAt: now())
    }
}

public struct RateCache: Sendable {
    private let fileURL: URL

    public init(fileURL: URL) { self.fileURL = fileURL }

    public func load() -> RateTable? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(RateTable.self, from: data)
    }

    public func save(_ t: RateTable) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(t).write(to: fileURL, options: .atomic)
    }
}
