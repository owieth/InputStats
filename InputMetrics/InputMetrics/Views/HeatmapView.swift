import SwiftUI

struct HeatmapView: View {
    @State private var heatmapData: [[Int]] = []

    var body: some View {
        Canvas { context, size in
            let cellWidth = size.width / CGFloat(Constants.heatmapGridSize)
            let cellHeight = size.height / CGFloat(Constants.heatmapGridSize)

            guard !heatmapData.isEmpty else { return }

            // Find max value for normalization
            let maxValue = heatmapData.flatMap { $0 }.max() ?? 1

            for y in 0..<Constants.heatmapGridSize {
                for x in 0..<Constants.heatmapGridSize {
                    let value = heatmapData[y][x]
                    let intensity = Double(value) / Double(maxValue)

                    let rect = CGRect(
                        x: CGFloat(x) * cellWidth,
                        y: CGFloat(y) * cellHeight,
                        width: cellWidth,
                        height: cellHeight
                    )

                    let color = colorForIntensity(intensity)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 0),
                        with: .color(color)
                    )
                }
            }
        }
        .background(Color.black.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            loadHeatmapData()
        }
    }

    private func loadHeatmapData() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        let entries = DatabaseManager.shared.getMouseHeatmap(date: today)

        // Initialize 50x50 grid with zeros
        var grid = Array(repeating: Array(repeating: 0, count: Constants.heatmapGridSize), count: Constants.heatmapGridSize)

        // Fill in the click counts
        for entry in entries {
            guard entry.bucketX >= 0 && entry.bucketY >= 0 && entry.bucketX < Constants.heatmapGridSize && entry.bucketY < Constants.heatmapGridSize else { continue }
            grid[entry.bucketY][entry.bucketX] += entry.clickCount
        }

        heatmapData = grid
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

#Preview {
    HeatmapView()
        .frame(width: 300, height: 300)
        .padding()
}
