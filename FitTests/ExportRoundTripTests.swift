import Foundation
import XCTest
@testable import Fit

/// A hermetic CSV export→import round-trip at the text level: build a document
/// with the real `CSVExporter` RFC-4180 writer, read it back with the real
/// `CSVParser`, and assert tricky values survive byte-for-byte. This is the
/// contract that protects every CSV export (no SwiftData / app environment).
final class ExportRoundTripTests: XCTestCase {

    func testEscapeRoundTripsThroughParseKeyed() {
        let header = ["id", "note", "weight_kg"]
        let rows: [[String]] = [
            // commas, embedded quotes, newline, and a plain numeric value.
            ["1", "heavy, deep", "100"],
            ["2", "said \"go\"", "82.5"],
            ["3", "line1\nline2", "60"],
            ["4", "", "0"], // empty note must come back as empty
        ]

        let document = CSVExporter.document(header: header, rows: rows)
        let keyed = CSVParser.parseKeyed(document)

        XCTAssertEqual(keyed.count, 4)

        XCTAssertEqual(keyed[0]["note"], "heavy, deep")
        XCTAssertEqual(keyed[0]["weight_kg"], "100")

        XCTAssertEqual(keyed[1]["note"], "said \"go\"")
        XCTAssertEqual(keyed[1]["weight_kg"], "82.5")

        XCTAssertEqual(keyed[2]["note"], "line1\nline2")

        XCTAssertEqual(keyed[3]["note"], "")
        XCTAssertEqual(keyed[3]["id"], "4")
    }

    func testDocumentUsesCRLFAndTrailingNewlineButNoPhantomRow() {
        let document = CSVExporter.document(header: ["a", "b"], rows: [["1", "2"]])
        XCTAssertTrue(document.contains("\r\n"))
        XCTAssertTrue(document.hasSuffix("\r\n"))

        // The trailing newline must not create an extra parsed row.
        let rows = CSVParser.parse(document)
        XCTAssertEqual(rows, [["a", "b"], ["1", "2"]])
    }

    func testEscapeLeavesPlainFieldsUnquoted() {
        // A field with no comma/quote/newline must not be wrapped.
        XCTAssertEqual(CSVExporter.escape("Squat"), "Squat")
        // A field with a comma must be wrapped.
        XCTAssertEqual(CSVExporter.escape("a,b"), "\"a,b\"")
        // A field with a quote must be wrapped and the quote doubled.
        XCTAssertEqual(CSVExporter.escape("a\"b"), "\"a\"\"b\"")
    }
}
