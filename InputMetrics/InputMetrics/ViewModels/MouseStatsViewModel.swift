import Foundation
import Observation

@Observable
@MainActor
final class MouseStatsViewModel {
    var selectedRange: TimeRange = .week
    var selectedDate: Date = Date()
    var chartData: [DailySummary] = []
    var allTimeStats: DailySummary?

    func loadAll() {
        loadChartData()
        loadAllTimeStats()
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

    func loadAllTimeStats() {
        let totals = DatabaseManager.shared.getAllTimeTotals()

        allTimeStats = DailySummary(
            date: "",
            mouseDistancePx: totals.distance,
            mouseClicksLeft: totals.clicksLeft,
            mouseClicksRight: totals.clicksRight,
            mouseClicksMiddle: totals.clicksMiddle,
            keystrokes: totals.keystrokes,
            scrollDistanceVertical: totals.scrollVertical,
            scrollDistanceHorizontal: totals.scrollHorizontal
        )
    }

    func formatScrollDistance(vertical: Double, horizontal: Double) -> String {
        let total = vertical + horizontal
        if total < 1000 {
            return String(format: "%.0f px", total)
        } else {
            return String(format: "%.1f K px", total / 1000)
        }
    }
}
