import XCTest
@testable import InputMetrics

final class CSVExportTests: XCTestCase {

    func testCSVFieldEscapesQuotes() {
        let field = "He said \"hello\""
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        let result = "\"\(escaped)\""
        XCTAssertEqual(result, "\"He said \"\"hello\"\"\"")
    }

    func testCSVFieldWrapsInQuotes() {
        let field = "simple"
        let result = "\"\(field)\""
        XCTAssertEqual(result, "\"simple\"")
    }

    func testCSVRowJoinsWithCommas() {
        let fields = ["a", "b", "c"]
        let result = fields.map { "\"\($0)\"" }.joined(separator: ",")
        XCTAssertEqual(result, "\"a\",\"b\",\"c\"")
    }

    func testDailySummaryEncodesToJSON() throws {
        let summary = DailySummary(
            date: "2025-01-15",
            mouseDistancePx: 1000,
            mouseClicksLeft: 10,
            mouseClicksRight: 5,
            mouseClicksMiddle: 2,
            keystrokes: 500,
            scrollDistanceVertical: 100,
            scrollDistanceHorizontal: 50
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)
        let decoded = try JSONDecoder().decode(DailySummary.self, from: data)

        XCTAssertEqual(decoded.date, summary.date)
        XCTAssertEqual(decoded.mouseDistancePx, summary.mouseDistancePx)
        XCTAssertEqual(decoded.keystrokes, summary.keystrokes)
    }

    func testKeyboardEntryEncodesToJSON() throws {
        let entry = KeyboardEntry(date: "2025-01-15", keyCode: 0, modifierFlags: 0, count: 42)

        let encoder = JSONEncoder()
        let data = try encoder.encode(entry)
        let decoded = try JSONDecoder().decode(KeyboardEntry.self, from: data)

        XCTAssertEqual(decoded.keyCode, 0)
        XCTAssertEqual(decoded.count, 42)
    }

    func testDateHelperFormat() {
        let date = DateHelper.date(from: "2025-01-15")
        XCTAssertNotNil(date)

        if let date {
            let str = DateHelper.string(from: date)
            XCTAssertEqual(str, "2025-01-15")
        }
    }

    func testDateHelperInvalidDate() {
        let date = DateHelper.date(from: "not-a-date")
        XCTAssertNil(date)
    }
}
