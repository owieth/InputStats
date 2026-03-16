import SwiftUI
import Charts

enum ChartMetric {
    case distance
    case keystrokes
}

struct ChartView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    let data: [DailySummary]
    let range: TimeRange
    var metric: ChartMetric = .distance

    @State private var hoveredLabel: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(chartTitle)
                .font(.headline)
                .padding(.bottom, 4)

            if data.isEmpty {
                Text("No data available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(data, id: \.date) { item in
                    let label = formatLabel(from: item.date)
                    let value = metricValue(for: item)

                    LineMark(
                        x: .value("Date", label),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", label),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(Color.blue.opacity(0.1))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", label),
                        y: .value("Value", value)
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(30)

                    if hoveredLabel == label {
                        RuleMark(x: .value("Date", label))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .annotation(position: .top, spacing: 4) {
                                Text(formattedTooltip(value: value))
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .cornerRadius(4)
                            }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(chartTitle) chart for \(range == .week ? "this week" : range == .month ? "this month" : "this year")")
                .chartYAxisLabel(yAxisLabel)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    let origin = geometry[proxy.plotFrame!].origin
                                    let x = location.x - origin.x
                                    if let label: String = proxy.value(atX: x) {
                                        hoveredLabel = label
                                    }
                                case .ended:
                                    hoveredLabel = nil
                                }
                            }
                    }
                }
            }
        }
    }

    private var chartTitle: String {
        switch metric {
        case .distance:
            return "Mouse Distance"
        case .keystrokes:
            return "Keystrokes"
        }
    }

    private var yAxisLabel: String {
        switch metric {
        case .distance:
            return preferences.distanceUnit == .metric ? "Distance (km)" : "Distance (mi)"
        case .keystrokes:
            return "Keystrokes"
        }
    }

    private func formatLabel(from dateString: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return dateString }

        let display = DateFormatter()
        switch range {
        case .week:
            display.dateFormat = "EEE"
        case .month:
            display.dateFormat = "d"
        case .year:
            display.dateFormat = "MMM d"
        }
        return display.string(from: date)
    }

    private func formattedTooltip(value: Double) -> String {
        switch metric {
        case .distance:
            let unit = preferences.distanceUnit == .metric ? "km" : "mi"
            return String(format: "%.2f %@", value, unit)
        case .keystrokes:
            return "\(Int(value))"
        }
    }

    private func metricValue(for item: DailySummary) -> Double {
        switch metric {
        case .distance:
            let meters = DistanceConverter.pixelsToMeters(item.mouseDistancePx)
            if preferences.distanceUnit == .metric {
                return DistanceConverter.metersToKilometers(meters)
            } else {
                return DistanceConverter.feetToMiles(DistanceConverter.metersToFeet(meters))
            }
        case .keystrokes:
            return Double(item.keystrokes)
        }
    }
}

#Preview {
    ChartView(
        data: [
            DailySummary(date: "2025-01-10", mouseDistancePx: 5000000, mouseClicksLeft: 100, mouseClicksRight: 20, mouseClicksMiddle: 5, keystrokes: 2000, scrollDistanceVertical: 0, scrollDistanceHorizontal: 0),
            DailySummary(date: "2025-01-11", mouseDistancePx: 7000000, mouseClicksLeft: 150, mouseClicksRight: 30, mouseClicksMiddle: 8, keystrokes: 3000, scrollDistanceVertical: 0, scrollDistanceHorizontal: 0),
            DailySummary(date: "2025-01-12", mouseDistancePx: 4000000, mouseClicksLeft: 80, mouseClicksRight: 15, mouseClicksMiddle: 3, keystrokes: 1500, scrollDistanceVertical: 0, scrollDistanceHorizontal: 0)
        ],
        range: .week
    )
    .frame(height: 250)
    .padding()
}
