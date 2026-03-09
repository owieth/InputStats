import Foundation
import GRDB

final class DatabaseManager: @unchecked Sendable {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?
    private let dbQueue_serial = DispatchQueue(label: "com.inputmetrics.database", qos: .userInitiated)
    private(set) var initializationError: String?

    var isReady: Bool { dbQueue != nil }

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let dbFolder = appSupport.appendingPathComponent("InputMetrics", isDirectory: true)
            try fileManager.createDirectory(at: dbFolder, withIntermediateDirectories: true)

            let dbPath = dbFolder.appendingPathComponent("metrics.db").path
            print("Database path: \(dbPath)")

            dbQueue = try DatabaseQueue(path: dbPath)
            try migrator.migrate(dbQueue!)

            print("Database initialized successfully")
        } catch {
            initializationError = "Database setup failed: \(error.localizedDescription)"
            print("Database setup error: \(error)")
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            // Daily summary table
            try db.create(table: "daily_summary") { t in
                t.column("date", .text).primaryKey()
                t.column("mouse_distance_px", .double).defaults(to: 0)
                t.column("mouse_clicks_left", .integer).defaults(to: 0)
                t.column("mouse_clicks_right", .integer).defaults(to: 0)
                t.column("mouse_clicks_middle", .integer).defaults(to: 0)
                t.column("keystrokes", .integer).defaults(to: 0)
            }

            // Mouse heatmap table
            try db.create(table: "mouse_heatmap") { t in
                t.column("date", .text)
                t.column("screen_id", .text)
                t.column("bucket_x", .integer)
                t.column("bucket_y", .integer)
                t.column("click_count", .integer).defaults(to: 0)
                t.primaryKey(["date", "screen_id", "bucket_x", "bucket_y"])
            }

            // Keyboard heatmap table
            try db.create(table: "keyboard_heatmap") { t in
                t.column("date", .text)
                t.column("key_code", .integer)
                t.column("modifier_flags", .integer).defaults(to: 0)
                t.column("count", .integer).defaults(to: 0)
                t.primaryKey(["date", "key_code", "modifier_flags"])
            }

            // Hourly summary table
            try db.create(table: "hourly_summary") { t in
                t.column("date", .text)
                t.column("hour", .integer)
                t.column("mouse_distance_px", .double).defaults(to: 0)
                t.column("mouse_clicks", .integer).defaults(to: 0)
                t.column("keystrokes", .integer).defaults(to: 0)
                t.primaryKey(["date", "hour"])
            }
        }

        return migrator
    }

    // MARK: - Daily Summary Operations

    func updateDailySummary(
        date: String,
        mouseDistance: Double = 0,
        leftClicks: Int = 0,
        rightClicks: Int = 0,
        middleClicks: Int = 0,
        keystrokes: Int = 0
    ) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes)
                            VALUES (?, ?, ?, ?, ?, ?)
                            ON CONFLICT(date) DO UPDATE SET
                                mouse_distance_px = mouse_distance_px + excluded.mouse_distance_px,
                                mouse_clicks_left = mouse_clicks_left + excluded.mouse_clicks_left,
                                mouse_clicks_right = mouse_clicks_right + excluded.mouse_clicks_right,
                                mouse_clicks_middle = mouse_clicks_middle + excluded.mouse_clicks_middle,
                                keystrokes = keystrokes + excluded.keystrokes
                            """,
                        arguments: [date, mouseDistance, leftClicks, rightClicks, middleClicks, keystrokes]
                    )
                }
            } catch {
                print("Error updating daily summary: \(error)")
            }
        }
    }

    func getDailySummary(date: String) -> DailySummary? {
        guard let db = dbQueue else { return nil }

        do {
            return try db.read { db in
                try DailySummary.fetchOne(db, key: date)
            }
        } catch {
            print("Error fetching daily summary: \(error)")
            return nil
        }
    }

    func getDailySummaries(from startDate: String, to endDate: String) -> [DailySummary] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try DailySummary
                    .filter(DailySummary.Columns.date >= startDate && DailySummary.Columns.date <= endDate)
                    .order(DailySummary.Columns.date)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching daily summaries: \(error)")
            return []
        }
    }

    // MARK: - Mouse Heatmap Operations

    func updateMouseHeatmap(date: String, screenId: String, bucketX: Int, bucketY: Int) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO mouse_heatmap (date, screen_id, bucket_x, bucket_y, click_count)
                            VALUES (?, ?, ?, ?, 1)
                            ON CONFLICT(date, screen_id, bucket_x, bucket_y) DO UPDATE SET
                                click_count = click_count + 1
                            """,
                        arguments: [date, screenId, bucketX, bucketY]
                    )
                }
            } catch {
                print("Error updating mouse heatmap: \(error)")
            }
        }
    }

    func getMouseHeatmap(date: String) -> [MouseHeatmapEntry] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try MouseHeatmapEntry
                    .filter(MouseHeatmapEntry.Columns.date == date)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching mouse heatmap: \(error)")
            return []
        }
    }

    // MARK: - Keyboard Operations

    func updateKeyboard(date: String, keyCode: Int, modifierFlags: Int = 0) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO keyboard_heatmap (date, key_code, modifier_flags, count)
                            VALUES (?, ?, ?, 1)
                            ON CONFLICT(date, key_code, modifier_flags) DO UPDATE SET
                                count = count + 1
                            """,
                        arguments: [date, keyCode, modifierFlags]
                    )
                }
            } catch {
                print("Error updating keyboard entry: \(error)")
            }
        }
    }

    func getKeyboardEntries(date: String) -> [KeyboardEntry] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try KeyboardEntry
                    .filter(KeyboardEntry.Columns.date == date)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching keyboard entries: \(error)")
            return []
        }
    }

    // MARK: - Fetch All (for export)

    func getAllDailySummaries() -> [DailySummary] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try DailySummary.order(DailySummary.Columns.date).fetchAll(db)
            }
        } catch {
            print("Error fetching all daily summaries: \(error)")
            return []
        }
    }

    func getAllMouseHeatmapEntries() -> [MouseHeatmapEntry] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try MouseHeatmapEntry.order(MouseHeatmapEntry.Columns.date).fetchAll(db)
            }
        } catch {
            print("Error fetching all mouse heatmap entries: \(error)")
            return []
        }
    }

    func getAllKeyboardEntries() -> [KeyboardEntry] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try KeyboardEntry.order(KeyboardEntry.Columns.date).fetchAll(db)
            }
        } catch {
            print("Error fetching all keyboard entries: \(error)")
            return []
        }
    }

    // MARK: - Utility

    func resetAllData() {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    try db.execute(sql: "DELETE FROM daily_summary")
                    try db.execute(sql: "DELETE FROM mouse_heatmap")
                    try db.execute(sql: "DELETE FROM keyboard_heatmap")
                    try db.execute(sql: "DELETE FROM hourly_summary")
                }
                print("All data reset successfully")
            } catch {
                print("Error resetting data: \(error)")
            }
        }
    }
}
