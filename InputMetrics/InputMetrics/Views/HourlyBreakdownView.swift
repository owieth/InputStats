import SwiftUI
import Charts

struct HourlyBreakdownView: View {
    let hourlySummaries: [HourlySummary]

    private var chartEntries: [(hour: Int, keystrokes: Int, clicks: Int)] {
        (0..<24).map { hour in
            let summary = hourlySummaries.first { $0.hour == hour }
            return (hour: hour, keystrokes: summary?.keystrokes ?? 0, clicks: summary?.mouseClicks ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hourlySummaries.isEmpty {
                Text("No hourly data yet")
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
            } else {
                Chart(chartEntries, id: \.hour) { entry in
                    BarMark(
                        x: .value("Hour", entry.hour),
                        y: .value("Keystrokes", entry.keystrokes)
                    )
                    .foregroundStyle(.purple.opacity(0.7))

                    BarMark(
                        x: .value("Hour", entry.hour),
                        y: .value("Clicks", entry.clicks)
                    )
                    .foregroundStyle(.blue.opacity(0.7))
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text("\(hour)h")
                            }
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Hourly breakdown chart showing keystrokes and clicks by hour")
                .frame(height: 120)
            }
        }
    }
}
