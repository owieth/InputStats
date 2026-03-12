import Foundation

struct Constants {
    // Distance conversion constants
    static let defaultPPI: Double = 110.0
    static let pixelsPerMeter: Double = 4330 // fallback: ~110 DPI
    static let metersPerKilometer: Double = 1000

    // Fun comparison constants
    static let earthCircumferenceMeters: Double = 40_075_000 // meters around Earth at equator
    static let moonDistanceMeters: Double = 384_400_000 // average distance to the moon

    // Imperial conversions
    static let metersPerFoot: Double = 0.3048
    static let feetPerMile: Double = 5280

    // Heatmap configuration
    static let heatmapGridSize: Int = 50
}
