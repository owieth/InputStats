import SwiftUI

struct HeatmapView: View {
    @State private var heatmapData: [[Int]] = []
    @State private var screenIds: [String] = []
    @State private var selectedScreenId: String?

    private var maxValue: Int {
        heatmapData.flatMap { $0 }.max() ?? 1
    }

    var body: some View {
        VStack(spacing: 8) {
            if !screenIds.isEmpty {
                Picker("Screen", selection: $selectedScreenId) {
                    Text("All Screens").tag(String?.none)
                    ForEach(screenIds, id: \.self) { id in
                        Text(id).tag(String?.some(id))
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Screen filter")
                .onChange(of: selectedScreenId) { _, _ in
                    loadHeatmapData()
                }
            }

            Canvas { context, size in
                let cellWidth = size.width / CGFloat(Constants.heatmapGridSize)
                let cellHeight = size.height / CGFloat(Constants.heatmapGridSize)

                guard !heatmapData.isEmpty else { return }

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

                        let color = HeatmapColor.forIntensity(intensity)
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: 0),
                            with: .color(color)
                        )
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mouse click heatmap")
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
        }
        .onAppear {
            loadScreenIds()
            loadHeatmapData()
        }
    }

    private func loadScreenIds() {
        let today = DateHelper.todayString()
        screenIds = DatabaseManager.shared.getDistinctScreenIds(date: today)
    }

    private func loadHeatmapData() {
        let today = DateHelper.todayString()
        let entries = DatabaseManager.shared.getMouseHeatmap(date: today, screenId: selectedScreenId)
        heatmapData = HeatmapGridBuilder.buildGrid(from: entries)
    }
}

#Preview {
    HeatmapView()
        .frame(width: 300, height: 300)
        .padding()
}
