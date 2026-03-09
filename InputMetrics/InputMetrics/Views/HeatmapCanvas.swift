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

                    let color = HeatmapColor.forIntensity(intensity)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mouse click heatmap")
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }

}
