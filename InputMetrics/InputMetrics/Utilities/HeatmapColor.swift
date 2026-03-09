import SwiftUI

enum HeatmapColor {
    static func forIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.clear
        } else if intensity < 0.2 {
            return Color.blue.opacity(0.3)
        } else if intensity < 0.4 {
            return Color.cyan.opacity(0.5)
        } else if intensity < 0.6 {
            return Color.green.opacity(0.7)
        } else if intensity < 0.8 {
            return Color.yellow.opacity(0.8)
        } else {
            return Color.red.opacity(0.9)
        }
    }

    static func forKeyboardIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.gray.opacity(0.15)
        } else if intensity < 0.2 {
            return Color.purple.opacity(0.25)
        } else if intensity < 0.4 {
            return Color.purple.opacity(0.45)
        } else if intensity < 0.6 {
            return Color.purple.opacity(0.65)
        } else if intensity < 0.8 {
            return Color.purple.opacity(0.8)
        } else {
            return Color.purple
        }
    }
}
