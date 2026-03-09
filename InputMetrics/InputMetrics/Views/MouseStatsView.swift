import SwiftUI
import Charts

enum TimeRange {
    case week
    case month
    case year
}

struct MouseStatsView: View {
    @State private var selectedRange: TimeRange = .week
    @State private var chartData: [DailySummary] = []
    @State private var allTimeStats: DailySummary?

    var body: some View {
        VStack(spacing: 20) {
            // Time range selector
            HStack {
                Spacer()
                Picker("Range", selection: $selectedRange) {
                    Text("Week").tag(TimeRange.week)
                    Text("Month").tag(TimeRange.month)
                    Text("Year").tag(TimeRange.year)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                .onChange(of: selectedRange) { _, _ in
                    loadChartData()
                }
            }
            .padding(.horizontal)

            // Chart
            ChartView(data: chartData, range: selectedRange)
                .frame(height: 250)
                .padding()

            // Stats and heatmap
            HStack(alignment: .top, spacing: 20) {
                // Heatmap placeholder
                VStack {
                    Text("Mouse Heatmap")
                        .font(.headline)
                    HeatmapView()
                        .frame(width: 300, height: 300)
                }

                // All-time stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("All-Time Stats")
                        .font(.headline)

                    if let stats = allTimeStats {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distance: \(DistanceConverter.formatDistance(stats.mouseDistancePx))")
                            Text("Clicks: \(stats.mouseClicksLeft + stats.mouseClicksRight + stats.mouseClicksMiddle)")
                            Text("Keystrokes: \(stats.keystrokes)")

                            Divider()

                            Text("🌍 " + DistanceConverter.formatEarthComparison(stats.mouseDistancePx))
                                .font(.caption)
                            Text("🌙 " + DistanceConverter.formatMoonComparison(stats.mouseDistancePx))
                                .font(.caption)
                        }
                    } else {
                        Text("No data yet")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .onAppear {
            loadChartData()
            loadAllTimeStats()
        }
    }

    private func loadChartData() {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let daysBack: Int
        switch selectedRange {
        case .week: daysBack = 7
        case .month: daysBack = 30
        case .year: daysBack = 365
        }

        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: today) else { return }

        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: today)

        chartData = DatabaseManager.shared.getDailySummaries(from: startString, to: endString)
    }

    private func loadAllTimeStats() {
        let allSummaries = DatabaseManager.shared.getAllDailySummaries()

        var totalDistance: Double = 0
        var totalClicksLeft: Int = 0
        var totalClicksRight: Int = 0
        var totalClicksMiddle: Int = 0
        var totalKeystrokes: Int = 0

        for summary in allSummaries {
            totalDistance += summary.mouseDistancePx
            totalClicksLeft += summary.mouseClicksLeft
            totalClicksRight += summary.mouseClicksRight
            totalClicksMiddle += summary.mouseClicksMiddle
            totalKeystrokes += summary.keystrokes
        }

        allTimeStats = DailySummary(
            date: "",
            mouseDistancePx: totalDistance,
            mouseClicksLeft: totalClicksLeft,
            mouseClicksRight: totalClicksRight,
            mouseClicksMiddle: totalClicksMiddle,
            keystrokes: totalKeystrokes
        )
    }
}

#Preview {
    MouseStatsView()
}
