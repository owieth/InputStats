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
                    // Get existing or create new
                    if var summary = try DailySummary.fetchOne(db, key: date) {
                        summary.mouseDistancePx += mouseDistance
                        summary.mouseClicksLeft += leftClicks
                        summary.mouseClicksRight += rightClicks
                        summary.mouseClicksMiddle += middleClicks
                        summary.keystrokes += keystrokes
                        try summary.update(db)
                    } else {
                        let newSummary = DailySummary(
                            date: date,
                            mouseDistancePx: mouseDistance,
                            mouseClicksLeft: leftClicks,
                            mouseClicksRight: rightClicks,
                            mouseClicksMiddle: middleClicks,
                            keystrokes: keystrokes
                        )
                        try newSummary.insert(db)
                    }
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
                    if var entry = try MouseHeatmapEntry
                        .filter(MouseHeatmapEntry.Columns.date == date)
                        .filter(MouseHeatmapEntry.Columns.screenId == screenId)
                        .filter(MouseHeatmapEntry.Columns.bucketX == bucketX)
                        .filter(MouseHeatmapEntry.Columns.bucketY == bucketY)
                        .fetchOne(db) {
                        entry.clickCount += 1
                        try entry.update(db)
                    } else {
                        let newEntry = MouseHeatmapEntry(
                            date: date,
                            screenId: screenId,
                            bucketX: bucketX,
                            bucketY: bucketY,
                            clickCount: 1
                        )
                        try newEntry.insert(db)
                    }
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
                    if var entry = try KeyboardEntry
                        .filter(KeyboardEntry.Columns.date == date)
                        .filter(KeyboardEntry.Columns.keyCode == keyCode)
                        .filter(KeyboardEntry.Columns.modifierFlags == modifierFlags)
                        .fetchOne(db) {
                        entry.count += 1
                        try entry.update(db)
                    } else {
                        let newEntry = KeyboardEntry(
                            date: date,
                            keyCode: keyCode,
                            modifierFlags: modifierFlags,
                            count: 1
                        )
                        try newEntry.insert(db)
                    }
                }
            } catch {
                print("Error updating keyboard entry: \(error)")
            }
        }
    }

    func updateKeyboardBatch(date: String, entries: [(keyCode: Int, modifierFlags: Int, count: Int)]) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    for entry in entries {
                        if var existing = try KeyboardEntry
                            .filter(KeyboardEntry.Columns.date == date)
                            .filter(KeyboardEntry.Columns.keyCode == entry.keyCode)
                            .filter(KeyboardEntry.Columns.modifierFlags == entry.modifierFlags)
                            .fetchOne(db) {
                            existing.count += entry.count
                            try existing.update(db)
                        } else {
                            let newEntry = KeyboardEntry(
                                date: date,
                                keyCode: entry.keyCode,
                                modifierFlags: entry.modifierFlags,
                                count: entry.count
                            )
                            try newEntry.insert(db)
                        }
                    }
                }
            } catch {
                print("Error updating keyboard batch: \(error)")
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
                }
                print("All data reset successfully")
            } catch {
                print("Error resetting data: \(error)")
            }
        }
    }
}
