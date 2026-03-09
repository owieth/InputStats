import SwiftUI

struct HeatmapCanvas: View {
    let data: [[Int]]

    private var maxValue: Int {
        data.flatMap { $0 }.max() ?? 1
    }

    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / 50
            let cellHeight = size.height / 50

            for y in 0..<50 {
                for x in 0..<50 {
                    let value = data[y][x]
                    let intensity = Double(value) / Double(maxValue)

                    let rect = CGRect(
                        x: CGFloat(x) * cellWidth,
                        y: CGFloat(y) * cellHeight,
                        width: cellWidth,
                        height: cellHeight
                    )

                    let color = colorForIntensity(intensity)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mouse click heatmap")
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }

    private func colorForIntensity(_ intensity: Double) -> Color {
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
}
