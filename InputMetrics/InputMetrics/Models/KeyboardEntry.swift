import Foundation
import GRDB

struct KeyboardEntry: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "keyboard_heatmap"

    var date: String
    var keyCode: Int
    var modifierFlags: Int
    var count: Int

    enum CodingKeys: String, CodingKey {
        case date
        case keyCode = "key_code"
        case modifierFlags = "modifier_flags"
        case count
    }

    enum Columns {
        static let date = Column(CodingKeys.date)
        static let keyCode = Column(CodingKeys.keyCode)
        static let modifierFlags = Column(CodingKeys.modifierFlags)
        static let count = Column(CodingKeys.count)
    }
}
