import Foundation
import Testing
@testable import SubusCore

@Suite struct CurrencyTests {
    let now = Date(timeIntervalSince1970: 1_790_000_000)

    func sampleTable() throws -> RateTable { try CBRParser.parse(fixture("cbr-sample.xml"), fetchedAt: now) }

    @Test func parsesSample() throws {
        let t = try sampleTable()
        #expect(t.date == d("2026-10-17"))
        #expect(t.rubPerUnit["USD"] == 81.5)
        #expect(t.rubPerUnit["EUR"] == 95.1)
        #expect(t.rubPerUnit["KZT"] == Decimal(string: "0.1632"))
        #expect(t.rubPerUnit["RUB"] == 1)
        #expect(t.fetchedAt == now)
    }

    @Test func parsesRealFile() throws {
        let t = try CBRParser.parse(fixture("cbr-real.xml"), fetchedAt: now)
        #expect(t.rubPerUnit.count >= 30)
        #expect(t.rubPerUnit["USD"] != nil && t.rubPerUnit["EUR"] != nil)
        #expect(t.rubPerUnit.values.allSatisfy { $0 > 0 })
    }

    @Test func rejectsGarbage() {
        #expect(throws: (any Error).self) { try CBRParser.parse(Data("<html>".utf8), fetchedAt: now) }
        #expect(throws: (any Error).self) { try CBRParser.parse(Data(), fetchedAt: now) }
    }

    @Test func crossRates() throws {
        let c = CurrencyConverter(table: try sampleTable())
        #expect(c.convert(usd(10), to: "RUB") == rub(815))
        #expect(c.convert(rub(951), to: "EUR") == eur(10))
        #expect(c.convert(usd(1), to: "EUR")?.amount.rounded(4) == 0.857)
        #expect(c.convert(Money(1, "XXX"), to: "RUB") == nil)
        #expect(CurrencyConverter(table: nil).convert(usd(1), to: "RUB") == nil)
        #expect(CurrencyConverter(table: nil).convert(rub(5), to: "RUB") == rub(5))
    }

    @Test func cacheRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("rates.json")
        let cache = RateCache(fileURL: file)
        #expect(cache.load() == nil)
        let t = try sampleTable()
        try cache.save(t)
        #expect(cache.load() == t)
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("\"81.5\"") && text.contains("\"0.1632\""))
        try Data("{broken".utf8).write(to: file)
        #expect(cache.load() == nil)
    }

    @Test func refreshPolicy() throws {
        func table(age hours: Double) throws -> RateTable {
            var t = try sampleTable()
            t.fetchedAt = now.addingTimeInterval(-hours * 3600)
            return t
        }
        #expect(RateRefreshPolicy.needsRefresh(cached: nil, now: now))
        #expect(!RateRefreshPolicy.needsRefresh(cached: try table(age: 23), now: now))
        #expect(RateRefreshPolicy.needsRefresh(cached: try table(age: 25), now: now))
    }

    @Test func providerUsesHTTP() async throws {
        let sample = try fixture("cbr-sample.xml")
        let t = try await CBRRateProvider(http: FakeHTTP(returning: sample), now: { now }).fetchRates()
        #expect(t == (try sampleTable()))
        await #expect(throws: HTTPError.status(503)) {
            try await CBRRateProvider(http: FakeHTTP(throwing: HTTPError.status(503))).fetchRates()
        }
    }
}
