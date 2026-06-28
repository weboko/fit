import Foundation

/// A correct RFC-4180 CSV reader — the read counterpart to `CSVExporter`.
///
/// Handles quoted fields (commas, CR/LF/CRLF newlines inside quotes, and doubled
/// `""` quotes), is tolerant of both CRLF and LF line endings, trims a single
/// trailing newline, and skips fully-empty lines. No SwiftUI, no SwiftData — a
/// pure string-in / rows-out parser, safe to run anywhere.
enum CSVParser {

    /// Parse a CSV document into rows of string fields. Quoted fields may contain
    /// commas, newlines and escaped (doubled) double-quotes. A record that is a
    /// single, unquoted, empty field (a genuine blank line) is skipped; a line of
    /// `""` is preserved as a real empty value.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        // Whether any field in the current record was quoted, so a line of `""`
        // is kept as a real empty value rather than treated as a blank line.
        var recordHadQuotes = false

        let scalars = Array(text.unicodeScalars)
        let n = scalars.count
        var i = 0

        func endField() {
            record.append(field)
            field = ""
        }

        func endRecord() {
            endField()
            // Drop a record that is a single unquoted empty field (a blank line).
            if record.count == 1, record[0].isEmpty, !recordHadQuotes {
                record = []
                recordHadQuotes = false
                return
            }
            rows.append(record)
            record = []
            recordHadQuotes = false
        }

        while i < n {
            let c = scalars[i]

            if inQuotes {
                if c == "\"" {
                    // A doubled quote inside a quoted field is a literal quote.
                    if i + 1 < n, scalars[i + 1] == "\"" {
                        field.unicodeScalars.append("\"")
                        i += 2
                    } else {
                        inQuotes = false
                        i += 1
                    }
                } else {
                    field.unicodeScalars.append(c)
                    i += 1
                }
                continue
            }

            switch c {
            case "\"":
                inQuotes = true
                recordHadQuotes = true
                i += 1
            case ",":
                endField()
                i += 1
            case "\r":
                endRecord()
                // Consume a following LF so CRLF is one terminator.
                i += (i + 1 < n && scalars[i + 1] == "\n") ? 2 : 1
            case "\n":
                endRecord()
                i += 1
            default:
                field.unicodeScalars.append(c)
                i += 1
            }
        }

        // Flush any trailing field/record not terminated by a newline.
        if !field.isEmpty || !record.isEmpty || recordHadQuotes {
            endRecord()
        }

        return rows
    }

    /// Parse a CSV document into header-keyed dictionaries. The first row is the
    /// header; its names are lowercased and trimmed so lookups by header name are
    /// case/whitespace-insensitive. Returns an empty array when there is no header
    /// or no data rows.
    static func parseKeyed(_ text: String) -> [[String: String]] {
        let rows = parse(text)
        guard let header = rows.first else { return [] }
        let keys = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        var result: [[String: String]] = []
        result.reserveCapacity(max(rows.count - 1, 0))
        for row in rows.dropFirst() {
            var dict: [String: String] = [:]
            for (index, key) in keys.enumerated() where !key.isEmpty {
                dict[key] = index < row.count ? row[index] : ""
            }
            result.append(dict)
        }
        return result
    }
}
