import SwiftUI
import AppKit
import Charts

struct MenuBarView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var selectedTab: MetricTab = .mouse
    @State private var mouseDistance: Double = 0
    @State private var keystrokes: Int = 0
    @State private var leftClicks: Int = 0
    @State private var rightClicks: Int = 0
    @State private var middleClicks: Int = 0
    @State private var chartData: [DailySummary] = []
    @State private var heatmapData: [[Int]] = []
    @State private var keyboardEntries: [KeyboardEntry] = []
    @State private var scrollVertical: Double = 0
    @State private var scrollHorizontal: Double = 0
    @State private var allTimeDistance: Double = 0
    @State private var allTimeClicks: Int = 0
    @State private var allTimeKeystrokes: Int = 0
    @State private var allTimeScrollVertical: Double = 0
    @State private var allTimeScrollHorizontal: Double = 0
    @State private var cachedTotals: DatabaseManager.AllTimeTotals = .zero
    @State private var lastCacheTime: Date = .distantPast

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let cacheInterval: TimeInterval = 30

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    WindowManager.shared.openSettingsWindow()
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")

                Spacer()

                Picker("Metric", selection: $selectedTab) {
                    Text("Mouse Metrics").tag(MetricTab.mouse)
                    Text("Keyboard Metrics").tag(MetricTab.keyboard)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    // Today's Activity Header
                    Text("Today's Activity")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if selectedTab == .mouse {
                        mouseMetricsView
                    } else {
                        keyboardMetricsView
                    }

                    Divider()
                        .padding(.horizontal)

                    // All Time Stats
                    allTimeStatsView
                }
                .padding(.vertical)
            }
        }
        .frame(width: 420, height: 600)
        .onReceive(timer) { _ in
            updateStats()
            refreshAllTimeTotalsIfNeeded()
            updateAllTimeStats()
        }
        .onAppear {
            updateStats()
            loadChartData()
            loadHeatmapData()
            loadKeyboardData()
            refreshCachedTotals()
            updateAllTimeStats()
        }
    }

    private var mouseMetricsView: some View {
        VStack(spacing: 16) {
            // Distance, Clicks, and Scroll Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Distance Card
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "arrow.up.right")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    Text(DistanceConverter.formatDistance(mouseDistance, unit: preferences.distanceUnit))
                        .font(.title.bold())

                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Clicks Card
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "cursorarrow.click")
                        .font(.title2)
                        .foregroundStyle(.green)

                    Text("\(leftClicks + rightClicks + middleClicks)")
                        .font(.title.bold())

                    Text("Clicks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Scroll Card
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "scroll")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    let totalScroll = scrollVertical + scrollHorizontal
                    if totalScroll < 1000 {
                        Text(String(format: "%.0f px", totalScroll))
                            .font(.title.bold())
                    } else {
                        Text(String(format: "%.1f K", totalScroll / 1000))
                            .font(.title.bold())
                    }

                    Text("Scroll")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)

            // Week Overview Chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Week Overview")
                    .font(.headline)
                    .padding(.horizontal)

                if !chartData.isEmpty {
                    Chart(chartData.suffix(7), id: \.date) { item in
                        BarMark(
                            x: .value("Day", shortDay(from: item.date)),
                            y: .value("Distance", chartDistance(item.mouseDistancePx))
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                    .frame(height: 150)
                    .chartYAxisLabel(preferences.distanceUnit == .metric ? "km" : "mi")
                    .padding(.horizontal)
                } else {
                    Text("No data yet")
                        .foregroundStyle(.secondary)
                        .frame(height: 150)
                }
            }

            // Mouse Heatmap
            VStack(alignment: .leading, spacing: 8) {
                DisclosureGroup("Mouse Heatmap") {
                    if !heatmapData.isEmpty {
                        HeatmapCanvas(data: heatmapData)
                            .frame(height: 200)
                            .padding(.top, 8)
                    } else {
                        Text("No heatmap data yet")
                            .foregroundStyle(.secondary)
                            .frame(height: 100)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var keyboardMetricsView: some View {
        VStack(spacing: 16) {
            // Keystrokes Card
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.purple)

                Text("\(keystrokes)")
                    .font(.title.bold())

                Text("Keystrokes Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            // Week Overview Chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Week Overview")
                    .font(.headline)
                    .padding(.horizontal)

                if !chartData.isEmpty {
                    Chart(chartData.suffix(7), id: \.date) { item in
                        BarMark(
                            x: .value("Day", shortDay(from: item.date)),
                            y: .value("Keystrokes", item.keystrokes)
                        )
                        .foregroundStyle(.purple.gradient)
                    }
                    .frame(height: 150)
                    .padding(.horizontal)
                } else {
                    Text("No data yet")
                        .foregroundStyle(.secondary)
                        .frame(height: 150)
                }
            }

            // Keyboard Heatmap
            VStack(alignment: .leading, spacing: 8) {
                DisclosureGroup("Keyboard Heatmap") {
                    if !keyboardEntries.isEmpty {
                        MiniKeyboardHeatmap(entries: keyboardEntries)
                            .frame(height: 150)
                            .padding(.top, 8)
                    } else {
                        Text("No keyboard data yet")
                            .foregroundStyle(.secondary)
                            .frame(height: 100)
                    }
                }
                .padding(.horizontal)
            }

            // Top Keys
            VStack(alignment: .leading, spacing: 8) {
                Text("Most Used Keys")
                    .font(.headline)
                    .padding(.horizontal)

                if !keyboardEntries.isEmpty {
                    let topKeys = keyboardEntries.sorted { $0.count > $1.count }.prefix(5)
                    HStack(spacing: 8) {
                        ForEach(Array(topKeys), id: \.compositeId) { entry in
                            VStack(spacing: 4) {
                                Text(KeyCodeMapping.keyName(for: entry.keyCode))
                                    .font(.caption.bold())
                                Text("\(entry.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Text("Type to see your most used keys")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
    }

    private var allTimeStatsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Time")
                .font(.title3.bold())
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Total Distance
                VStack(alignment: .leading, spacing: 4) {
                    Label("Distance", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(DistanceConverter.formatDistance(allTimeDistance, unit: preferences.distanceUnit))
                        .font(.title2.bold().monospacedDigit())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // Total Clicks
                VStack(alignment: .leading, spacing: 4) {
                    Label("Clicks", systemImage: "cursorarrow.click")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(allTimeClicks)")
                        .font(.title2.bold().monospacedDigit())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                // Total Keystrokes
                VStack(alignment: .leading, spacing: 4) {
                    Label("Keystrokes", systemImage: "keyboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(allTimeKeystrokes)")
                        .font(.title2.bold().monospacedDigit())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)

                // Total Scroll
                VStack(alignment: .leading, spacing: 4) {
                    Label("Scroll", systemImage: "scroll")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let totalScroll = allTimeScrollVertical + allTimeScrollHorizontal
                    if totalScroll < 1000 {
                        Text(String(format: "%.0f px", totalScroll))
                            .font(.title2.bold().monospacedDigit())
                    } else {
                        Text(String(format: "%.1f K px", totalScroll / 1000))
                            .font(.title2.bold().monospacedDigit())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }

    private func updateStats() {
        let mouseStats = MouseTracker.shared.getCurrentStats()
        let keyboardStats = KeyboardTracker.shared.getCurrentKeystrokes()

        let today = getTodayString()
        if let summary = DatabaseManager.shared.getDailySummary(date: today) {
            mouseDistance = summary.mouseDistancePx + mouseStats.distance
            keystrokes = summary.keystrokes + keyboardStats
            leftClicks = summary.mouseClicksLeft + mouseStats.left
            rightClicks = summary.mouseClicksRight + mouseStats.right
            middleClicks = summary.mouseClicksMiddle + mouseStats.middle
            scrollVertical = summary.scrollDistanceVertical + mouseStats.scrollV
            scrollHorizontal = summary.scrollDistanceHorizontal + mouseStats.scrollH
        } else {
            mouseDistance = mouseStats.distance
            keystrokes = keyboardStats
            leftClicks = mouseStats.left
            rightClicks = mouseStats.right
            middleClicks = mouseStats.middle
            scrollVertical = mouseStats.scrollV
            scrollHorizontal = mouseStats.scrollH
        }
    }

    private func loadChartData() {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let startDate = calendar.date(byAdding: .day, value: -6, to: today) else { return }

        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: today)

        chartData = DatabaseManager.shared.getDailySummaries(from: startString, to: endString)
    }

    private func loadHeatmapData() {
        let today = getTodayString()
        let entries = DatabaseManager.shared.getMouseHeatmap(date: today)

        var grid = Array(repeating: Array(repeating: 0, count: 50), count: 50)

        for entry in entries {
            guard entry.bucketX >= 0 && entry.bucketY >= 0 && entry.bucketX < 50 && entry.bucketY < 50 else { continue }
            grid[entry.bucketY][entry.bucketX] += entry.clickCount
        }

        heatmapData = grid
    }

    private func loadKeyboardData() {
        let today = getTodayString()
        keyboardEntries = DatabaseManager.shared.getKeyboardEntries(date: today)
    }

    private func refreshCachedTotals() {
        cachedTotals = DatabaseManager.shared.getAllTimeTotals()
        lastCacheTime = Date()
    }

    private func refreshAllTimeTotalsIfNeeded() {
        guard Date().timeIntervalSince(lastCacheTime) >= cacheInterval else { return }
        refreshCachedTotals()
    }

    private func updateAllTimeStats() {
        let mouseStats = MouseTracker.shared.getCurrentStats()
        allTimeDistance = cachedTotals.distance + mouseStats.distance
        allTimeClicks = cachedTotals.totalClicks + mouseStats.left + mouseStats.right + mouseStats.middle
        allTimeKeystrokes = cachedTotals.keystrokes + KeyboardTracker.shared.getCurrentKeystrokes()
        allTimeScrollVertical = cachedTotals.scrollVertical + mouseStats.scrollV
        allTimeScrollHorizontal = cachedTotals.scrollHorizontal + mouseStats.scrollH
    }

    private func chartDistance(_ pixels: Double) -> Double {
        let meters = DistanceConverter.pixelsToMeters(pixels)
        if preferences.distanceUnit == .metric {
            return DistanceConverter.metersToKilometers(meters)
        } else {
            let feet = DistanceConverter.metersToFeet(meters)
            return DistanceConverter.feetToMiles(feet)
        }
    }

    private func shortDay(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }

        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

#Preview {
    MenuBarView()
}
