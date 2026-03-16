import Foundation
import GRDB
import os

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
            AppLogger.database.info("Database path: \(dbPath)")

            dbQueue = try DatabaseQueue(path: dbPath)
            try migrator.migrate(dbQueue!)

            AppLogger.database.info("Database initialized")
        } catch {
            initializationError = "Database setup failed: \(error.localizedDescription)"
            AppLogger.database.error("Setup failed: \(error.localizedDescription)")
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
        registerV7Migration(&migrator)
        registerV8Migration(&migrator)
        registerV9Migration(&migrator)

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

    private func registerV7Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v7") { db in
            try db.alter(table: "daily_summary") { t in
                t.add(column: "active_minutes", .integer).defaults(to: 0)
            }
        }
    }

    private func registerV8Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v8") { db in
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

    private func registerV9Migration(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v9") { db in
            try db.alter(table: "daily_summary") { t in
                t.add(column: "avg_mouse_speed", .double).defaults(to: 0)
                t.add(column: "peak_mouse_speed", .double).defaults(to: 0)
                t.add(column: "peak_wpm", .double).defaults(to: 0)
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
        lastActiveAt: String? = nil,
        activeMinutes: Int = 0,
        avgMouseSpeed: Double = 0,
        peakMouseSpeed: Double = 0,
        peakWPM: Double = 0
    ) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
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
                        arguments: [date, mouseDistance, leftClicks, rightClicks, middleClicks, keystrokes, scrollVertical, scrollHorizontal, firstActiveAt, lastActiveAt, activeMinutes, avgMouseSpeed, peakMouseSpeed, peakWPM]
                    )
                }
            } catch {
                AppLogger.database.error("Update daily summary failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch daily summary failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch daily summaries failed: \(error.localizedDescription)")
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
                AppLogger.database.error("Update hourly summary failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch hourly summaries failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch hourly summaries range failed: \(error.localizedDescription)")
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
                AppLogger.database.error("Update mouse heatmap failed: \(error.localizedDescription)")
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
                AppLogger.database.error("Batch update mouse heatmap failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch mouse heatmap failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch screen IDs failed: \(error.localizedDescription)")
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
                AppLogger.database.error("Update keyboard entry failed: \(error.localizedDescription)")
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
                AppLogger.database.error("Update keyboard batch failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch keyboard entries failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - App Usage Operations

    func updateAppUsage(date: String, bundleId: String, appName: String, keystrokes: Int = 0, mouseClicks: Int = 0, activeSeconds: Int = 0) {
        guard let db = dbQueue else { return }

        dbQueue_serial.async {
            do {
                try db.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO app_usage (date, bundle_id, app_name, keystrokes, mouse_clicks, active_seconds)
                            VALUES (?, ?, ?, ?, ?, ?)
                            ON CONFLICT(date, bundle_id) DO UPDATE SET
                                app_name = excluded.app_name,
                                keystrokes = keystrokes + excluded.keystrokes,
                                mouse_clicks = mouse_clicks + excluded.mouse_clicks,
                                active_seconds = active_seconds + excluded.active_seconds
                            """,
                        arguments: [date, bundleId, appName, keystrokes, mouseClicks, activeSeconds]
                    )
                }
            } catch {
                AppLogger.database.error("Update app usage failed: \(error.localizedDescription)")
            }
        }
    }

    func getAppUsage(date: String) -> [AppUsageEntry] {
        guard let db = dbQueue else { return [] }

        do {
            return try db.read { db in
                try AppUsageEntry
                    .filter(AppUsageEntry.Columns.date == date)
                    .order(AppUsageEntry.Columns.keystrokes.desc)
                    .fetchAll(db)
            }
        } catch {
            AppLogger.database.error("Fetch app usage failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch all-time totals failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch all daily summaries failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch all hourly summaries failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch all mouse heatmap entries failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Fetch all keyboard entries failed: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Backup & Restore

    func getDatabasePath() -> URL? {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return nil }
        return appSupport
            .appendingPathComponent("InputMetrics", isDirectory: true)
            .appendingPathComponent("metrics.db")
    }

    func backupDatabase(to url: URL) throws {
        guard let db = dbQueue else {
            throw NSError(domain: "InputMetrics", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not ready"])
        }

        AppLogger.database.info("Starting backup to \(url.path)")
        try db.backup(to: DatabaseQueue(path: url.path))

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            AppLogger.database.error("Backup file does not exist after creation: \(url.path)")
            throw NSError(domain: "InputMetrics", code: 3, userInfo: [NSLocalizedDescriptionKey: "Backup file was not created"])
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        guard fileSize > 0 else {
            AppLogger.database.error("Backup file is empty: \(url.path)")
            throw NSError(domain: "InputMetrics", code: 4, userInfo: [NSLocalizedDescriptionKey: "Backup file is empty"])
        }

        AppLogger.database.info("Backup completed (\(fileSize) bytes)")
    }

    private static let requiredTables: Set<String> = [
        "daily_summary", "mouse_heatmap", "keyboard_heatmap", "hourly_summary", "app_usage"
    ]

    func restoreDatabase(from url: URL) throws {
        guard dbQueue != nil else {
            throw NSError(domain: "InputMetrics", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not ready"])
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            AppLogger.database.error("Backup file not found: \(url.path)")
            throw NSError(domain: "InputMetrics", code: 2, userInfo: [NSLocalizedDescriptionKey: "Backup file not found"])
        }

        AppLogger.database.info("Validating backup at \(url.path)")

        let backupDb = try DatabaseQueue(path: url.path)

        // Validate all required tables exist in the backup
        let existingTables = try backupDb.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'")
        }
        let existingTableSet = Set(existingTables)
        let missingTables = Self.requiredTables.subtracting(existingTableSet)

        guard missingTables.isEmpty else {
            let sorted = missingTables.sorted().joined(separator: ", ")
            AppLogger.database.error("Backup is missing required tables: \(sorted)")
            throw NSError(domain: "InputMetrics", code: 5, userInfo: [NSLocalizedDescriptionKey: "Backup is missing required tables: \(sorted)"])
        }

        AppLogger.database.info("Backup validation passed, restoring database")

        // Restore by copying backup contents into the current database
        try backupDb.backup(to: dbQueue!)

        // Re-run migrations in case the backup is from an older schema
        do {
            try migrator.migrate(dbQueue!)
        } catch {
            AppLogger.database.error("Migration after restore failed: \(error.localizedDescription)")
            throw NSError(domain: "InputMetrics", code: 6, userInfo: [NSLocalizedDescriptionKey: "Migration after restore failed: \(error.localizedDescription)"])
        }

        AppLogger.database.info("Database restore completed")
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
                    try db.execute(sql: "DELETE FROM \(AppUsageEntry.databaseTableName)")
                }
                AppLogger.database.info("All data reset")
            } catch {
                AppLogger.database.error("Reset data failed: \(error.localizedDescription)")
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
                    try db.execute(sql: "DELETE FROM app_usage WHERE date < ?", arguments: [cutoffString])
                    try db.execute(sql: "VACUUM")
                }
                AppLogger.database.info("Pruned data older than \(cutoffString)")
            } catch {
                AppLogger.database.error("Prune old data failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Get database file size failed: \(error.localizedDescription)")
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
            AppLogger.database.error("Get record counts failed: \(error.localizedDescription)")
            return (0, 0, 0, 0)
        }
    }
}
