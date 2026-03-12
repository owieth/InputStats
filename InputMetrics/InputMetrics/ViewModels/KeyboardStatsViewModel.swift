import Foundation
import Observation

@Observable
@MainActor
final class KeyboardStatsViewModel {
    var selectedRange: TimeRange = .week
    var selectedDate: Date = Date()
    var chartData: [DailySummary] = []
    var keyboardEntries: [KeyboardEntry] = []

    var topKeys: [(id: String, name: String, count: Int)] {
        let sorted = keyboardEntries.sorted { $0.count > $1.count }
        return Array(sorted.prefix(5)).map { ($0.compositeId, KeyCodeMapping.keyName(for: $0.keyCode), $0.count) }
    }

    func loadAll() {
        loadChartData()
        loadKeyboardData()
    }

    func onRangeChanged() {
        loadChartData()
    }

    func previousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        loadAll()
    }

    func nextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if next <= Date() {
            selectedDate = next
            loadAll()
        }
    }

    func loadChartData() {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let daysBack: Int
        switch selectedRange {
        case .week: daysBack = 7
        case .month: daysBack = 30
        case .year: daysBack = 365
        }

        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: selectedDate) else { return }

        let startString = formatter.string(from: startDate)
        let endString = formatter.string(from: selectedDate)

        chartData = DatabaseManager.shared.getDailySummaries(from: startString, to: endString)

        if calendar.isDateInToday(selectedDate) {
            let todayStr = formatter.string(from: selectedDate)
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
                    scrollDistanceHorizontal: mouseStats.scrollH
                ))
            }
        }
    }

    func loadKeyboardData() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: selectedDate)

        keyboardEntries = DatabaseManager.shared.getKeyboardEntries(date: dateStr)
    }
}
