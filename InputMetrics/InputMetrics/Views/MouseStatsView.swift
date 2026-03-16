import SwiftUI
import Charts

struct MouseStatsView: View {
    @State private var viewModel = MouseStatsViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Date navigation
            HStack {
                Button(action: { viewModel.previousDay() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous day")

                DatePicker("", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: viewModel.selectedDate) { _, _ in
                        viewModel.loadAll()
                    }

                Button(action: { viewModel.nextDay() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next day")
                .disabled(Calendar.current.isDateInToday(viewModel.selectedDate))

                if !Calendar.current.isDateInToday(viewModel.selectedDate) {
                    Button("Today") {
                        viewModel.selectedDate = Date()
                        viewModel.loadAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            // Time range selector
            HStack {
                Spacer()
                Picker("Range", selection: $viewModel.selectedRange) {
                    Text("Week").tag(TimeRange.week)
                    Text("Month").tag(TimeRange.month)
                    Text("Year").tag(TimeRange.year)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                .onChange(of: viewModel.selectedRange) { _, _ in
                    viewModel.onRangeChanged()
                }
            }
            .padding(.horizontal)

            // Chart
            ChartView(data: viewModel.chartData, range: viewModel.selectedRange)
                .frame(height: 250)
                .padding()

            // Stats and heatmap
            HStack(alignment: .top, spacing: 20) {
                // Heatmap placeholder
                VStack {
                    Text("Mouse Heatmap")
                        .font(.headline)
                    HeatmapView()
                        .frame(width: 300, height: 300)
                }

                // All-time stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("All-Time Stats")
                        .font(.headline)

                    if let stats = viewModel.allTimeStats {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distance: \(DistanceConverter.formatDistance(stats.mouseDistancePx))")
                            Text("Clicks: \(stats.mouseClicksLeft + stats.mouseClicksRight + stats.mouseClicksMiddle)")
                            Text("Scroll: \(viewModel.formatScrollDistance(vertical: stats.scrollDistanceVertical, horizontal: stats.scrollDistanceHorizontal))")
                            Text("Keystrokes: \(stats.keystrokes)")

                            Divider()

                            Text("\u{1F30D} " + DistanceConverter.formatEarthComparison(stats.mouseDistancePx))
                                .font(.caption)
                            Text("\u{1F319} " + DistanceConverter.formatMoonComparison(stats.mouseDistancePx))
                                .font(.caption)
                        }
                    } else {
                        Text("No data yet")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .onAppear {
            viewModel.loadAll()
        }
    }
}

#Preview {
    MouseStatsView()
}
