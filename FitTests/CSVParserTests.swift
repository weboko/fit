import Foundation
import XCTest
@testable import Fit

/// RFC-4180 conformance for `CSVParser`. Pure string-in / rows-out — no SwiftData,
/// no actor isolation needed.
final class CSVParserTests: XCTestCase {

    // MARK: - parse

    func testSimpleRows() {
        let rows = CSVParser.parse("a,b,c\n1,2,3")
        XCTAssertEqual(rows, [["a", "b", "c"], ["1", "2", "3"]])
    }

    func testQuotedFieldWithEmbeddedComma() {
        let rows = CSVParser.parse("name,note\nSquat,\"heavy, deep\"")
        XCTAssertEqual(rows, [["name", "note"], ["Squat", "heavy, deep"]])
    }

    func testDoubledQuoteBecomesLiteralQuote() {
        // The field  "a""b"  represents  a"b
        let rows = CSVParser.parse("x\n\"a\"\"b\"")
        XCTAssertEqual(rows, [["x"], ["a\"b"]])
    }

    func testQuotedFieldWithEmbeddedNewline() {
        let rows = CSVParser.parse("a,b\n\"line1\nline2\",y")
        XCTAssertEqual(rows, [["a", "b"], ["line1\nline2", "y"]])
    }

    func testCRLFLineEndings() {
        let rows = CSVParser.parse("a,b\r\n1,2\r\n3,4")
        XCTAssertEqual(rows, [["a", "b"], ["1", "2"], ["3", "4"]])
    }

    func testLFLineEndings() {
        let rows = CSVParser.parse("a,b\n1,2\n3,4")
        XCTAssertEqual(rows, [["a", "b"], ["1", "2"], ["3", "4"]])
    }

    func testTrailingNewlineDoesNotProduceAPhantomRow() {
        // CRLF
        XCTAssertEqual(CSVParser.parse("a,b\r\n1,2\r\n"),
                       [["a", "b"], ["1", "2"]])
        // LF
        XCTAssertEqual(CSVParser.parse("a,b\n1,2\n"),
                       [["a", "b"], ["1", "2"]])
    }

    func testBlankUnquotedLineIsSkippedButQuotedEmptyIsKept() {
        // A genuine empty line between records is dropped.
        let rows = CSVParser.parse("a\n\nb")
        XCTAssertEqual(rows, [["a"], ["b"]])
        // A line that is a single quoted empty field is a real empty value.
        let kept = CSVParser.parse("a\n\"\"")
        XCTAssertEqual(kept, [["a"], [""]])
    }

    func testEmptyTrailingFieldsPreserved() {
        let rows = CSVParser.parse("a,b,c\n1,,3")
        XCTAssertEqual(rows, [["a", "b", "c"], ["1", "", "3"]])
    }

    // MARK: - parseKeyed

    func testParseKeyedMapsHeadersCaseAndWhitespaceInsensitively() {
        let csv = " Name , Reps \nSquat,5\nBench,8"
        let keyed = CSVParser.parseKeyed(csv)
        XCTAssertEqual(keyed.count, 2)
        // Header " Name " is normalised to "name".
        XCTAssertEqual(keyed[0]["name"], "Squat")
        XCTAssertEqual(keyed[0]["reps"], "5")
        XCTAssertEqual(keyed[1]["name"], "Bench")
        XCTAssertEqual(keyed[1]["reps"], "8")
    }

    func testParseKeyedShortRowFillsMissingTrailingColumnsWithEmpty() {
        let csv = "a,b,c\n1,2"
        let keyed = CSVParser.parseKeyed(csv)
        XCTAssertEqual(keyed[0]["a"], "1")
        XCTAssertEqual(keyed[0]["b"], "2")
        XCTAssertEqual(keyed[0]["c"], "") // missing column ⇒ empty string
    }

    func testParseKeyedEmptyDocumentIsEmpty() {
        XCTAssertEqual(CSVParser.parseKeyed("").count, 0)
        // Header only, no data rows.
        XCTAssertEqual(CSVParser.parseKeyed("a,b,c").count, 0)
    }
}
