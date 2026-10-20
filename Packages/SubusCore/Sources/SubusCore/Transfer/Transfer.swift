import Foundation

public enum ImportMode: Sendable { case add, replace }

public struct ImportRowError: Equatable, Sendable {
    public var line: Int
    public var field: String

    public init(line: Int, field: String) {
        self.line = line
        self.field = field
    }
}

public struct ImportPreview: Equatable, Sendable {
    public var library: Library
    public var errors: [ImportRowError]
    public var logos: [String: Data]

    public init(library: Library, errors: [ImportRowError] = [], logos: [String: Data] = [:]) {
        self.library = library
        self.errors = errors
        self.logos = logos
    }
}

public struct ImportResult: Equatable, Sendable {
    public var library: Library
    public var logos: [String: Data]

    public init(library: Library, logos: [String: Data] = [:]) {
        self.library = library
        self.logos = logos
    }
}

public enum TransferError: Error, Equatable, Sendable {
    case newerSchema(Int)
    case notSubusFile
}

public enum Transfer {
    public static let csvColumns = ["name", "price", "currency", "cycle_count", "cycle_unit", "start_date", "end_date",
                                    "trial_end_date", "active", "category", "payment_method", "website", "manage_url", "notes"]
    private static let requiredColumns = ["name", "price", "currency", "cycle_count", "cycle_unit", "start_date"]

    // MARK: JSON

    private struct ExportFile: Encodable {
        var library: Library
        var logos: [String: String]

        private enum Keys: String, CodingKey { case logos }

        func encode(to encoder: Encoder) throws {
            try library.encode(to: encoder)
            var c = encoder.container(keyedBy: Keys.self)
            try c.encode(logos, forKey: .logos)
        }
    }

    private struct ImportFile: Decodable {
        var library: Library
        var logos: [String: String]

        private enum Keys: String, CodingKey { case logos }
        private struct Lossy: Decodable {
            var value: String?
            init(from decoder: Decoder) throws { value = try? decoder.singleValueContainer().decode(String.self) }
        }

        init(from decoder: Decoder) throws {
            library = try Library(from: decoder)
            let c = try decoder.container(keyedBy: Keys.self)
            let raw = (try? c.decodeIfPresent([String: Lossy].self, forKey: .logos)) ?? [:]
            logos = raw.compactMapValues(\.value)
        }
    }

    public static func exportJSON(_ l: Library, logos: [String: Data]) throws -> Data {
        try JSONFileStore.makeEncoder().encode(ExportFile(library: l, logos: logos.mapValues { $0.base64EncodedString() }))
    }

    public static func parseJSON(_ data: Data) throws -> ImportPreview {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else { throw TransferError.notSubusFile }
        if let version = dict["schemaVersion"] as? Int, version > Library.currentSchemaVersion {
            throw TransferError.newerSchema(version)
        }
        guard let subscriptions = dict["subscriptions"], !(subscriptions is NSNull) else { throw TransferError.notSubusFile }
        let file = try JSONDecoder().decode(ImportFile.self, from: data)
        var logos: [String: Data] = [:]
        for (name, encoded) in file.logos where Logo.isSafeFileName(name) {
            if let bytes = Data(base64Encoded: encoded) { logos[name] = bytes }
        }
        return ImportPreview(library: file.library.sanitized(), errors: [], logos: logos)
    }

    // MARK: CSV export

    public static func exportCSV(_ l: Library) -> String {
        let categories = Dictionary(l.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let methods = Dictionary(l.paymentMethods.map { ($0.id, $0.label) }, uniquingKeysWith: { a, _ in a })
        var lines = [CSV.row(csvColumns)]
        for s in l.subscriptions {
            lines.append(CSV.row([
                s.name,
                "\(s.price.amount)",
                s.price.currency,
                String(s.cycle.count),
                s.cycle.unit.rawValue,
                s.startDate.iso,
                s.endDate?.iso ?? "",
                s.trialEndDate?.iso ?? "",
                s.isActive ? "true" : "false",
                s.categoryID.flatMap { categories[$0] } ?? "",
                s.paymentMethodID.flatMap { methods[$0] } ?? "",
                s.websiteURL?.absoluteString ?? "",
                s.manageURL?.absoluteString ?? "",
                s.notes,
            ]))
        }
        return "\u{FEFF}" + lines.map { $0 + "\r\n" }.joined()
    }

    // MARK: CSV import

    public static func parseCSV(_ text: String, now: Date) -> ImportPreview {
        var text = Substring(text)
        if text.unicodeScalars.first == "\u{FEFF}" { text = text.dropFirst() }
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r\n" && $0 != "\r" }
        let separator: Character = firstLine.contains(";") ? ";" : ","
        let records = CSV.parse(String(text), separator: separator)
        guard let header = records.first else { return ImportPreview(library: Library()) }

        var index: [String: Int] = [:]
        for (i, name) in header.fields.enumerated() {
            let key = name.trimmingCharacters(in: .whitespaces).lowercased()
            if index[key] == nil { index[key] = i }
        }
        let missing = requiredColumns.filter { index[$0] == nil }

        var library = Library()
        var errors: [ImportRowError] = []

        func field(_ record: CSV.Record, _ name: String) -> String {
            guard let i = index[name], i < record.fields.count else { return "" }
            return record.fields[i].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for record in records.dropFirst() {
            if record.fields.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            if record.unterminated {
                errors.append(ImportRowError(line: record.line, field: "csv"))
                continue
            }
            if !missing.isEmpty {
                errors += missing.map { ImportRowError(line: record.line, field: $0) }
                continue
            }
            var bad: [String] = []

            let name = field(record, "name")
            if name.isEmpty { bad.append("name") }
            let price = parsePrice(field(record, "price"))
            if price == nil { bad.append("price") }
            let currency = field(record, "currency")
            if currency.isEmpty { bad.append("currency") }
            let count = Int(field(record, "cycle_count")).flatMap { (1...BillingCycle.maxCount).contains($0) ? $0 : nil }
            if count == nil { bad.append("cycle_count") }
            let unit = BillingCycle.Unit(rawValue: field(record, "cycle_unit").lowercased())
            if unit == nil { bad.append("cycle_unit") }
            let start = LocalDate(iso: field(record, "start_date"))
            if start == nil { bad.append("start_date") }

            func optionalDate(_ column: String) -> LocalDate? {
                let raw = field(record, column)
                if raw.isEmpty { return nil }
                guard let date = LocalDate(iso: raw) else { bad.append(column); return nil }
                return date
            }
            let end = optionalDate("end_date"), trial = optionalDate("trial_end_date")

            var active = true
            let activeRaw = field(record, "active").lowercased()
            if !activeRaw.isEmpty {
                switch activeRaw {
                case "true", "1", "yes": active = true
                case "false", "0", "no": active = false
                default: bad.append("active")
                }
            }

            func optionalURL(_ column: String) -> URL? {
                let raw = field(record, column)
                if raw.isEmpty { return nil }
                guard let url = URL(string: raw), ["http", "https"].contains(url.scheme?.lowercased()), url.host != nil else {
                    bad.append(column); return nil
                }
                return url
            }
            let website = optionalURL("website"), manage = optionalURL("manage_url")

            if bad.isEmpty, let start {
                if let trial, trial < start { bad.append("trial_end_date") }
                if let end, end < (trial ?? start) { bad.append("end_date") }
            }

            guard bad.isEmpty, let price, let count, let unit, let start else {
                errors += bad.map { ImportRowError(line: record.line, field: $0) }
                continue
            }

            var s = Subscription(name: name, price: Money(price, currency), cycle: BillingCycle(count, unit), startDate: start,
                                 trialEndDate: trial, endDate: end, createdAt: now)
            s.isActive = active
            s.websiteURL = website
            s.manageURL = manage
            s.notes = index["notes"].flatMap { $0 < record.fields.count ? record.fields[$0] : nil } ?? ""
            let categoryName = field(record, "category")
            if !categoryName.isEmpty {
                if let c = library.categories.first(where: { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }) {
                    s.categoryID = c.id
                } else {
                    let c = Category(name: categoryName, colorIndex: library.categories.count % Category.paletteCount)
                    library.categories.append(c)
                    s.categoryID = c.id
                }
            }
            let methodName = field(record, "payment_method")
            if !methodName.isEmpty {
                if let m = library.paymentMethods.first(where: { $0.label.caseInsensitiveCompare(methodName) == .orderedSame }) {
                    s.paymentMethodID = m.id
                } else {
                    let m = PaymentMethod(label: methodName, colorIndex: library.paymentMethods.count % Category.paletteCount)
                    library.paymentMethods.append(m)
                    s.paymentMethodID = m.id
                }
            }
            library.subscriptions.append(s)
        }
        return ImportPreview(library: library.sanitized(), errors: errors, logos: [:])
    }

    private static func parsePrice(_ raw: String) -> Decimal? {
        var s = raw
        if !s.contains(".") { s = s.replacingOccurrences(of: ",", with: ".") }
        guard s.wholeMatch(of: /[0-9]+(\.[0-9]+)?|\.[0-9]+/) != nil,
              let value = Decimal(string: s, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
        return value
    }

    // MARK: Apply

    public static func apply(_ preview: ImportPreview, to l: Library, mode: ImportMode) -> ImportResult {
        if mode == .replace {
            var library = preview.library
            var taken = Set<String>()
            var logos: [String: Data] = [:]
            for i in library.subscriptions.indices {
                guard let name = logoFileName(library.subscriptions[i].logo) else { continue }
                guard let bytes = preview.logos[name] else {
                    library.subscriptions[i].logo = .monogram(colorIndex: nil)
                    continue
                }
                if taken.insert(name).inserted {
                    logos[name] = bytes
                } else {
                    let renamed = freshLogoName(for: library.subscriptions[i].id, taken: taken)
                    if case .siteIcon = library.subscriptions[i].logo {
                        library.subscriptions[i].logo = .siteIcon(fileName: renamed)
                    } else {
                        library.subscriptions[i].logo = .image(fileName: renamed)
                    }
                    taken.insert(renamed)
                    logos[renamed] = bytes
                }
            }
            return ImportResult(library: library, logos: logos)
        }

        var result = l
        var categoryMap: [UUID: UUID] = [:]
        for c in preview.library.categories {
            if result.categories.contains(where: { $0.id == c.id }) {
                categoryMap[c.id] = c.id
            } else if let same = result.categories.first(where: { $0.name.caseInsensitiveCompare(c.name) == .orderedSame }) {
                categoryMap[c.id] = same.id
            } else {
                var added = c
                if result.categories.contains(where: { $0.id == added.id }) { added.id = UUID() }
                result.categories.append(added)
                categoryMap[c.id] = added.id
            }
        }
        var methodMap: [UUID: UUID] = [:]
        for m in preview.library.paymentMethods {
            if result.paymentMethods.contains(where: { $0.id == m.id }) {
                methodMap[m.id] = m.id
            } else if let same = result.paymentMethods.first(where: { $0.label.caseInsensitiveCompare(m.label) == .orderedSame }) {
                methodMap[m.id] = same.id
            } else {
                var added = m
                if result.paymentMethods.contains(where: { $0.id == added.id }) { added.id = UUID() }
                result.paymentMethods.append(added)
                methodMap[m.id] = added.id
            }
        }

        var takenLogoNames = Set(l.subscriptions.compactMap { Self.logoFileName($0.logo) })
        var usedIDs = Set(l.subscriptions.map(\.id))
        var logos: [String: Data] = [:]
        for var s in preview.library.subscriptions {
            s.categoryID = s.categoryID.flatMap { categoryMap[$0] }
            s.paymentMethodID = s.paymentMethodID.flatMap { methodMap[$0] }
            let idCollides = usedIDs.contains(s.id)
            if idCollides { s.id = UUID() }
            usedIDs.insert(s.id)

            if let name = logoFileName(s.logo) {
                let bytes = preview.logos[name]
                if idCollides || takenLogoNames.contains(name) {
                    if let bytes {
                        let renamed = freshLogoName(for: s.id, taken: takenLogoNames)
                        if case .siteIcon = s.logo { s.logo = .siteIcon(fileName: renamed) } else { s.logo = .image(fileName: renamed) }
                        logos[renamed] = bytes
                        takenLogoNames.insert(renamed)
                    } else {
                        s.logo = .monogram(colorIndex: nil)
                    }
                } else if let bytes {
                    logos[name] = bytes
                    takenLogoNames.insert(name)
                } else {
                    s.logo = .monogram(colorIndex: nil)
                }
            }
            result.subscriptions.append(s)
        }
        return ImportResult(library: result.sanitized(), logos: logos)
    }

    private static func freshLogoName(for id: UUID, taken: Set<String>) -> String {
        var name = "\(id).png"
        var n = 2
        while taken.contains(name) {
            name = "\(id)-\(n).png"
            n += 1
        }
        return name
    }

    private static func logoFileName(_ logo: Logo) -> String? {
        switch logo {
        case .image(let name), .siteIcon(let name): name
        case .monogram: nil
        }
    }
}
