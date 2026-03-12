import Foundation
import GRDB

struct AppUsageEntry: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "app_usage"

    var date: String
    var bundleId: String
    var appName: String
    var keystrokes: Int
    var mouseClicks: Int
    var activeSeconds: Int

    enum CodingKeys: String, CodingKey {
        case date
        case bundleId = "bundle_id"
        case appName = "app_name"
        case keystrokes
        case mouseClicks = "mouse_clicks"
        case activeSeconds = "active_seconds"
    }

    enum Columns {
        static let date = Column(CodingKeys.date)
        static let bundleId = Column(CodingKeys.bundleId)
        static let appName = Column(CodingKeys.appName)
        static let keystrokes = Column(CodingKeys.keystrokes)
        static let mouseClicks = Column(CodingKeys.mouseClicks)
        static let activeSeconds = Column(CodingKeys.activeSeconds)
    }
}
