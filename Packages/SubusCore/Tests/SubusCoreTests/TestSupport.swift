import Foundation
import Testing
@testable import SubusCore

func d(_ iso: String) -> LocalDate { LocalDate(iso: iso)! }
func rub(_ v: Decimal) -> Money { Money(v, "RUB") }
func usd(_ v: Decimal) -> Money { Money(v, "USD") }
func eur(_ v: Decimal) -> Money { Money(v, "EUR") }

let msk = Calendar.subus(timeZone: TimeZone(identifier: "Europe/Moscow")!, locale: Locale(identifier: "en_US"))
let ny = Calendar.subus(timeZone: TimeZone(identifier: "America/New_York")!, locale: Locale(identifier: "en_US"))

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

struct FakeHTTP: HTTPClient {
    private let handler: @Sendable (URL) throws -> (data: Data, finalURL: URL)

    init(returning data: Data) { handler = { (data, $0) } }

    init(responses: [URL: Data], finalURLs: [URL: URL] = [:]) {
        handler = { url in
            guard let data = responses[url] else { throw HTTPError.status(404) }
            return (data, finalURLs[url] ?? url)
        }
    }

    init(throwing error: any Error) { handler = { _ in throw error } }

    func get(_ url: URL, timeout: TimeInterval, maxBytes: Int) async throws -> (data: Data, finalURL: URL) {
        try handler(url)
    }
}

/// Перехватывает запросы сессии; ответы задаются статической таблицей (тесты — `.serialized`).
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    enum Step {
        case respond(status: Int, chunks: [Data])
        case redirect(status: Int, to: URL)
    }

    private static let table = NSLock()
    nonisolated(unsafe) private static var handlers: [URL: Step] = [:]

    static func set(_ handlers: [URL: Step]) {
        table.lock(); defer { table.unlock() }
        self.handlers = handlers
    }

    private static func step(for url: URL) -> Step? {
        table.lock(); defer { table.unlock() }
        return handlers[url]
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let step = Self.step(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        switch step {
        case let .redirect(status, target):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
                                           headerFields: ["Location": target.absoluteString])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
        case let .respond(status, chunks):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks { client?.urlProtocol(self, didLoad: chunk) }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
