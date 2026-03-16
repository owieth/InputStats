import SwiftUI
import Charts

struct KeyboardStatsView: View {
    @State private var viewModel = KeyboardStatsViewModel()

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
            ChartView(data: viewModel.chartData, range: viewModel.selectedRange, metric: .keystrokes)
                .frame(height: 250)
                .padding()

            // Keyboard heatmap
            KeyboardHeatmapView(entries: viewModel.keyboardEntries)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Keyboard heatmap showing key usage frequency")
                .padding()

            // Top keys
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Keys Today:")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(viewModel.topKeys, id: \.id) { entry in
                        Text("\(entry.name) (\(entry.count))")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            viewModel.loadAll()
        }
    }
}

#Preview {
    KeyboardStatsView()
}
