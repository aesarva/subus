import Foundation

/// Minimal RFC 4180 reader/writer.
enum CSV {
    struct Record: Equatable {
        var line: Int          // 1-based file line where the record starts
        var fields: [String]
    }

    static func parse(_ text: String, separator: Character) -> [Record] {
        let sep = separator.unicodeScalars.first!
        var records: [Record] = []
        var fields: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var line = 1, recordLine = 1
        var pendingContent = false

        func endField() { fields.append(String(field)); field = String.UnicodeScalarView() }
        func endRecord() {
            endField()
            records.append(Record(line: recordLine, fields: fields))
            fields = []
            pendingContent = false
        }

        let scalars = Array(text.unicodeScalars)
        var i = 0
        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < scalars.count, scalars[i + 1] == "\"" { field.append(c); i += 1 } else { inQuotes = false }
                } else {
                    if c == "\n" { line += 1 }
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
                pendingContent = true
            } else if c == sep {
                endField()
                pendingContent = true
            } else if c == "\r" || c == "\n" {
                if c == "\r", i + 1 < scalars.count, scalars[i + 1] == "\n" { i += 1 }
                endRecord()
                line += 1
                recordLine = line
            } else {
                field.append(c)
                pendingContent = true
            }
            i += 1
        }
        if pendingContent || !field.isEmpty { endRecord() }
        return records
    }

    static func escape(_ value: String, separator: Character = ",") -> String {
        let needsQuotes = value.unicodeScalars.contains { $0 == "\"" || $0 == "\r" || $0 == "\n" || $0 == separator.unicodeScalars.first! }
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func row(_ fields: [String], separator: Character = ",") -> String {
        fields.map { escape($0, separator: separator) }.joined(separator: String(separator))
    }
}
