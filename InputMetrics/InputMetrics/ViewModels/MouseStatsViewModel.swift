import Foundation
import Observation

@Observable
@MainActor
final class MouseStatsViewModel {
    var selectedRange: TimeRange = .week
    var chartData: [DailySummary] = []
    var allTimeStats: DailySummary?

    func loadAll() {
        loadChartData()
        loadAllTimeStats()
    }

    func onRangeChanged() {
        loadChartData()
    }

    func loadChartData() {
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
