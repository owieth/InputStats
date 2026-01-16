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

    enum CodingKeys: String, CodingKey {
        case date
        case mouseDistancePx = "mouse_distance_px"
        case mouseClicksLeft = "mouse_clicks_left"
        case mouseClicksRight = "mouse_clicks_right"
        case mouseClicksMiddle = "mouse_clicks_middle"
        case keystrokes
    }

    enum Columns {
        static let date = Column(CodingKeys.date)
        static let mouseDistancePx = Column(CodingKeys.mouseDistancePx)
        static let mouseClicksLeft = Column(CodingKeys.mouseClicksLeft)
        static let mouseClicksRight = Column(CodingKeys.mouseClicksRight)
        static let mouseClicksMiddle = Column(CodingKeys.mouseClicksMiddle)
        static let keystrokes = Column(CodingKeys.keystrokes)
    }
}
