import Foundation

public enum LogoError: Error, Equatable, Sendable { case noIcon }

public struct SiteIconFetcher: Sendable {
    private static let timeout: TimeInterval = 5
    private static let maxBytes = 2 * 1024 * 1024

    private let http: any HTTPClient

    public init(http: HTTPClient) { self.http = http }

    public func fetch(site: URL) async throws -> Data {
        guard site.scheme?.lowercased() == "https" else { throw HTTPError.insecureRedirect }
        let page = try await http.get(site, timeout: Self.timeout, maxBytes: Self.maxBytes)
        let html = String(decoding: page.data, as: UTF8.self)
        var lastError: (any Error)?
        for url in IconHTMLParser.candidates(html: html, baseURL: page.finalURL) where url.scheme?.lowercased() == "https" {
            do {
                let image = try await http.get(url, timeout: Self.timeout, maxBytes: Self.maxBytes)
                return try ImageNormalizer.pngThumbnail(from: image.data)
            } catch {
                if error is CancellationError { throw error }
                lastError = error
            }
        }
        throw lastError ?? LogoError.noIcon
    }
}
