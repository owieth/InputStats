import SwiftUI

enum HeatmapColor {
    private struct RGB {
        let r: Double
        let g: Double
        let b: Double

        func interpolated(to other: RGB, t: Double) -> RGB {
            RGB(
                r: r + (other.r - r) * t,
                g: g + (other.g - g) * t,
                b: b + (other.b - b) * t
            )
        }

        var color: Color {
            Color(red: r, green: g, blue: b)
        }
    }

    private static let viridisStops: [(position: Double, color: RGB)] = [
        (0.00, RGB(r: 0x44 / 255.0, g: 0x01 / 255.0, b: 0x54 / 255.0)),
        (0.25, RGB(r: 0x31 / 255.0, g: 0x68 / 255.0, b: 0x8E / 255.0)),
        (0.50, RGB(r: 0x21 / 255.0, g: 0x91 / 255.0, b: 0x8C / 255.0)),
        (0.75, RGB(r: 0x5E / 255.0, g: 0xC9 / 255.0, b: 0x62 / 255.0)),
        (1.00, RGB(r: 0xFD / 255.0, g: 0xE7 / 255.0, b: 0x25 / 255.0)),
    ]

    private static func viridisColor(for intensity: Double) -> Color {
        let clamped = min(max(intensity, 0), 1)

        for i in 0 ..< viridisStops.count - 1 {
            let lower = viridisStops[i]
            let upper = viridisStops[i + 1]

            if clamped >= lower.position && clamped <= upper.position {
                let t = (clamped - lower.position) / (upper.position - lower.position)
                return lower.color.interpolated(to: upper.color, t: t).color
            }
        }

        return viridisStops.last!.color.color
    }

    static func forIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.clear
        }
        return viridisColor(for: intensity)
    }

    static func forKeyboardIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.gray.opacity(0.15)
        }
        return viridisColor(for: intensity)
    }
}
