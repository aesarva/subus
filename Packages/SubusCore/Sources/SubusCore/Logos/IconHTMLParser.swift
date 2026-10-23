import Foundation

public enum IconHTMLParser {
    public static func candidates(html: String, baseURL: URL) -> [URL] {
        var found: [(priority: Int, size: Int, url: URL)] = []
        for tag in linkTags(in: html) {
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
            if $0.element.priority != $1.element.priority { return $0.element.priority < $1.element.priority }
            if $0.element.size != $1.element.size { return $0.element.size > $1.element.size }
            return $0.offset < $1.offset
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
            let size = max(w, h)
            return (1...4096).contains(size) ? size : nil
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

    private static let maxInputBytes = 512 * 1024

    /// Один линейный проход: пропускает комментарии, обрывается на незакрытом теге.
    private static func linkTags(in html: String) -> [String] {
        let bytes = Array(html.utf8.prefix(maxInputBytes))
        let lt = UInt8(ascii: "<"), gt = UInt8(ascii: ">")
        func lower(_ b: UInt8) -> UInt8 { (65...90).contains(b) ? b + 32 : b }
        func matches(_ word: String, at i: Int) -> Bool {
            let w = Array(word.utf8)
            guard i + w.count <= bytes.count else { return false }
            return (0..<w.count).allSatisfy { lower(bytes[i + $0]) == w[$0] }
        }
        var tags: [String] = []
        var i = 0
        while i < bytes.count {
            guard bytes[i] == lt else { i += 1; continue }
            if matches("<!--", at: i) {
                var j = i + 4
                while j + 2 < bytes.count, !(bytes[j] == 45 && bytes[j + 1] == 45 && bytes[j + 2] == gt) { j += 1 }
                if j + 2 >= bytes.count { break }
                i = j + 3
            } else if matches("<link", at: i), i + 5 < bytes.count,
                      bytes[i + 5] == gt || bytes[i + 5] == 47 || bytes[i + 5] <= 32 {
                guard let end = bytes[i...].firstIndex(of: gt) else { break }
                var tag = bytes[i...end]
                if tag.count > 2, tag[tag.endIndex - 2] == 47 { tag.remove(at: tag.endIndex - 2) }
                tags.append(String(decoding: tag, as: UTF8.self))
                i = end + 1
            } else {
                i += 1
            }
        }
        return tags
    }
}
