import SwiftUI
import AppKit
import Charts

struct MenuBarView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var viewModel = MenuBarViewModel()
    @State private var hoveredMouseLabel: String?
    @State private var hoveredKeyboardLabel: String?
    @State private var showKeyboardWarning = false
    @State private var dataRefreshTick = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                Picker("Metric", selection: $viewModel.selectedTab) {
                    Text("Mouse Metrics").tag(MenuBarViewModel.MetricTab.mouse)
                    Text("Keyboard Metrics").tag(MenuBarViewModel.MetricTab.keyboard)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Spacer()

                Button(action: {
                    WindowManager.shared.openDashboardWindow()
                }) {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dashboard")
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    if showKeyboardWarning {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Keyboard tracking requires Input Monitoring permission")
                                    .font(.caption.bold())
                                Button("Open System Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.link)
                            }

                            Spacer()

                            Button {
                                showKeyboardWarning = false
                                preferences.dismissedKeyboardPermissionWarning = true
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Dismiss")
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Today's Activity Header
                    Text("Today's Activity")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    // Active Time Card
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.title3)
                            .foregroundStyle(.teal)

                        if let first = viewModel.firstActiveAt,
                           let last = viewModel.lastActiveAt {
                            Text("\(first) - \(last)")
                                .font(.headline.monospacedDigit())
                        } else {
                            Text("Activity tracking will begin as you use your Mac")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Active Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    if UserPreferences.shared.goalConfig.enabled {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Goals")
                                    .font(.headline)
                                Spacer()
                                if viewModel.currentStreak > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(.orange)
                                        Text("\(viewModel.currentStreak) day streak")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            VStack(spacing: 6) {
                                HStack {
                                    Image(systemName: "keyboard")
                                        .foregroundStyle(.purple)
                                    ProgressView(value: viewModel.keystrokeProgress)
                                        .tint(.purple)
                                        .accessibilityLabel("Keystroke goal progress")
                                        .accessibilityValue("\(Int(viewModel.keystrokeProgress * 100)) percent")
                                    Text("\(Int(viewModel.keystrokeProgress * 100))%")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .frame(width: 40, alignment: .trailing)
                                }

                                HStack {
                                    Image(systemName: "arrow.up.right")
                                        .foregroundStyle(.blue)
                                    ProgressView(value: viewModel.distanceProgress)
                                        .tint(.blue)
                                        .accessibilityLabel("Distance goal progress")
                                        .accessibilityValue("\(Int(viewModel.distanceProgress * 100)) percent")
                                    Text("\(Int(viewModel.distanceProgress * 100))%")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .frame(width: 40, alignment: .trailing)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if viewModel.selectedTab == .mouse {
                        mouseMetricsView
                    } else {
                        keyboardMetricsView
                    }

                    Divider()
                        .padding(.horizontal)

                    // All Time Stats
                    allTimeStatsView

                    // App Usage
                    VStack(alignment: .leading, spacing: 8) {
                        DisclosureGroup("App Usage") {
                            AppUsageView(entries: viewModel.appUsageEntries)
                                .padding(.top, 8)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(width: 420, height: 600)
        .onReceive(timer) { _ in
            viewModel.updateStats()
            viewModel.refreshAllTimeTotalsIfNeeded()
            viewModel.updateAllTimeStats()
            updateKeyboardWarning()
            viewModel.loadChartData()
            dataRefreshTick += 1
            if dataRefreshTick % 10 == 0 {
                viewModel.loadHeatmapData()
                viewModel.loadKeyboardData()
                viewModel.loadHourlySummaries()
                viewModel.loadAppUsage()
            }
        }
        .onAppear {
            viewModel.loadAll()
            updateKeyboardWarning()
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

                    Text(DistanceConverter.formatDistance(viewModel.mouseDistance, unit: preferences.distanceUnit))
                        .font(.title.bold())

                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Distance: \(DistanceConverter.formatDistance(viewModel.mouseDistance, unit: preferences.distanceUnit))")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Clicks Card
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "cursorarrow.click")
                        .font(.title2)
                        .foregroundStyle(.green)

                    Text("\(viewModel.totalClicks)")
                        .font(.title.bold())

                    Text("Clicks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Clicks: \(viewModel.totalClicks)")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Scroll Card
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "scroll")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    let totalScroll = viewModel.scrollVertical + viewModel.scrollHorizontal
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Scroll: \(String(format: "%.0f pixels", viewModel.scrollVertical + viewModel.scrollHorizontal))")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                // Active Time Card
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundStyle(.teal)

                    let hours = viewModel.activeMinutes / 60
                    let mins = viewModel.activeMinutes % 60
                    Text(hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m")
                        .font(.title.bold())

                    Text("Active Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Active time: \(viewModel.activeMinutes / 60) hours \(viewModel.activeMinutes % 60) minutes")
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

                if !viewModel.chartData.isEmpty {
                    Chart(viewModel.chartData.suffix(7), id: \.date) { item in
                        let label = viewModel.shortDay(from: item.date)
                        let distance = viewModel.chartDistance(item.mouseDistancePx, unit: preferences.distanceUnit)

                        LineMark(
                            x: .value("Day", label),
                            y: .value("Distance", distance)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", label),
                            y: .value("Distance", distance)
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", label),
                            y: .value("Distance", distance)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(30)

                        if hoveredMouseLabel == label {
                            RuleMark(x: .value("Day", label))
                                .foregroundStyle(Color.secondary.opacity(0.3))
                                .annotation(position: .top, spacing: 4) {
                                    let unit = preferences.distanceUnit == .metric ? "km" : "mi"
                                    Text(String(format: "%.2f %@", distance, unit))
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(4)
                                }
                        }
                    }
                    .frame(height: 150)
                    .chartYAxisLabel(preferences.distanceUnit == .metric ? "km" : "mi")
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
                                            hoveredMouseLabel = label
                                        }
                                    case .ended:
                                        hoveredMouseLabel = nil
                                    }
                                }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Weekly mouse distance chart")
                    .padding(.horizontal)
                } else {
                    Text("Use your Mac for a few days to see trends")
                        .foregroundStyle(.secondary)
                        .frame(height: 150)
                }
            }

            // Mouse Heatmap
            VStack(alignment: .leading, spacing: 8) {
                DisclosureGroup("Mouse Heatmap") {
                    if viewModel.hasHeatmapData {
                        HeatmapCanvas(data: viewModel.heatmapData)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Mouse click heatmap showing click distribution")
                            .frame(height: 200)
                            .padding(.top, 8)
                    } else {
                        Text("Move your mouse to see the heatmap")
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

                Text("\(viewModel.keystrokes)")
                    .font(.title.bold())

                Text("Keystrokes Today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Keystrokes today: \(viewModel.keystrokes)")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)

            // Peak Typing Speed Card
            if viewModel.peakWPM > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "gauge.with.needle")
                        .font(.title2)
                        .foregroundStyle(.orange)

                    Text(String(format: "%.0f WPM", viewModel.peakWPM))
                        .font(.title.bold())

                    Text("Peak Typing Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Peak typing speed: \(String(format: "%.0f", viewModel.peakWPM)) words per minute")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Week Overview Chart
            VStack(alignment: .leading, spacing: 8) {
                Text("Week Overview")
                    .font(.headline)
                    .padding(.horizontal)

                if !viewModel.chartData.isEmpty {
                    Chart(viewModel.chartData.suffix(7), id: \.date) { item in
                        let label = viewModel.shortDay(from: item.date)
                        let count = item.keystrokes

                        LineMark(
                            x: .value("Day", label),
                            y: .value("Keystrokes", count)
                        )
                        .foregroundStyle(.purple)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", label),
                            y: .value("Keystrokes", count)
                        )
                        .foregroundStyle(.purple.opacity(0.1))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", label),
                            y: .value("Keystrokes", count)
                        )
                        .foregroundStyle(.purple)
                        .symbolSize(30)

                        if hoveredKeyboardLabel == label {
                            RuleMark(x: .value("Day", label))
                                .foregroundStyle(Color.secondary.opacity(0.3))
                                .annotation(position: .top, spacing: 4) {
                                    Text("\(count)")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(nsColor: .controlBackgroundColor))
                                        .cornerRadius(4)
                                }
                        }
                    }
                    .frame(height: 150)
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
                                            hoveredKeyboardLabel = label
                                        }
                                    case .ended:
                                        hoveredKeyboardLabel = nil
                                    }
                                }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Weekly keystrokes chart")
                    .padding(.horizontal)
                } else {
                    Text("Use your Mac for a few days to see trends")
                        .foregroundStyle(.secondary)
                        .frame(height: 150)
                }
            }

            // Keyboard Heatmap
            VStack(alignment: .leading, spacing: 8) {
                DisclosureGroup("Keyboard Heatmap") {
                    if !viewModel.keyboardEntries.isEmpty {
                        MiniKeyboardHeatmap(entries: viewModel.keyboardEntries)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Keyboard heatmap showing key usage frequency")
                            .frame(height: 150)
                            .padding(.top, 8)
                    } else {
                        Text("Start typing to see your keyboard heatmap")
                            .foregroundStyle(.secondary)
                            .frame(height: 100)
                    }
                }
                .padding(.horizontal)
            }

            // Hourly Breakdown
            VStack(alignment: .leading, spacing: 8) {
                DisclosureGroup("Hourly Breakdown") {
                    HourlyBreakdownView(hourlySummaries: viewModel.hourlySummaries)
                        .padding(.top, 8)
                }
                .padding(.horizontal)
            }

            // Top Keys
            VStack(alignment: .leading, spacing: 8) {
                Text("Most Used Keys")
                    .font(.headline)
                    .padding(.horizontal)

                if !viewModel.keyboardEntries.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(viewModel.topKeys, id: \.compositeId) { entry in
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

    private func updateKeyboardWarning() {
        let missing = EventMonitor.shared.isKeyboardPermissionLikelyMissing
        let dismissed = preferences.dismissedKeyboardPermissionWarning
        showKeyboardWarning = missing && !dismissed

        if !missing && preferences.dismissedKeyboardPermissionWarning {
            preferences.dismissedKeyboardPermissionWarning = false
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

                    Text(DistanceConverter.formatDistance(viewModel.allTimeDistance, unit: preferences.distanceUnit))
                        .font(.title2.bold().monospacedDigit())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("All-time distance: \(DistanceConverter.formatDistance(viewModel.allTimeDistance, unit: preferences.distanceUnit))")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                // Total Clicks
                VStack(alignment: .leading, spacing: 4) {
                    Label("Clicks", systemImage: "cursorarrow.click")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(viewModel.allTimeClicks)")
                        .font(.title2.bold().monospacedDigit())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("All-time clicks: \(viewModel.allTimeClicks)")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)

                // Total Keystrokes
                VStack(alignment: .leading, spacing: 4) {
                    Label("Keystrokes", systemImage: "keyboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(viewModel.allTimeKeystrokes)")
                        .font(.title2.bold().monospacedDigit())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("All-time keystrokes: \(viewModel.allTimeKeystrokes)")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)

                // Total Scroll
                VStack(alignment: .leading, spacing: 4) {
                    Label("Scroll", systemImage: "scroll")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let totalScroll = viewModel.allTimeScrollVertical + viewModel.allTimeScrollHorizontal
                    if totalScroll < 1000 {
                        Text(String(format: "%.0f px", totalScroll))
                            .font(.title2.bold().monospacedDigit())
                    } else {
                        Text(String(format: "%.1f K px", totalScroll / 1000))
                            .font(.title2.bold().monospacedDigit())
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("All-time scroll: \(String(format: "%.0f pixels", viewModel.allTimeScrollVertical + viewModel.allTimeScrollHorizontal))")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    MenuBarView()
}
