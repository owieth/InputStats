import Foundation

struct GoalConfig: Codable {
    var keystrokesDaily: Int
    var distanceDaily: Double // in pixels
    var enabled: Bool

    static let `default` = GoalConfig(keystrokesDaily: 5000, distanceDaily: 4_330_000, enabled: false)
}
