import Foundation

public enum CBRParserError: Error, Equatable {
    case malformed, missingDate, noRates
}

public enum CBRParser {
    public static func parse(_ data: Data, fetchedAt: Date) throws -> RateTable {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), delegate.sawRoot else { throw CBRParserError.malformed }
        guard let date = delegate.date else { throw CBRParserError.missingDate }
        guard !delegate.rates.isEmpty else { throw CBRParserError.noRates }
        var rates = delegate.rates
        rates["RUB"] = 1
        return RateTable(date: date, rubPerUnit: rates, fetchedAt: fetchedAt)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var sawRoot = false
        var date: LocalDate?
        var rates: [String: Decimal] = [:]
        private var inValute = false
        private var field: String?
        private var text = ""
        private var code = "", nominal = "", value = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String]) {
            switch name {
            case "ValCurs":
                sawRoot = true
                date = attributes["Date"].flatMap(Self.parseDate)
            case "Valute":
                inValute = true
                code = ""; nominal = ""; value = ""
            case "CharCode", "Nominal", "Value":
                if inValute { field = name; text = "" }
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if field != nil { text += string }
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            switch name {
            case field:
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                switch name {
                case "CharCode": code = trimmed.uppercased()
                case "Nominal": nominal = trimmed
                default: value = trimmed
                }
                field = nil
            case "Valute":
                inValute = false
                if let v = Self.decimal(value), let n = Self.decimal(nominal), v > 0, n > 0, !code.isEmpty {
                    rates[code] = v / n
                }
            default: break
            }
        }

        private static func decimal(_ s: String) -> Decimal? {
            Decimal(string: s.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX"))
        }

        private static func parseDate(_ s: String) -> LocalDate? {
            let p = s.split(separator: ".", omittingEmptySubsequences: false)
            guard p.count == 3, let d = Int(p[0]), let m = Int(p[1]), let y = Int(p[2]) else { return nil }
            return LocalDate(year: y, month: m, day: d)
        }
    }
}
