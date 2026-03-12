import SwiftUI
import Charts

struct AppUsageView: View {
    let entries: [AppUsageEntry]

    private var topApps: [AppUsageEntry] {
        Array(entries.prefix(10))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if topApps.isEmpty {
                Text("No app usage data yet")
                    .foregroundStyle(.secondary)
            } else {
                Chart(topApps, id: \.bundleId) { entry in
                    BarMark(
                        x: .value("Activity", entry.keystrokes + entry.mouseClicks),
                        y: .value("App", entry.appName)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: CGFloat(topApps.count * 28))
            }
        }
    }
}
