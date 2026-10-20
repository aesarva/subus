import Foundation
import Testing
@testable import SubusCore

@Suite(.serialized) struct URLSessionHTTPClientTests {
    let start = URL(string: "https://a.test/start")!

    func client() -> URLSessionHTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSessionHTTPClient(configuration: config)
    }

    func get(_ c: URLSessionHTTPClient, maxBytes: Int = 1000) async throws -> (data: Data, finalURL: URL) {
        try await c.get(start, timeout: 5, maxBytes: maxBytes)
    }

    @Test func returnsDataAndFinalURL() async throws {
        let final = URL(string: "https://b.test/final")!
        StubURLProtocol.set([
            start: .redirect(status: 302, to: final),
            final: .respond(status: 200, chunks: [Data("hello".utf8)]),
        ])
        let r = try await get(client())
        #expect(r.data == Data("hello".utf8))
        #expect(r.finalURL == final)
    }

    @Test func nonSuccessStatus() async {
        StubURLProtocol.set([start: .respond(status: 500, chunks: [])])
        await #expect(throws: HTTPError.status(500)) { try await get(client()) }
    }

    @Test func tooLarge() async {
        let chunk = Data(count: 1024 * 1024)
        StubURLProtocol.set([start: .respond(status: 200, chunks: [chunk, chunk, chunk])])
        await #expect(throws: HTTPError.tooLarge) { try await get(client(), maxBytes: 2 * 1024 * 1024) }
    }

    @Test func insecureInitialURL() async {
        StubURLProtocol.set([:])
        await #expect(throws: HTTPError.insecureRedirect) {
            try await client().get(URL(string: "http://a.test/")!, timeout: 5, maxBytes: 10)
        }
    }

    @Test func insecureRedirect() async {
        StubURLProtocol.set([start: .redirect(status: 301, to: URL(string: "http://a.test/plain")!)])
        await #expect(throws: HTTPError.insecureRedirect) { try await get(client()) }
    }

    @Test func redirectLimit() async throws {
        func hop(_ i: Int) -> URL { URL(string: "https://a.test/\(i)")! }
        func table(hops: Int) -> [URL: StubURLProtocol.Step] {
            var t: [URL: StubURLProtocol.Step] = [start: .redirect(status: 302, to: hop(1))]
            for i in 1..<hops { t[hop(i)] = .redirect(status: 302, to: hop(i + 1)) }
            t[hop(hops)] = .respond(status: 200, chunks: [Data("ok".utf8)])
            return t
        }
        StubURLProtocol.set(table(hops: 3))
        #expect(try await get(client()).data == Data("ok".utf8))
        StubURLProtocol.set(table(hops: 4))
        await #expect(throws: HTTPError.tooManyRedirects) { try await get(client()) }
    }
}
