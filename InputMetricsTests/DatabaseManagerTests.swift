import XCTest
import GRDB
@testable import InputMetrics

final class DatabaseManagerTests: XCTestCase {

    // Since DatabaseManager is a singleton with a file-based DB,
    // we test models and their GRDB conformance with an in-memory DB

    private var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        dbQueue = try DatabaseQueue()
        try dbQueue.write { db in
            try db.create(table: "daily_summary") { t in
                t.column("date", .text).primaryKey()
                t.column("mouse_distance_px", .double).defaults(to: 0)
                t.column("mouse_clicks_left", .integer).defaults(to: 0)
                t.column("mouse_clicks_right", .integer).defaults(to: 0)
                t.column("mouse_clicks_middle", .integer).defaults(to: 0)
                t.column("keystrokes", .integer).defaults(to: 0)
                t.column("scroll_distance_vertical", .double).defaults(to: 0)
                t.column("scroll_distance_horizontal", .double).defaults(to: 0)
            }

            try db.create(table: "mouse_heatmap") { t in
                t.column("date", .text)
                t.column("screen_id", .text)
                t.column("bucket_x", .integer)
                t.column("bucket_y", .integer)
                t.column("click_count", .integer).defaults(to: 0)
                t.primaryKey(["date", "screen_id", "bucket_x", "bucket_y"])
            }

            try db.create(table: "keyboard_heatmap") { t in
                t.column("date", .text)
                t.column("key_code", .integer)
                t.column("modifier_flags", .integer).defaults(to: 0)
                t.column("count", .integer).defaults(to: 0)
                t.primaryKey(["date", "key_code", "modifier_flags"])
            }

            try db.create(table: "hourly_summary") { t in
                t.column("date", .text)
                t.column("hour", .integer)
                t.column("mouse_distance_px", .double).defaults(to: 0)
                t.column("mouse_clicks", .integer).defaults(to: 0)
                t.column("keystrokes", .integer).defaults(to: 0)
                t.primaryKey(["date", "hour"])
            }
        }
    }

    override func tearDown() {
        dbQueue = nil
    }

    // MARK: - DailySummary CRUD

    func testInsertAndFetchDailySummary() throws {
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

        try dbQueue.write { db in
            try summary.insert(db)
        }

        let fetched = try dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-01-15")
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.date, "2025-01-15")
        XCTAssertEqual(fetched?.mouseDistancePx, 1000)
        XCTAssertEqual(fetched?.keystrokes, 500)
    }

    func testUpdateDailySummary() throws {
        var summary = DailySummary(
            date: "2025-01-15",
            mouseDistancePx: 1000,
            mouseClicksLeft: 10,
            mouseClicksRight: 0,
            mouseClicksMiddle: 0,
            keystrokes: 500,
            scrollDistanceVertical: 0,
            scrollDistanceHorizontal: 0
        )

        try dbQueue.write { db in
            try summary.insert(db)
        }

        summary.keystrokes = 1000

        try dbQueue.write { db in
            try summary.update(db)
        }

        let fetched = try dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-01-15")
        }

        XCTAssertEqual(fetched?.keystrokes, 1000)
    }

    func testFetchNonExistentSummary() throws {
        let fetched = try dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2099-01-01")
        }
        XCTAssertNil(fetched)
    }

    // MARK: - KeyboardEntry CRUD

    func testInsertAndFetchKeyboardEntry() throws {
        let entry = KeyboardEntry(date: "2025-01-15", keyCode: 0, modifierFlags: 0, count: 42)

        try dbQueue.write { db in
            try entry.insert(db)
        }

        let entries = try dbQueue.read { db in
            try KeyboardEntry.filter(KeyboardEntry.Columns.date == "2025-01-15").fetchAll(db)
        }

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.keyCode, 0)
        XCTAssertEqual(entries.first?.count, 42)
    }

    func testKeyboardEntryCompositeId() {
        let entry = KeyboardEntry(date: "2025-01-15", keyCode: 49, modifierFlags: 256, count: 10)
        XCTAssertEqual(entry.compositeId, "49-256")
    }

    // MARK: - MouseHeatmapEntry CRUD

    func testInsertAndFetchMouseHeatmap() throws {
        let entry = MouseHeatmapEntry(date: "2025-01-15", screenId: "1", bucketX: 25, bucketY: 25, clickCount: 5)

        try dbQueue.write { db in
            try entry.insert(db)
        }

        let entries = try dbQueue.read { db in
            try MouseHeatmapEntry.filter(MouseHeatmapEntry.Columns.date == "2025-01-15").fetchAll(db)
        }

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.clickCount, 5)
    }

    // MARK: - HourlySummary CRUD

    func testInsertAndFetchHourlySummary() throws {
        let summary = HourlySummary(date: "2025-01-15", hour: 14, mouseDistancePx: 500, mouseClicks: 20, keystrokes: 100)

        try dbQueue.write { db in
            try summary.insert(db)
        }

        let summaries = try dbQueue.read { db in
            try HourlySummary
                .filter(HourlySummary.Columns.date == "2025-01-15")
                .order(HourlySummary.Columns.hour)
                .fetchAll(db)
        }

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.hour, 14)
    }
}
