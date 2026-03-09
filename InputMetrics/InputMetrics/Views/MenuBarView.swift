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
    @State private var allTimeDistance: Double = 0
    @State private var allTimeClicks: Int = 0
    @State private var allTimeKeystrokes: Int = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum MetricTab {
        case mouse, keyboard
    }

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
            loadAllTimeStats()
        }
        .onAppear {
            updateStats()
            loadChartData()
            loadHeatmapData()
            loadKeyboardData()
            loadAllTimeStats()
        }
    }

    private var mouseMetricsView: some View {
        VStack(spacing: 16) {
            // Distance and Clicks Cards - equal width grid
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
        } else {
            mouseDistance = mouseStats.distance
            keystrokes = keyboardStats
            leftClicks = mouseStats.left
            rightClicks = mouseStats.right
            middleClicks = mouseStats.middle
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

    private func loadAllTimeStats() {
        let allSummaries = DatabaseManager.shared.getAllDailySummaries()

        var totalDistance: Double = 0
        var totalClicks: Int = 0
        var totalKeys: Int = 0

        for summary in allSummaries {
            totalDistance += summary.mouseDistancePx
            totalClicks += summary.mouseClicksLeft + summary.mouseClicksRight + summary.mouseClicksMiddle
            totalKeys += summary.keystrokes
        }

        // Add current session counters (not yet persisted)
        let mouseStats = MouseTracker.shared.getCurrentStats()
        totalDistance += mouseStats.distance
        totalClicks += mouseStats.left + mouseStats.right + mouseStats.middle
        totalKeys += KeyboardTracker.shared.getCurrentKeystrokes()

        allTimeDistance = totalDistance
        allTimeClicks = totalClicks
        allTimeKeystrokes = totalKeys
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

struct MiniKeyboardHeatmap: View {
    let entries: [KeyboardEntry]

    private var keyCountMap: [Int: Int] {
        var map: [Int: Int] = [:]
        for entry in entries {
            map[entry.keyCode, default: 0] += entry.count
        }
        return map
    }

    private var maxCount: Int {
        keyCountMap.values.max() ?? 1
    }

    // QWERTZ layout with key codes
    private let keyboardLayout: [[(keyCode: Int, label: String, width: CGFloat)]] = [
        // Number row
        [(50, "^", 1), (18, "1", 1), (19, "2", 1), (20, "3", 1), (21, "4", 1), (23, "5", 1), (22, "6", 1), (26, "7", 1), (28, "8", 1), (25, "9", 1), (29, "0", 1), (27, "ß", 1), (24, "´", 1)],
        // QWERTZ row
        [(12, "Q", 1), (13, "W", 1), (14, "E", 1), (15, "R", 1), (17, "T", 1), (16, "Z", 1), (32, "U", 1), (34, "I", 1), (31, "O", 1), (35, "P", 1), (33, "Ü", 1), (30, "+", 1)],
        // ASDF row
        [(0, "A", 1), (1, "S", 1), (2, "D", 1), (3, "F", 1), (5, "G", 1), (4, "H", 1), (38, "J", 1), (40, "K", 1), (37, "L", 1), (41, "Ö", 1), (39, "Ä", 1), (42, "#", 1)],
        // YXCV row
        [(6, "Y", 1), (7, "X", 1), (8, "C", 1), (9, "V", 1), (11, "B", 1), (45, "N", 1), (46, "M", 1), (43, ",", 1), (47, ".", 1), (44, "-", 1)],
        // Space row
        [(49, "Space", 6)]
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<keyboardLayout.count, id: \.self) { rowIndex in
                HStack(spacing: 2) {
                    ForEach(0..<keyboardLayout[rowIndex].count, id: \.self) { keyIndex in
                        let key = keyboardLayout[rowIndex][keyIndex]
                        let count = keyCountMap[key.keyCode] ?? 0
                        let intensity = Double(count) / Double(maxCount)

                        KeyCapView(
                            label: key.label,
                            count: count,
                            intensity: intensity,
                            width: key.width
                        )
                    }
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
}

struct KeyCapView: View {
    let label: String
    let count: Int
    let intensity: Double
    let width: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 6))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 28 * width, height: 28)
        .background(colorForIntensity(intensity))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func colorForIntensity(_ intensity: Double) -> Color {
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

@MainActor
class WindowManager: ObservableObject {
    static let shared = WindowManager()

    private var settingsWindow: NSWindow?
    private var dashboardWindow: NSWindow?

    private init() {}

    func openSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func openDashboardWindow() {
        if let window = dashboardWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let dashboardView = MainWindowView()
        let hostingController = NSHostingController(rootView: dashboardView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "InputMetrics Dashboard"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)

        dashboardWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

#Preview {
    MenuBarView()
}
