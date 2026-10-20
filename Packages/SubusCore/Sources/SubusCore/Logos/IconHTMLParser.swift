import Foundation

public enum IconHTMLParser {
    public static func candidates(html: String, baseURL: URL) -> [URL] {
        var found: [(priority: Int, size: Int, url: URL)] = []
        for tag in matches(#"<link\b[^>]*>"#, in: html) {
            let attrs = attributes(of: tag)
            guard let rel = attrs["rel"], let href = attrs["href"], !href.isEmpty else { continue }
            let tokens = rel.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
            let priority: Int
            if tokens.contains(where: { $0.hasPrefix("apple-touch-icon") }) {
                priority = 0
            } else if tokens.contains("icon") {
                priority = 1
            } else {
                continue
            }
            if attrs["type"]?.lowercased() == "image/svg+xml" { continue }
            guard let url = URL(string: href, relativeTo: baseURL)?.absoluteURL,
                  url.pathExtension.lowercased() != "svg" else { continue }
            found.append((priority, largestSize(attrs["sizes"]), url))
        }
        let sorted = found.enumerated().sorted {
            ($0.element.priority, -$0.element.size, $0.offset) < ($1.element.priority, -$1.element.size, $1.offset)
        }.map(\.element.url)

        var result: [URL] = []
        var seen = Set<URL>()
        for url in sorted + [fallback(for: baseURL)] where seen.insert(url).inserted { result.append(url) }
        return result
    }

    private static func fallback(for baseURL: URL) -> URL {
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.port = baseURL.port
        components.path = "/favicon.ico"
        return components.url ?? baseURL
    }

    private static func largestSize(_ sizes: String?) -> Int {
        guard let sizes else { return 0 }
        return sizes.lowercased().split(whereSeparator: \.isWhitespace).compactMap { token -> Int? in
            let parts = token.split(separator: "x")
            guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) else { return nil }
            return max(w, h)
        }.max() ?? 0
    }

    private static func attributes(of tag: String) -> [String: String] {
        let pattern = #"([^\s"'<>/=]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let ns = tag as NSString
        var result: [String: String] = [:]
        for m in regex.matches(in: tag, range: NSRange(location: 0, length: ns.length)) {
            let name = ns.substring(with: m.range(at: 1)).lowercased()
            let value = (2...4).lazy.map { m.range(at: $0) }.first { $0.location != NSNotFound }.map(ns.substring) ?? ""
            if result[name] == nil { result[name] = value }
        }
        return result
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }
}
