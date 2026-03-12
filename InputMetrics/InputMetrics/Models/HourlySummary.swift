import GRDB

struct HourlySummary: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "hourly_summary"

    var date: String
    var hour: Int
    var mouseDistancePx: Double
    var mouseClicks: Int
    var keystrokes: Int

    enum CodingKeys: String, CodingKey {
        case date
        case hour
        case mouseDistancePx = "mouse_distance_px"
        case mouseClicks = "mouse_clicks"
        case keystrokes
    }

    enum Columns {
        static let date = Column(CodingKeys.date)
        static let hour = Column(CodingKeys.hour)
        static let mouseDistancePx = Column(CodingKeys.mouseDistancePx)
        static let mouseClicks = Column(CodingKeys.mouseClicks)
        static let keystrokes = Column(CodingKeys.keystrokes)
    }
}
