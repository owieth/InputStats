import SwiftUI
import Charts

struct KeyboardStatsView: View {
    @State private var selectedRange: TimeRange = .week
    @State private var chartData: [DailySummary] = []
    @State private var keyboardEntries: [KeyboardEntry] = []

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
            ChartView(data: chartData, range: selectedRange, metric: .keystrokes)
                .frame(height: 250)
                .padding()

            // Keyboard heatmap
            KeyboardHeatmapView(entries: keyboardEntries)
                .padding()

            // Top keys
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Keys Today:")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(topKeys(), id: \.0) { key, count in
                        Text("\(key) (\(count))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            loadChartData()
            loadKeyboardData()
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

    private func loadKeyboardData() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        keyboardEntries = DatabaseManager.shared.getKeyboardEntries(date: today)
    }

    private func topKeys() -> [(String, Int)] {
        let sorted = keyboardEntries.sorted { $0.count > $1.count }
        return Array(sorted.prefix(5)).map { (KeyCodeMapping.keyName(for: $0.keyCode), $0.count) }
    }
}

#Preview {
    KeyboardStatsView()
}
