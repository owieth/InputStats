import Foundation
import GRDB

struct DailySummary: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_summary"

    var date: String
    var mouseDistancePx: Double
    var mouseClicksLeft: Int
    var mouseClicksRight: Int
    var mouseClicksMiddle: Int
    var keystrokes: Int
    var scrollDistanceVertical: Double
    var scrollDistanceHorizontal: Double
    var firstActiveAt: String?
    var lastActiveAt: String?
    var activeMinutes: Int = 0

    enum CodingKeys: String, CodingKey {
        case date
        case mouseDistancePx = "mouse_distance_px"
        case mouseClicksLeft = "mouse_clicks_left"
        case mouseClicksRight = "mouse_clicks_right"
        case mouseClicksMiddle = "mouse_clicks_middle"
        case keystrokes
        case scrollDistanceVertical = "scroll_distance_vertical"
        case scrollDistanceHorizontal = "scroll_distance_horizontal"
        case firstActiveAt = "first_active_at"
        case lastActiveAt = "last_active_at"
        case activeMinutes = "active_minutes"
    }

    enum Columns {
        static let date = Column(CodingKeys.date)
        static let mouseDistancePx = Column(CodingKeys.mouseDistancePx)
        static let mouseClicksLeft = Column(CodingKeys.mouseClicksLeft)
        static let mouseClicksRight = Column(CodingKeys.mouseClicksRight)
        static let mouseClicksMiddle = Column(CodingKeys.mouseClicksMiddle)
        static let keystrokes = Column(CodingKeys.keystrokes)
        static let scrollDistanceVertical = Column(CodingKeys.scrollDistanceVertical)
        static let scrollDistanceHorizontal = Column(CodingKeys.scrollDistanceHorizontal)
        static let firstActiveAt = Column(CodingKeys.firstActiveAt)
        static let lastActiveAt = Column(CodingKeys.lastActiveAt)
        static let activeMinutes = Column(CodingKeys.activeMinutes)
    }
}
