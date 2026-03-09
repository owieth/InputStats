import Foundation

enum DistanceUnit: String {
    case metric
    case imperial
}

struct DistanceConverter {
    static func pixelsToMeters(_ pixels: Double) -> Double {
        return pixels / Constants.pixelsPerMeter
    }

    static func metersToKilometers(_ meters: Double) -> Double {
        return meters / Constants.metersPerKilometer
    }

    static func metersToFeet(_ meters: Double) -> Double {
        return meters / Constants.metersPerFoot
    }

    static func feetToMiles(_ feet: Double) -> Double {
        return feet / Constants.feetPerMile
    }

    static func formatDistance(_ pixels: Double, unit: DistanceUnit = .metric) -> String {
        let meters = pixelsToMeters(pixels)

        switch unit {
        case .metric:
            if meters < 1000 {
                return String(format: "%.1f m", meters)
            } else {
                let km = metersToKilometers(meters)
                return String(format: "%.2f km", km)
            }
        case .imperial:
            let feet = metersToFeet(meters)
            if feet < Constants.feetPerMile {
                return String(format: "%.1f ft", feet)
            } else {
                let miles = feetToMiles(feet)
                return String(format: "%.2f mi", miles)
            }
        }
    }

    static func percentAroundEarth(_ pixels: Double) -> Double {
        let meters = pixelsToMeters(pixels)
        return (meters / Constants.earthCircumferenceMeters) * 100
    }

    static func percentToMoon(_ pixels: Double) -> Double {
        let meters = pixelsToMeters(pixels)
        return (meters / Constants.moonDistanceMeters) * 100
    }

    static func formatEarthComparison(_ pixels: Double) -> String {
        let percent = percentAroundEarth(pixels)
        return String(format: "%.5f%% around the world", percent)
    }

    static func formatMoonComparison(_ pixels: Double) -> String {
        let percent = percentToMoon(pixels)
        return String(format: "%.6f%% to the moon", percent)
    }
}
