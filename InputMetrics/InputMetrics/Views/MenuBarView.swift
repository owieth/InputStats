import SwiftUI
import AppKit
import Charts

struct MenuBarView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var viewModel = MenuBarViewModel()

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
            }
            .padding()

            ScrollView {
                VStack(spacing: 16) {
                    // Today's Activity Header
                    Text("Today's Activity")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if viewModel.selectedTab == .mouse {
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
            viewModel.updateStats()
            viewModel.refreshAllTimeTotalsIfNeeded()
            viewModel.updateAllTimeStats()
        }
        .onAppear {
            viewModel.loadAll()
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
                        LineMark(
                            x: .value("Day", viewModel.shortDay(from: item.date)),
                            y: .value("Distance", viewModel.chartDistance(item.mouseDistancePx, unit: preferences.distanceUnit))
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", viewModel.shortDay(from: item.date)),
                            y: .value("Distance", viewModel.chartDistance(item.mouseDistancePx, unit: preferences.distanceUnit))
                        )
                        .foregroundStyle(.blue.opacity(0.1))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", viewModel.shortDay(from: item.date)),
                            y: .value("Distance", viewModel.chartDistance(item.mouseDistancePx, unit: preferences.distanceUnit))
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(30)
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
                    if !viewModel.heatmapData.isEmpty {
                        HeatmapCanvas(data: viewModel.heatmapData)
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

                Text("\(viewModel.keystrokes)")
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

                if !viewModel.chartData.isEmpty {
                    Chart(viewModel.chartData.suffix(7), id: \.date) { item in
                        LineMark(
                            x: .value("Day", viewModel.shortDay(from: item.date)),
                            y: .value("Keystrokes", item.keystrokes)
                        )
                        .foregroundStyle(.purple)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", viewModel.shortDay(from: item.date)),
                            y: .value("Keystrokes", item.keystrokes)
                        )
                        .foregroundStyle(.purple.opacity(0.1))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", viewModel.shortDay(from: item.date)),
                            y: .value("Keystrokes", item.keystrokes)
                        )
                        .foregroundStyle(.purple)
                        .symbolSize(30)
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
                    if !viewModel.keyboardEntries.isEmpty {
                        MiniKeyboardHeatmap(entries: viewModel.keyboardEntries)
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
