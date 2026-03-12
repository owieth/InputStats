import Foundation
import Observation

@Observable
@MainActor
final class MenuBarViewModel {
    enum MetricTab {
        case mouse, keyboard
    }

    var selectedTab: MetricTab = .mouse
    var mouseDistance: Double = 0
    var keystrokes: Int = 0
    var leftClicks: Int = 0
    var rightClicks: Int = 0
    var middleClicks: Int = 0
    var chartData: [DailySummary] = []
    var heatmapData: [[Int]] = []
    var keyboardEntries: [KeyboardEntry] = []
    var scrollVertical: Double = 0
    var scrollHorizontal: Double = 0
    var allTimeDistance: Double = 0
    var allTimeClicks: Int = 0
    var allTimeKeystrokes: Int = 0
    var allTimeScrollVertical: Double = 0
    var allTimeScrollHorizontal: Double = 0
    var firstActiveAt: String?
    var lastActiveAt: String?
    private var cachedTotals: DatabaseManager.AllTimeTotals = .zero
    private var lastCacheTime: Date = .distantPast
    private let cacheInterval: TimeInterval = 30

    var totalClicks: Int {
        leftClicks + rightClicks + middleClicks
    }

    var topKeys: [KeyboardEntry] {
        Array(keyboardEntries.sorted { $0.count > $1.count }.prefix(5))
    }

    func loadAll() {
        updateStats()
        loadChartData()
        loadHeatmapData()
        loadKeyboardData()
        refreshCachedTotals()
        updateAllTimeStats()
    }

    func updateStats() {
        let mouseStats = MouseTracker.shared.getCurrentStats()
        let keyboardStats = KeyboardTracker.shared.getCurrentKeystrokes()
        let today = todayString()

        let liveActivity = EventMonitor.shared.getActivityTimes()

        if let summary = DatabaseManager.shared.getDailySummary(date: today) {
            mouseDistance = summary.mouseDistancePx + mouseStats.distance
            keystrokes = summary.keystrokes + keyboardStats
            leftClicks = summary.mouseClicksLeft + mouseStats.left
            rightClicks = summary.mouseClicksRight + mouseStats.right
            middleClicks = summary.mouseClicksMiddle + mouseStats.middle
            scrollVertical = summary.scrollDistanceVertical + mouseStats.scrollV
            scrollHorizontal = summary.scrollDistanceHorizontal + mouseStats.scrollH
            firstActiveAt = summary.firstActiveAt ?? liveActivity.first
            lastActiveAt = liveActivity.last ?? summary.lastActiveAt
        } else {
            mouseDistance = mouseStats.distance
            keystrokes = keyboardStats
            leftClicks = mouseStats.left
            rightClicks = mouseStats.right
            middleClicks = mouseStats.middle
            scrollVertical = mouseStats.scrollV
            scrollHorizontal = mouseStats.scrollH
            firstActiveAt = liveActivity.first
            lastActiveAt = liveActivity.last
        }
    }

    func refreshCachedTotals() {
        cachedTotals = DatabaseManager.shared.getAllTimeTotals()
        lastCacheTime = Date()
    }

    func refreshAllTimeTotalsIfNeeded() {
        guard Date().timeIntervalSince(lastCacheTime) >= cacheInterval else { return }
        refreshCachedTotals()
    }

    func updateAllTimeStats() {
        let mouseStats = MouseTracker.shared.getCurrentStats()
        allTimeDistance = cachedTotals.distance + mouseStats.distance
        allTimeClicks = cachedTotals.totalClicks + mouseStats.left + mouseStats.right + mouseStats.middle
        allTimeKeystrokes = cachedTotals.keystrokes + KeyboardTracker.shared.getCurrentKeystrokes()
        allTimeScrollVertical = cachedTotals.scrollVertical + mouseStats.scrollV
        allTimeScrollHorizontal = cachedTotals.scrollHorizontal + mouseStats.scrollH
    }

    func loadChartData() {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let startDate = calendar.date(byAdding: .day, value: -6, to: today) else { return }

        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: today)

        chartData = DatabaseManager.shared.getDailySummaries(from: startString, to: endString)

        let todayStr = formatter.string(from: today)
        let mouseStats = MouseTracker.shared.getCurrentStats()
        let keyboardStats = KeyboardTracker.shared.getCurrentKeystrokes()

        if let idx = chartData.firstIndex(where: { $0.date == todayStr }) {
            chartData[idx].mouseDistancePx += mouseStats.distance
            chartData[idx].keystrokes += keyboardStats
            chartData[idx].mouseClicksLeft += mouseStats.left
            chartData[idx].mouseClicksRight += mouseStats.right
            chartData[idx].mouseClicksMiddle += mouseStats.middle
            chartData[idx].scrollDistanceVertical += mouseStats.scrollV
            chartData[idx].scrollDistanceHorizontal += mouseStats.scrollH
        } else {
            chartData.append(DailySummary(
                date: todayStr,
                mouseDistancePx: mouseStats.distance,
                mouseClicksLeft: mouseStats.left,
                mouseClicksRight: mouseStats.right,
                mouseClicksMiddle: mouseStats.middle,
                keystrokes: keyboardStats,
                scrollDistanceVertical: mouseStats.scrollV,
                scrollDistanceHorizontal: mouseStats.scrollH,
                firstActiveAt: nil,
                lastActiveAt: nil
            ))
        }
    }

    func loadHeatmapData() {
        let today = todayString()
        let entries = DatabaseManager.shared.getMouseHeatmap(date: today)

        var grid = Array(repeating: Array(repeating: 0, count: 50), count: 50)

        for entry in entries {
            guard entry.bucketX >= 0 && entry.bucketY >= 0 && entry.bucketX < 50 && entry.bucketY < 50 else { continue }
            grid[entry.bucketY][entry.bucketX] += entry.clickCount
        }

        heatmapData = grid
    }

    func loadKeyboardData() {
        let today = todayString()
        keyboardEntries = DatabaseManager.shared.getKeyboardEntries(date: today)
    }

    func chartDistance(_ pixels: Double, unit: DistanceUnit) -> Double {
        let meters = DistanceConverter.pixelsToMeters(pixels)
        if unit == .metric {
            return DistanceConverter.metersToKilometers(meters)
        } else {
            let feet = DistanceConverter.metersToFeet(meters)
            return DistanceConverter.feetToMiles(feet)
        }
    }

    func shortDay(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }

        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
