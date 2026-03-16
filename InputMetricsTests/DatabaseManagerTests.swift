import XCTest
import GRDB
@testable import InputMetrics

final class DatabaseManagerTests: XCTestCase {

    // Since DatabaseManager is a singleton with a file-based DB,
    // we test models and their GRDB conformance with an in-memory DB

    private var dbQueue: DatabaseQueue!

    override func setUp() async throws {
        dbQueue = try DatabaseQueue()
        try await dbQueue.write { db in
            try db.create(table: "daily_summary") { t in
                t.column("date", .text).primaryKey()
                t.column("mouse_distance_px", .double).defaults(to: 0)
                t.column("mouse_clicks_left", .integer).defaults(to: 0)
                t.column("mouse_clicks_right", .integer).defaults(to: 0)
                t.column("mouse_clicks_middle", .integer).defaults(to: 0)
                t.column("keystrokes", .integer).defaults(to: 0)
                t.column("scroll_distance_vertical", .double).defaults(to: 0)
                t.column("scroll_distance_horizontal", .double).defaults(to: 0)
                t.column("first_active_at", .text)
                t.column("last_active_at", .text)
                t.column("active_minutes", .integer).defaults(to: 0)
                t.column("avg_mouse_speed", .double).defaults(to: 0)
                t.column("peak_mouse_speed", .double).defaults(to: 0)
                t.column("peak_wpm", .double).defaults(to: 0)
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

            try db.create(table: "app_usage") { t in
                t.column("date", .text)
                t.column("bundle_id", .text)
                t.column("app_name", .text).defaults(to: "")
                t.column("keystrokes", .integer).defaults(to: 0)
                t.column("mouse_clicks", .integer).defaults(to: 0)
                t.column("active_seconds", .integer).defaults(to: 0)
                t.primaryKey(["date", "bundle_id"])
            }
        }
    }

    override func tearDown() {
        dbQueue = nil
    }

    // MARK: - DailySummary CRUD

    func testInsertAndFetchDailySummary() async throws {
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

        try await dbQueue.write { db in
            try summary.insert(db)
        }

        let fetched = try await dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-01-15")
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.date, "2025-01-15")
        XCTAssertEqual(fetched?.mouseDistancePx, 1000)
        XCTAssertEqual(fetched?.keystrokes, 500)
    }

    func testUpdateDailySummary() async throws {
        let summary = DailySummary(
            date: "2025-01-15",
            mouseDistancePx: 1000,
            mouseClicksLeft: 10,
            mouseClicksRight: 0,
            mouseClicksMiddle: 0,
            keystrokes: 500,
            scrollDistanceVertical: 0,
            scrollDistanceHorizontal: 0
        )

        try await dbQueue.write { db in
            try summary.insert(db)
        }

        var modified = summary
        modified.keystrokes = 1000
        let updated = modified

        try await dbQueue.write { db in
            try updated.update(db)
        }

        let fetched = try await dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-01-15")
        }

        XCTAssertEqual(fetched?.keystrokes, 1000)
    }

    func testFetchNonExistentSummary() async throws {
        let fetched = try await dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2099-01-01")
        }
        XCTAssertNil(fetched)
    }

    // MARK: - KeyboardEntry CRUD

    func testInsertAndFetchKeyboardEntry() async throws {
        let entry = KeyboardEntry(date: "2025-01-15", keyCode: 0, modifierFlags: 0, count: 42)

        try await dbQueue.write { db in
            try entry.insert(db)
        }

        let entries = try await dbQueue.read { db in
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

    func testInsertAndFetchMouseHeatmap() async throws {
        let entry = MouseHeatmapEntry(date: "2025-01-15", screenId: "1", bucketX: 25, bucketY: 25, clickCount: 5)

        try await dbQueue.write { db in
            try entry.insert(db)
        }

        let entries = try await dbQueue.read { db in
            try MouseHeatmapEntry.filter(MouseHeatmapEntry.Columns.date == "2025-01-15").fetchAll(db)
        }

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.clickCount, 5)
    }

    // MARK: - HourlySummary CRUD

    func testInsertAndFetchHourlySummary() async throws {
        let summary = HourlySummary(date: "2025-01-15", hour: 14, mouseDistancePx: 500, mouseClicks: 20, keystrokes: 100)

        try await dbQueue.write { db in
            try summary.insert(db)
        }

        let summaries = try await dbQueue.read { db in
            try HourlySummary
                .filter(HourlySummary.Columns.date == "2025-01-15")
                .order(HourlySummary.Columns.hour)
                .fetchAll(db)
        }

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.hour, 14)
    }

    // MARK: - Backup & Restore

    func testBackupCreatesValidFile() async throws {
        let summary = DailySummary(
            date: "2025-06-01",
            mouseDistancePx: 500,
            mouseClicksLeft: 3,
            mouseClicksRight: 1,
            mouseClicksMiddle: 0,
            keystrokes: 200,
            scrollDistanceVertical: 10,
            scrollDistanceHorizontal: 5
        )

        try await dbQueue.write { db in
            try summary.insert(db)
        }

        let tempDir = FileManager.default.temporaryDirectory
        let backupURL = tempDir.appendingPathComponent("test_backup_\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: backupURL) }

        let backupDb = try DatabaseQueue(path: backupURL.path)
        try dbQueue.backup(to: backupDb)

        let fetched = try await backupDb.read { db in
            try DailySummary.fetchOne(db, key: "2025-06-01")
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.mouseDistancePx, 500)
        XCTAssertEqual(fetched?.keystrokes, 200)
    }

    func testRestoreFromValidBackup() async throws {
        let original = DailySummary(
            date: "2025-06-01",
            mouseDistancePx: 999,
            mouseClicksLeft: 7,
            mouseClicksRight: 2,
            mouseClicksMiddle: 1,
            keystrokes: 300,
            scrollDistanceVertical: 0,
            scrollDistanceHorizontal: 0
        )

        try await dbQueue.write { db in
            try original.insert(db)
        }

        let tempDir = FileManager.default.temporaryDirectory
        let backupURL = tempDir.appendingPathComponent("test_restore_\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: backupURL) }

        let backupDb = try DatabaseQueue(path: backupURL.path)
        try dbQueue.backup(to: backupDb)

        // Create a fresh in-memory DB with the same schema and restore into it
        let restoredDb = try DatabaseQueue()
        try await restoredDb.write { db in
            try db.create(table: "daily_summary") { t in
                t.column("date", .text).primaryKey()
                t.column("mouse_distance_px", .double).defaults(to: 0)
                t.column("mouse_clicks_left", .integer).defaults(to: 0)
                t.column("mouse_clicks_right", .integer).defaults(to: 0)
                t.column("mouse_clicks_middle", .integer).defaults(to: 0)
                t.column("keystrokes", .integer).defaults(to: 0)
                t.column("scroll_distance_vertical", .double).defaults(to: 0)
                t.column("scroll_distance_horizontal", .double).defaults(to: 0)
                t.column("first_active_at", .text)
                t.column("last_active_at", .text)
                t.column("active_minutes", .integer).defaults(to: 0)
                t.column("avg_mouse_speed", .double).defaults(to: 0)
                t.column("peak_mouse_speed", .double).defaults(to: 0)
                t.column("peak_wpm", .double).defaults(to: 0)
            }
        }

        try backupDb.backup(to: restoredDb)

        let fetched = try await restoredDb.read { db in
            try DailySummary.fetchOne(db, key: "2025-06-01")
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.date, "2025-06-01")
        XCTAssertEqual(fetched?.mouseDistancePx, 999)
        XCTAssertEqual(fetched?.keystrokes, 300)
    }

    // MARK: - Data Retention (Pruning)

    func testPruneRemovesOldData() async throws {
        let oldDate = "2020-01-01"
        let recentDate = "2099-12-31"

        try await dbQueue.write { db in
            try DailySummary(
                date: oldDate, mouseDistancePx: 100, mouseClicksLeft: 1,
                mouseClicksRight: 0, mouseClicksMiddle: 0, keystrokes: 50,
                scrollDistanceVertical: 0, scrollDistanceHorizontal: 0
            ).insert(db)

            try DailySummary(
                date: recentDate, mouseDistancePx: 200, mouseClicksLeft: 2,
                mouseClicksRight: 0, mouseClicksMiddle: 0, keystrokes: 100,
                scrollDistanceVertical: 0, scrollDistanceHorizontal: 0
            ).insert(db)

            try HourlySummary(date: oldDate, hour: 10, mouseDistancePx: 50, mouseClicks: 1, keystrokes: 10).insert(db)
            try HourlySummary(date: recentDate, hour: 10, mouseDistancePx: 50, mouseClicks: 1, keystrokes: 10).insert(db)

            try KeyboardEntry(date: oldDate, keyCode: 0, modifierFlags: 0, count: 5).insert(db)
            try KeyboardEntry(date: recentDate, keyCode: 0, modifierFlags: 0, count: 5).insert(db)

            try MouseHeatmapEntry(date: oldDate, screenId: "1", bucketX: 0, bucketY: 0, clickCount: 1).insert(db)
            try MouseHeatmapEntry(date: recentDate, screenId: "1", bucketX: 0, bucketY: 0, clickCount: 1).insert(db)

            try AppUsageEntry(date: oldDate, bundleId: "com.test", appName: "Test", keystrokes: 10, mouseClicks: 5, activeSeconds: 60).insert(db)
            try AppUsageEntry(date: recentDate, bundleId: "com.test", appName: "Test", keystrokes: 10, mouseClicks: 5, activeSeconds: 60).insert(db)
        }

        // Prune with a cutoff that removes oldDate but keeps recentDate
        let cutoffString = "2025-01-01"
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM daily_summary WHERE date < ?", arguments: [cutoffString])
            try db.execute(sql: "DELETE FROM mouse_heatmap WHERE date < ?", arguments: [cutoffString])
            try db.execute(sql: "DELETE FROM keyboard_heatmap WHERE date < ?", arguments: [cutoffString])
            try db.execute(sql: "DELETE FROM hourly_summary WHERE date < ?", arguments: [cutoffString])
            try db.execute(sql: "DELETE FROM app_usage WHERE date < ?", arguments: [cutoffString])
        }

        let dailyCount = try await dbQueue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM daily_summary") }
        let hourlyCount = try await dbQueue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM hourly_summary") }
        let keyboardCount = try await dbQueue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM keyboard_heatmap") }
        let mouseCount = try await dbQueue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mouse_heatmap") }
        let appUsageCount = try await dbQueue.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM app_usage") }

        XCTAssertEqual(dailyCount, 1)
        XCTAssertEqual(hourlyCount, 1)
        XCTAssertEqual(keyboardCount, 1)
        XCTAssertEqual(mouseCount, 1)
        XCTAssertEqual(appUsageCount, 1)
    }

    func testPrunePreservesDataAtCutoff() async throws {
        let cutoffDate = "2025-01-01"
        let afterCutoff = "2025-01-02"

        try await dbQueue.write { db in
            try DailySummary(
                date: cutoffDate, mouseDistancePx: 100, mouseClicksLeft: 1,
                mouseClicksRight: 0, mouseClicksMiddle: 0, keystrokes: 50,
                scrollDistanceVertical: 0, scrollDistanceHorizontal: 0
            ).insert(db)

            try DailySummary(
                date: afterCutoff, mouseDistancePx: 200, mouseClicksLeft: 2,
                mouseClicksRight: 0, mouseClicksMiddle: 0, keystrokes: 100,
                scrollDistanceVertical: 0, scrollDistanceHorizontal: 0
            ).insert(db)
        }

        // DELETE WHERE date < cutoff preserves cutoff date itself
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM daily_summary WHERE date < ?", arguments: [cutoffDate])
        }

        let remaining = try await dbQueue.read { db in
            try DailySummary.order(DailySummary.Columns.date).fetchAll(db)
        }

        XCTAssertEqual(remaining.count, 2)
        XCTAssertEqual(remaining[0].date, cutoffDate)
        XCTAssertEqual(remaining[1].date, afterCutoff)
    }

    // MARK: - Upsert Edge Cases

    func testDailySummaryUpsertAccumulatesValues() async throws {
        // First insert
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at, active_minutes, avg_mouse_speed, peak_mouse_speed, peak_wpm)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(date) DO UPDATE SET
                        mouse_distance_px = mouse_distance_px + excluded.mouse_distance_px,
                        mouse_clicks_left = mouse_clicks_left + excluded.mouse_clicks_left,
                        mouse_clicks_right = mouse_clicks_right + excluded.mouse_clicks_right,
                        mouse_clicks_middle = mouse_clicks_middle + excluded.mouse_clicks_middle,
                        keystrokes = keystrokes + excluded.keystrokes,
                        scroll_distance_vertical = scroll_distance_vertical + excluded.scroll_distance_vertical,
                        scroll_distance_horizontal = scroll_distance_horizontal + excluded.scroll_distance_horizontal,
                        first_active_at = COALESCE(daily_summary.first_active_at, excluded.first_active_at),
                        last_active_at = COALESCE(daily_summary.last_active_at, excluded.last_active_at),
                        active_minutes = active_minutes + excluded.active_minutes,
                        avg_mouse_speed = CASE WHEN excluded.avg_mouse_speed > 0 THEN excluded.avg_mouse_speed ELSE daily_summary.avg_mouse_speed END,
                        peak_mouse_speed = CASE WHEN excluded.peak_mouse_speed > daily_summary.peak_mouse_speed THEN excluded.peak_mouse_speed ELSE daily_summary.peak_mouse_speed END,
                        peak_wpm = CASE WHEN excluded.peak_wpm > daily_summary.peak_wpm THEN excluded.peak_wpm ELSE daily_summary.peak_wpm END
                    """,
                arguments: ["2025-06-01", 100.0, 5, 2, 1, 200, 10.0, 5.0, "08:00", "09:00", 30, 50.0, 120.0, 80.0]
            )
        }

        // Second upsert for the same date
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at, active_minutes, avg_mouse_speed, peak_mouse_speed, peak_wpm)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(date) DO UPDATE SET
                        mouse_distance_px = mouse_distance_px + excluded.mouse_distance_px,
                        mouse_clicks_left = mouse_clicks_left + excluded.mouse_clicks_left,
                        mouse_clicks_right = mouse_clicks_right + excluded.mouse_clicks_right,
                        mouse_clicks_middle = mouse_clicks_middle + excluded.mouse_clicks_middle,
                        keystrokes = keystrokes + excluded.keystrokes,
                        scroll_distance_vertical = scroll_distance_vertical + excluded.scroll_distance_vertical,
                        scroll_distance_horizontal = scroll_distance_horizontal + excluded.scroll_distance_horizontal,
                        first_active_at = COALESCE(daily_summary.first_active_at, excluded.first_active_at),
                        last_active_at = COALESCE(daily_summary.last_active_at, excluded.last_active_at),
                        active_minutes = active_minutes + excluded.active_minutes,
                        avg_mouse_speed = CASE WHEN excluded.avg_mouse_speed > 0 THEN excluded.avg_mouse_speed ELSE daily_summary.avg_mouse_speed END,
                        peak_mouse_speed = CASE WHEN excluded.peak_mouse_speed > daily_summary.peak_mouse_speed THEN excluded.peak_mouse_speed ELSE daily_summary.peak_mouse_speed END,
                        peak_wpm = CASE WHEN excluded.peak_wpm > daily_summary.peak_wpm THEN excluded.peak_wpm ELSE daily_summary.peak_wpm END
                    """,
                arguments: ["2025-06-01", 50.0, 3, 1, 0, 100, 5.0, 2.0, "10:00", "11:00", 15, 60.0, 100.0, 90.0]
            )
        }

        let fetched = try await dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-06-01")
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.mouseDistancePx, 150.0)
        XCTAssertEqual(fetched?.mouseClicksLeft, 8)
        XCTAssertEqual(fetched?.mouseClicksRight, 3)
        XCTAssertEqual(fetched?.mouseClicksMiddle, 1)
        XCTAssertEqual(fetched?.keystrokes, 300)
        XCTAssertEqual(fetched?.scrollDistanceVertical, 15.0)
        XCTAssertEqual(fetched?.scrollDistanceHorizontal, 7.0)
        XCTAssertEqual(fetched?.activeMinutes, 45)
    }

    func testUpsertPreservesPeakValues() async throws {
        // Insert with high peak values
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at, active_minutes, avg_mouse_speed, peak_mouse_speed, peak_wpm)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: ["2025-06-01", 0.0, 0, 0, 0, 0, 0.0, 0.0, nil, nil, 0, 0.0, 200.0, 150.0]
            )
        }

        // Upsert with lower peak values -- existing peaks should be preserved
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at, active_minutes, avg_mouse_speed, peak_mouse_speed, peak_wpm)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(date) DO UPDATE SET
                        mouse_distance_px = mouse_distance_px + excluded.mouse_distance_px,
                        mouse_clicks_left = mouse_clicks_left + excluded.mouse_clicks_left,
                        mouse_clicks_right = mouse_clicks_right + excluded.mouse_clicks_right,
                        mouse_clicks_middle = mouse_clicks_middle + excluded.mouse_clicks_middle,
                        keystrokes = keystrokes + excluded.keystrokes,
                        scroll_distance_vertical = scroll_distance_vertical + excluded.scroll_distance_vertical,
                        scroll_distance_horizontal = scroll_distance_horizontal + excluded.scroll_distance_horizontal,
                        first_active_at = COALESCE(daily_summary.first_active_at, excluded.first_active_at),
                        last_active_at = COALESCE(daily_summary.last_active_at, excluded.last_active_at),
                        active_minutes = active_minutes + excluded.active_minutes,
                        avg_mouse_speed = CASE WHEN excluded.avg_mouse_speed > 0 THEN excluded.avg_mouse_speed ELSE daily_summary.avg_mouse_speed END,
                        peak_mouse_speed = CASE WHEN excluded.peak_mouse_speed > daily_summary.peak_mouse_speed THEN excluded.peak_mouse_speed ELSE daily_summary.peak_mouse_speed END,
                        peak_wpm = CASE WHEN excluded.peak_wpm > daily_summary.peak_wpm THEN excluded.peak_wpm ELSE daily_summary.peak_wpm END
                    """,
                arguments: ["2025-06-01", 10.0, 1, 0, 0, 5, 0.0, 0.0, nil, nil, 0, 0.0, 50.0, 30.0]
            )
        }

        let fetched = try await dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-06-01")
        }

        XCTAssertNotNil(fetched)
        // Higher existing peaks should be preserved
        XCTAssertEqual(fetched?.peakMouseSpeed, 200.0)
        XCTAssertEqual(fetched?.peakWPM, 150.0)

        // Upsert with higher peak values -- new peaks should win
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at, active_minutes, avg_mouse_speed, peak_mouse_speed, peak_wpm)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(date) DO UPDATE SET
                        mouse_distance_px = mouse_distance_px + excluded.mouse_distance_px,
                        mouse_clicks_left = mouse_clicks_left + excluded.mouse_clicks_left,
                        mouse_clicks_right = mouse_clicks_right + excluded.mouse_clicks_right,
                        mouse_clicks_middle = mouse_clicks_middle + excluded.mouse_clicks_middle,
                        keystrokes = keystrokes + excluded.keystrokes,
                        scroll_distance_vertical = scroll_distance_vertical + excluded.scroll_distance_vertical,
                        scroll_distance_horizontal = scroll_distance_horizontal + excluded.scroll_distance_horizontal,
                        first_active_at = COALESCE(daily_summary.first_active_at, excluded.first_active_at),
                        last_active_at = COALESCE(daily_summary.last_active_at, excluded.last_active_at),
                        active_minutes = active_minutes + excluded.active_minutes,
                        avg_mouse_speed = CASE WHEN excluded.avg_mouse_speed > 0 THEN excluded.avg_mouse_speed ELSE daily_summary.avg_mouse_speed END,
                        peak_mouse_speed = CASE WHEN excluded.peak_mouse_speed > daily_summary.peak_mouse_speed THEN excluded.peak_mouse_speed ELSE daily_summary.peak_mouse_speed END,
                        peak_wpm = CASE WHEN excluded.peak_wpm > daily_summary.peak_wpm THEN excluded.peak_wpm ELSE daily_summary.peak_wpm END
                    """,
                arguments: ["2025-06-01", 0.0, 0, 0, 0, 0, 0.0, 0.0, nil, nil, 0, 0.0, 300.0, 250.0]
            )
        }

        let updated = try await dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-06-01")
        }

        XCTAssertEqual(updated?.peakMouseSpeed, 300.0)
        XCTAssertEqual(updated?.peakWPM, 250.0)
    }

    func testUpsertPreservesFirstActiveAt() async throws {
        // Insert with first_active_at set
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at, active_minutes, avg_mouse_speed, peak_mouse_speed, peak_wpm)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: ["2025-06-01", 0.0, 0, 0, 0, 0, 0.0, 0.0, "08:00", "09:00", 0, 0.0, 0.0, 0.0]
            )
        }

        // Upsert -- first_active_at should be preserved (COALESCE keeps existing)
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at, active_minutes, avg_mouse_speed, peak_mouse_speed, peak_wpm)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(date) DO UPDATE SET
                        first_active_at = COALESCE(daily_summary.first_active_at, excluded.first_active_at),
                        last_active_at = COALESCE(daily_summary.last_active_at, excluded.last_active_at)
                    """,
                arguments: ["2025-06-01", 0.0, 0, 0, 0, 0, 0.0, 0.0, "14:00", "15:00", 0, 0.0, 0.0, 0.0]
            )
        }

        let fetched = try await dbQueue.read { db in
            try DailySummary.fetchOne(db, key: "2025-06-01")
        }

        XCTAssertEqual(fetched?.firstActiveAt, "08:00")
        XCTAssertEqual(fetched?.lastActiveAt, "09:00")
    }

    // MARK: - Empty Database Queries

    func testEmptyDatabaseDailySummariesReturnsEmpty() async throws {
        let summaries = try await dbQueue.read { db in
            try DailySummary
                .filter(DailySummary.Columns.date >= "2025-01-01" && DailySummary.Columns.date <= "2025-12-31")
                .order(DailySummary.Columns.date)
                .fetchAll(db)
        }
        XCTAssertTrue(summaries.isEmpty)
    }

    func testEmptyDatabaseHourlySummariesReturnsEmpty() async throws {
        let summaries = try await dbQueue.read { db in
            try HourlySummary
                .filter(HourlySummary.Columns.date == "2025-01-15")
                .order(HourlySummary.Columns.hour)
                .fetchAll(db)
        }
        XCTAssertTrue(summaries.isEmpty)
    }

    func testEmptyDatabaseAllTimeTotalsReturnsNil() async throws {
        let summary = try await dbQueue.read { db in
            try DailySummary.fetchOne(db)
        }

        XCTAssertNil(summary)
    }

    func testEmptyDatabaseMouseHeatmapReturnsEmpty() async throws {
        let entries = try await dbQueue.read { db in
            try MouseHeatmapEntry.filter(MouseHeatmapEntry.Columns.date == "2025-01-15").fetchAll(db)
        }
        XCTAssertTrue(entries.isEmpty)
    }

    func testEmptyDatabaseKeyboardEntriesReturnsEmpty() async throws {
        let entries = try await dbQueue.read { db in
            try KeyboardEntry.filter(KeyboardEntry.Columns.date == "2025-01-15").fetchAll(db)
        }
        XCTAssertTrue(entries.isEmpty)
    }

    func testMouseHeatmapUpsertAccumulatesClickCount() async throws {
        // First insert via ON CONFLICT upsert
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO mouse_heatmap (date, screen_id, bucket_x, bucket_y, click_count)
                    VALUES (?, ?, ?, ?, 1)
                    ON CONFLICT(date, screen_id, bucket_x, bucket_y) DO UPDATE SET
                        click_count = click_count + 1
                    """,
                arguments: ["2025-06-01", "screen1", 10, 20]
            )
        }

        // Second upsert for same bucket
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO mouse_heatmap (date, screen_id, bucket_x, bucket_y, click_count)
                    VALUES (?, ?, ?, ?, 1)
                    ON CONFLICT(date, screen_id, bucket_x, bucket_y) DO UPDATE SET
                        click_count = click_count + 1
                    """,
                arguments: ["2025-06-01", "screen1", 10, 20]
            )
        }

        let entry = try await dbQueue.read { db in
            try MouseHeatmapEntry
                .filter(MouseHeatmapEntry.Columns.date == "2025-06-01")
                .filter(MouseHeatmapEntry.Columns.screenId == "screen1")
                .filter(MouseHeatmapEntry.Columns.bucketX == 10)
                .filter(MouseHeatmapEntry.Columns.bucketY == 20)
                .fetchOne(db)
        }

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.clickCount, 2)
    }

    func testKeyboardHeatmapUpsertAccumulatesCount() async throws {
        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO keyboard_heatmap (date, key_code, modifier_flags, count)
                    VALUES (?, ?, ?, 1)
                    ON CONFLICT(date, key_code, modifier_flags) DO UPDATE SET
                        count = count + 1
                    """,
                arguments: ["2025-06-01", 49, 0]
            )
        }

        try await dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO keyboard_heatmap (date, key_code, modifier_flags, count)
                    VALUES (?, ?, ?, 1)
                    ON CONFLICT(date, key_code, modifier_flags) DO UPDATE SET
                        count = count + 1
                    """,
                arguments: ["2025-06-01", 49, 0]
            )
        }

        let entry = try await dbQueue.read { db in
            try KeyboardEntry
                .filter(KeyboardEntry.Columns.date == "2025-06-01")
                .filter(KeyboardEntry.Columns.keyCode == 49)
                .filter(KeyboardEntry.Columns.modifierFlags == 0)
                .fetchOne(db)
        }

        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.count, 2)
    }
}
