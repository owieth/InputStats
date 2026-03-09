import SwiftUI
import LaunchAtLogin

enum ExportResult {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let msg), .failure(let msg): return msg
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .failure: return .red
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var preferences = UserPreferences.shared
    @State private var showResetConfirmation = false
    @State private var exportResult: ExportResult?
    @State private var showExportToast = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)

                        Text("Settings")
                            .font(.title.bold())

                        Text("Customize your InputMetrics experience")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    // General Section
                    SettingsSectionView(title: "General", icon: "slider.horizontal.3") {
                        VStack(spacing: 0) {
                            SettingsRowView {
                                HStack {
                                    Label("Launch at login", systemImage: "power")
                                        .font(.body)

                                    Spacer()

                                    LaunchAtLogin.Toggle {
                                        EmptyView()
                                    }
                                    .labelsHidden()
                                }
                            }

                            SettingsRowView {
                                HStack {
                                    Label("Show live stats in menu bar", systemImage: "chart.bar")
                                        .font(.body)

                                    Spacer()

                                    Toggle("", isOn: $preferences.showLiveStats)
                                        .labelsHidden()
                                }
                            }
                        }
                    }

                    // Display Section
                    SettingsSectionView(title: "Display", icon: "ruler") {
                        SettingsRowView {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Distance units", systemImage: "arrow.left.and.right")
                                    .font(.body)

                                Picker("", selection: $preferences.distanceUnit) {
                                    Label("Metric (km/m)", systemImage: "m.square")
                                        .tag(DistanceUnit.metric)
                                    Label("Imperial (mi/ft)", systemImage: "i.square")
                                        .tag(DistanceUnit.imperial)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                        }
                    }

                    // Data Section
                    SettingsSectionView(title: "Data", icon: "externaldrive") {
                        VStack(spacing: 12) {
                            Button(action: {
                                exportData()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title3)
                                        .foregroundStyle(.blue)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Export data")
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text("Save your metrics as CSV")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                showResetConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .font(.title3)
                                        .foregroundStyle(.red)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Reset all data")
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text("Permanently delete all metrics")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }

                    // Footer
                    VStack(spacing: 4) {
                        Text("InputMetrics")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Track your productivity")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text("© 2026 InputMetrics. All rights reserved.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 32)
            }

            if showExportToast, let result = exportResult {
                VStack {
                    Spacer()

                    HStack(spacing: 12) {
                        Image(systemName: result.icon)
                            .foregroundStyle(result.color)

                        Text(result.message)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert("Reset all data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetData()
            }
        } message: {
            Text("This will permanently delete all tracking data. This action cannot be undone.")
        }
        .onChange(of: exportResult?.message) { oldValue, newValue in
            if newValue != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showExportToast = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showExportToast = false
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exportResult = nil
                    }
                }
            }
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "InputMetrics-Export.csv"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let csvContent = generateCSV()
                    try csvContent.write(to: url, atomically: true, encoding: .utf8)
                    exportResult = .success("Data exported to \(url.lastPathComponent)")
                } catch {
                    exportResult = .failure("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func generateCSV() -> String {
        var csv = ""

        // Daily summary section
        csv += "=== DAILY SUMMARY ===\n"
        csv += "Date,Mouse Distance (px),Left Clicks,Right Clicks,Middle Clicks,Keystrokes\n"

        let allSummaries = DatabaseManager.shared.getAllDailySummaries()
        for summary in allSummaries {
            csv += "\(summary.date),\(summary.mouseDistancePx),\(summary.mouseClicksLeft),\(summary.mouseClicksRight),\(summary.mouseClicksMiddle),\(summary.keystrokes)\n"
        }

        csv += "\n"

        // Mouse heatmap section
        csv += "=== MOUSE HEATMAP ===\n"
        csv += "Date,Screen ID,Bucket X,Bucket Y,Click Count\n"

        let allMouseData = DatabaseManager.shared.getAllMouseHeatmapEntries()
        for entry in allMouseData {
            csv += "\(entry.date),\(entry.screenId),\(entry.bucketX),\(entry.bucketY),\(entry.clickCount)\n"
        }

        csv += "\n"

        // Keyboard heatmap section
        csv += "=== KEYBOARD HEATMAP ===\n"
        csv += "Date,Key Code,Key Name,Modifier Flags,Count\n"

        let allKeyboardData = DatabaseManager.shared.getAllKeyboardEntries()
        for entry in allKeyboardData {
            let keyName = KeyCodeMapping.keyName(for: entry.keyCode)
            csv += "\(entry.date),\(entry.keyCode),\(keyName),\(entry.modifierFlags),\(entry.count)\n"
        }

        return csv
    }

    private func resetData() {
        DatabaseManager.shared.resetAllData()
        exportResult = .success("All data has been reset")
    }
}

// MARK: - Helper Views

struct SettingsSectionView<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(title)
                    .font(.headline)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal)

            content()
        }
    }
}

struct SettingsRowView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

#Preview {
    SettingsView()
}
