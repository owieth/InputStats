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

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        registerV1Migration(&migrator)
        registerV2Migration(&migrator)
        registerV3Migration(&migrator)
        registerV4Migration(&migrator)
        registerV5Migration(&migrator)
        registerV6Migration(&migrator)

        return migrator
    }

    // MARK: - Migrations

    private func registerV1Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1") { db in
            try db.create(table: "daily_summary") { t in
                t.column("date", .text).primaryKey()
                t.column("mouse_distance_px", .double).defaults(to: 0)
                t.column("mouse_clicks_left", .integer).defaults(to: 0)
                t.column("mouse_clicks_right", .integer).defaults(to: 0)
                t.column("mouse_clicks_middle", .integer).defaults(to: 0)
                t.column("keystrokes", .integer).defaults(to: 0)
            }
        }
    }

    private func registerV2Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v2") { db in
            try db.create(table: "mouse_heatmap") { t in
                t.column("date", .text)
                t.column("screen_id", .text)
                t.column("bucket_x", .integer)
                t.column("bucket_y", .integer)
                t.column("click_count", .integer).defaults(to: 0)
                t.primaryKey(["date", "screen_id", "bucket_x", "bucket_y"])
            }
        }
    }

    private func registerV3Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v3") { db in
            try db.create(table: "keyboard_heatmap") { t in
                t.column("date", .text)
                t.column("key_code", .integer)
                t.column("modifier_flags", .integer).defaults(to: 0)
                t.column("count", .integer).defaults(to: 0)
                t.primaryKey(["date", "key_code", "modifier_flags"])
            }
        }
    }

    private func registerV4Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v4") { db in
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

    private func registerV5Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v5") { db in
            try db.alter(table: "daily_summary") { t in
                t.add(column: "scroll_distance_vertical", .double).defaults(to: 0)
                t.add(column: "scroll_distance_horizontal", .double).defaults(to: 0)
            }
        }
    }

    private func registerV6Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v6") { db in
            try db.alter(table: "daily_summary") { t in
                t.add(column: "first_active_at", .text)
                t.add(column: "last_active_at", .text)
            }
        }
    }

    // MARK: - Daily Summary Operations

    func updateDailySummary(
        date: String,
        mouseDistance: Double = 0,
        leftClicks: Int = 0,
        rightClicks: Int = 0,
        middleClicks: Int = 0,
        keystrokes: Int = 0,
        scrollVertical: Double = 0,
        scrollHorizontal: Double = 0,
        firstActiveAt: String? = nil,
        lastActiveAt: String? = nil
    ) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO daily_summary (date, mouse_distance_px, mouse_clicks_left, mouse_clicks_right, mouse_clicks_middle, keystrokes, scroll_distance_vertical, scroll_distance_horizontal, first_active_at, last_active_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ON CONFLICT(date) DO UPDATE SET
                                mouse_distance_px = mouse_distance_px + excluded.mouse_distance_px,
                                mouse_clicks_left = mouse_clicks_left + excluded.mouse_clicks_left,
                                mouse_clicks_right = mouse_clicks_right + excluded.mouse_clicks_right,
                                mouse_clicks_middle = mouse_clicks_middle + excluded.mouse_clicks_middle,
                                keystrokes = keystrokes + excluded.keystrokes,
                                scroll_distance_vertical = scroll_distance_vertical + excluded.scroll_distance_vertical,
                                scroll_distance_horizontal = scroll_distance_horizontal + excluded.scroll_distance_horizontal,
                                first_active_at = COALESCE(daily_summary.first_active_at, excluded.first_active_at),
                                last_active_at = COALESCE(excluded.last_active_at, daily_summary.last_active_at)
                            """,
                        arguments: [date, mouseDistance, leftClicks, rightClicks, middleClicks, keystrokes, scrollVertical, scrollHorizontal, firstActiveAt, lastActiveAt]
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

    // MARK: - Hourly Summary Operations

    func updateHourlySummary(
        date: String,
        hour: Int,
        mouseDistance: Double = 0,
        mouseClicks: Int = 0,
        keystrokes: Int = 0
    ) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    if var summary = try HourlySummary
                        .filter(HourlySummary.Columns.date == date)
                        .filter(HourlySummary.Columns.hour == hour)
                        .fetchOne(db) {
                        summary.mouseDistancePx += mouseDistance
                        summary.mouseClicks += mouseClicks
                        summary.keystrokes += keystrokes
                        try summary.update(db)
                    } else {
                        let newSummary = HourlySummary(
                            date: date,
                            hour: hour,
                            mouseDistancePx: mouseDistance,
                            mouseClicks: mouseClicks,
                            keystrokes: keystrokes
                        )
                        try newSummary.insert(db)
                    }
                }
            } catch {
                print("Error updating hourly summary: \(error)")
            }
        }
    }

    func getHourlySummaries(date: String) -> [HourlySummary] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try HourlySummary
                    .filter(HourlySummary.Columns.date == date)
                    .order(HourlySummary.Columns.hour)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching hourly summaries: \(error)")
            return []
        }
    }

    func getHourlySummaries(from startDate: String, to endDate: String) -> [HourlySummary] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try HourlySummary
                    .filter(HourlySummary.Columns.date >= startDate && HourlySummary.Columns.date <= endDate)
                    .order(HourlySummary.Columns.date, HourlySummary.Columns.hour)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching hourly summaries: \(error)")
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

    func batchUpdateMouseHeatmap(_ buffer: [HeatmapBucketKey: Int]) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    for (key, count) in buffer {
                        if var entry = try MouseHeatmapEntry
                            .filter(MouseHeatmapEntry.Columns.date == key.date)
                            .filter(MouseHeatmapEntry.Columns.screenId == key.screenId)
                            .filter(MouseHeatmapEntry.Columns.bucketX == key.bucketX)
                            .filter(MouseHeatmapEntry.Columns.bucketY == key.bucketY)
                            .fetchOne(db) {
                            entry.clickCount += count
                            try entry.update(db)
                        } else {
                            let newEntry = MouseHeatmapEntry(
                                date: key.date,
                                screenId: key.screenId,
                                bucketX: key.bucketX,
                                bucketY: key.bucketY,
                                clickCount: count
                            )
                            try newEntry.insert(db)
                        }
                    }
                }
            } catch {
                print("Error batch updating mouse heatmap: \(error)")
            }
        }
    }

    func getMouseHeatmap(date: String, screenId: String? = nil) -> [MouseHeatmapEntry] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                var request = MouseHeatmapEntry
                    .filter(MouseHeatmapEntry.Columns.date == date)

                if let screenId {
                    request = request.filter(MouseHeatmapEntry.Columns.screenId == screenId)
                }

                return try request.fetchAll(db)
            }
        } catch {
            print("Error fetching mouse heatmap: \(error)")
            return []
        }
    }

    func getDistinctScreenIds(date: String) -> [String] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try String.fetchAll(
                    db,
                    sql: "SELECT DISTINCT screen_id FROM mouse_heatmap WHERE date = ? ORDER BY screen_id",
                    arguments: [date]
                )
            }
        } catch {
            print("Error fetching screen IDs: \(error)")
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

    // MARK: - Aggregated Totals

    struct AllTimeTotals {
        var distance: Double
        var clicksLeft: Int
        var clicksRight: Int
        var clicksMiddle: Int
        var keystrokes: Int
        var scrollVertical: Double
        var scrollHorizontal: Double

        static let zero = AllTimeTotals(distance: 0, clicksLeft: 0, clicksRight: 0, clicksMiddle: 0, keystrokes: 0, scrollVertical: 0, scrollHorizontal: 0)

        var totalClicks: Int { clicksLeft + clicksRight + clicksMiddle }
    }

    func getAllTimeTotals() -> AllTimeTotals {
        guard let db = dbQueue else { return .zero }

        do {
            return try db.read { db in
                let row = try Row.fetchOne(db, sql: """
                    SELECT
                        COALESCE(SUM(mouse_distance_px), 0) AS distance,
                        COALESCE(SUM(mouse_clicks_left), 0) AS clicks_left,
                        COALESCE(SUM(mouse_clicks_right), 0) AS clicks_right,
                        COALESCE(SUM(mouse_clicks_middle), 0) AS clicks_middle,
                        COALESCE(SUM(keystrokes), 0) AS keystrokes,
                        COALESCE(SUM(scroll_distance_vertical), 0) AS scroll_vertical,
                        COALESCE(SUM(scroll_distance_horizontal), 0) AS scroll_horizontal
                    FROM daily_summary
                    """)
                guard let row else { return .zero }
                return AllTimeTotals(
                    distance: row["distance"],
                    clicksLeft: row["clicks_left"],
                    clicksRight: row["clicks_right"],
                    clicksMiddle: row["clicks_middle"],
                    keystrokes: row["keystrokes"],
                    scrollVertical: row["scroll_vertical"],
                    scrollHorizontal: row["scroll_horizontal"]
                )
            }
        } catch {
            print("Error fetching all-time totals: \(error)")
            return .zero
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

    func getAllHourlySummaries() -> [HourlySummary] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try HourlySummary
                    .order(HourlySummary.Columns.date, HourlySummary.Columns.hour)
                    .fetchAll(db)
            }
        } catch {
            print("Error fetching all hourly summaries: \(error)")
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
                    try db.execute(sql: "DELETE FROM \(DailySummary.databaseTableName)")
                    try db.execute(sql: "DELETE FROM \(MouseHeatmapEntry.databaseTableName)")
                    try db.execute(sql: "DELETE FROM \(KeyboardEntry.databaseTableName)")
                    try db.execute(sql: "DELETE FROM \(HourlySummary.databaseTableName)")
                }
                print("All data reset successfully")
            } catch {
                print("Error resetting data: \(error)")
            }
        }
    }

    // MARK: - Data Retention

    func pruneOldData(olderThanDays days: Int) {
        guard let db = dbQueue else { return }

        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let cutoffString = formatter.string(from: cutoffDate)

        dbQueue_serial.async {
            do {
                try db.write { db in
                    try db.execute(sql: "DELETE FROM daily_summary WHERE date < ?", arguments: [cutoffString])
                    try db.execute(sql: "DELETE FROM mouse_heatmap WHERE date < ?", arguments: [cutoffString])
                    try db.execute(sql: "DELETE FROM keyboard_heatmap WHERE date < ?", arguments: [cutoffString])
                    try db.execute(sql: "DELETE FROM hourly_summary WHERE date < ?", arguments: [cutoffString])
                    try db.execute(sql: "VACUUM")
                }
                print("Pruned data older than \(cutoffString)")
            } catch {
                print("Error pruning old data: \(error)")
            }
        }
    }

    // MARK: - Database Size

    func getDatabaseFileSize() -> Int64 {
        do {
            let fileManager = FileManager.default
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )

            let dbPath = appSupport
                .appendingPathComponent("InputMetrics", isDirectory: true)
                .appendingPathComponent("metrics.db")

            let attributes = try fileManager.attributesOfItem(atPath: dbPath.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            print("Error getting database file size: \(error)")
            return 0
        }
    }

    func getRecordCounts() -> (dailySummaries: Int, mouseHeatmap: Int, keyboardHeatmap: Int, hourlySummaries: Int) {
        guard let db = dbQueue else { return (0, 0, 0, 0) }

        do {
            return try db.read { db in
                let daily = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM daily_summary") ?? 0
                let mouse = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM mouse_heatmap") ?? 0
                let keyboard = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM keyboard_heatmap") ?? 0
                let hourly = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM hourly_summary") ?? 0
                return (daily, mouse, keyboard, hourly)
            }
        } catch {
            print("Error getting record counts: \(error)")
            return (0, 0, 0, 0)
        }
    }
}
