import SwiftUI
import UniformTypeIdentifiers
import LaunchAtLogin
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
}

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
    @State private var showRestoreConfirmation = false
    @State private var exportResult: ExportResult?
    @State private var showExportToast = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var databaseSize: String = "Calculating..."
    @State private var totalRecords: Int = 0

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
                        SettingsGroupView {
                            SettingsGroupItemView {
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

                            Divider()
                                .padding(.horizontal)

                            SettingsGroupItemView {
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

                    // Shortcuts Section
                    SettingsSectionView(title: "Shortcuts", icon: "command") {
                        SettingsRowView {
                            HStack {
                                Label("Global shortcut (\u{2325}\u{21e7}I)", systemImage: "keyboard")
                                    .font(.body)
                                Spacer()
                                Toggle("", isOn: $preferences.hotkeyEnabled)
                                    .labelsHidden()
                                    .onChange(of: preferences.hotkeyEnabled) { _, enabled in
                                        if enabled {
                                            HotkeyManager.shared.start {
                                                if let delegate = NSApp.delegate as? AppDelegate {
                                                    delegate.togglePopoverFromHotkey()
                                                }
                                            }
                                        } else {
                                            HotkeyManager.shared.stop()
                                        }
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

                    // Goals Section
                    SettingsSectionView(title: "Goals", icon: "target") {
                        SettingsGroupView {
                            SettingsGroupItemView {
                                HStack {
                                    Label("Enable daily goals", systemImage: "flag")
                                        .font(.body)
                                    Spacer()
                                    Toggle("", isOn: $preferences.goalConfig.enabled)
                                        .labelsHidden()
                                }
                            }

                            if preferences.goalConfig.enabled {
                                Divider()
                                    .padding(.horizontal)

                                SettingsGroupItemView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Daily keystroke goal", systemImage: "keyboard")
                                            .font(.body)
                                        HStack {
                                            Slider(value: Binding(
                                                get: { Double(preferences.goalConfig.keystrokesDaily) },
                                                set: { preferences.goalConfig.keystrokesDaily = Int($0) }
                                            ), in: 1000...50000, step: 1000)
                                            Text("\(preferences.goalConfig.keystrokesDaily)")
                                                .monospacedDigit()
                                                .frame(width: 60, alignment: .trailing)
                                        }
                                    }
                                }

                                Divider()
                                    .padding(.horizontal)

                                SettingsGroupItemView {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Daily distance goal (km)", systemImage: "arrow.up.right")
                                            .font(.body)
                                        let kmValue = Binding(
                                            get: { preferences.goalConfig.distanceDaily / 4_330_000 },
                                            set: { preferences.goalConfig.distanceDaily = $0 * 4_330_000 }
                                        )
                                        HStack {
                                            Slider(value: kmValue, in: 0.1...10, step: 0.1)
                                            Text(String(format: "%.1f km", kmValue.wrappedValue))
                                                .monospacedDigit()
                                                .frame(width: 70, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Notifications Section
                    SettingsSectionView(title: "Notifications", icon: "bell") {
                        VStack(spacing: 0) {
                            SettingsRowView {
                                HStack {
                                    Label("Enable notifications", systemImage: "bell.badge")
                                        .font(.body)
                                    Spacer()
                                    Toggle("", isOn: $preferences.notificationsEnabled)
                                        .labelsHidden()
                                        .onChange(of: preferences.notificationsEnabled) { _, enabled in
                                            if enabled {
                                                NotificationManager.shared.requestPermission()
                                                Task {
                                                    await NotificationManager.shared.scheduleDailySummary()
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }

                    // Storage Section
                    SettingsSectionView(title: "Storage", icon: "internaldrive") {
                        SettingsGroupView {
                            SettingsGroupItemView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Data retention", systemImage: "clock.arrow.circlepath")
                                        .font(.body)

                                    Picker("", selection: $preferences.dataRetentionPeriod) {
                                        ForEach(DataRetentionPeriod.allCases) { period in
                                            Text(period.displayName).tag(period)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    .onChange(of: preferences.dataRetentionPeriod) { _, newValue in
                                        if let days = newValue.days {
                                            DatabaseManager.shared.pruneOldData(olderThanDays: days)
                                            refreshDatabaseInfo()
                                        }
                                    }

                                    Text("Data older than the selected period is automatically deleted on app launch.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()
                                .padding(.horizontal)

                            SettingsGroupItemView {
                                HStack {
                                    Label("Database size", systemImage: "externaldrive")
                                        .font(.body)

                                    Spacer()

                                    Text(databaseSize)
                                        .font(.body)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Divider()
                                .padding(.horizontal)

                            SettingsGroupItemView {
                                HStack {
                                    Label("Total records", systemImage: "number")
                                        .font(.body)

                                    Spacer()

                                    Text("\(totalRecords)")
                                        .font(.body)
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Data Section
                    SettingsSectionView(title: "Data", icon: "externaldrive") {
                        VStack(spacing: 12) {
                            SettingsRowView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label("Export format", systemImage: "doc")
                                        .font(.body)

                                    Picker("", selection: $exportFormat) {
                                        ForEach(ExportFormat.allCases, id: \.self) { format in
                                            Text(format.rawValue).tag(format)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                }
                            }

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

                                        Text("Save your metrics as \(exportFormat.rawValue)")
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
                                backupDatabase()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.doc")
                                        .font(.title3)
                                        .foregroundStyle(.blue)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Backup database")
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text("Save a full copy of your database")
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
                                showRestoreConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.doc")
                                        .font(.title3)
                                        .foregroundStyle(.orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Restore database")
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text("Replace current data from a backup")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(Color.orange.opacity(0.1))
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

                    #if DEBUG
                    SettingsSectionView(title: "Debug", icon: "ladybug") {
                        SettingsRowView {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Log viewer", systemImage: "doc.text")
                                    .font(.body)

                                Text("View logs in Console.app with subsystem: com.inputmetrics.app")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Open Console") {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
                                }
                                .buttonStyle(.link)
                            }
                        }
                    }
                    #endif

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
        .alert("Restore database?", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                restoreDatabase()
            }
        } message: {
            Text("This will replace all current data with the backup. This action cannot be undone.")
        }
        .onAppear {
            refreshDatabaseInfo()
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
        let fileExtension = exportFormat == .csv ? "csv" : "json"
        panel.nameFieldStringValue = "InputMetrics-Export.\(fileExtension)"
        panel.canCreateDirectories = true

        if exportFormat == .csv {
            panel.allowedContentTypes = [.commaSeparatedText]
        } else {
            panel.allowedContentTypes = [.json]
        }

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let content = exportFormat == .csv ? generateCSV() : generateJSON()
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    exportResult = .success("Data exported to \(url.lastPathComponent)")
                } catch {
                    exportResult = .failure("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func csvRow(_ fields: [String]) -> String {
        fields.map { csvField($0) }.joined(separator: ",")
    }

    private func generateJSON() -> String {
        struct ExportData: Codable {
            let dailySummaries: [DailySummary]
            let hourlySummaries: [HourlySummary]
            let mouseHeatmap: [MouseHeatmapEntry]
            let keyboardHeatmap: [KeyboardEntry]
        }

        let data = ExportData(
            dailySummaries: DatabaseManager.shared.getAllDailySummaries(),
            hourlySummaries: DatabaseManager.shared.getAllHourlySummaries(),
            mouseHeatmap: DatabaseManager.shared.getAllMouseHeatmapEntries(),
            keyboardHeatmap: DatabaseManager.shared.getAllKeyboardEntries()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private func generateCSV() -> String {
        var lines: [String] = []

        lines.append(csvRow(["Date", "Mouse Distance (px)", "Left Clicks", "Right Clicks", "Middle Clicks", "Keystrokes", "Scroll Vertical", "Scroll Horizontal"]))

        let allSummaries = DatabaseManager.shared.getAllDailySummaries()
        for summary in allSummaries {
            lines.append(csvRow([
                summary.date,
                "\(summary.mouseDistancePx)",
                "\(summary.mouseClicksLeft)",
                "\(summary.mouseClicksRight)",
                "\(summary.mouseClicksMiddle)",
                "\(summary.keystrokes)",
                "\(summary.scrollDistanceVertical)",
                "\(summary.scrollDistanceHorizontal)"
            ]))
        }

        lines.append("")

        lines.append(csvRow(["Date", "Screen ID", "Bucket X", "Bucket Y", "Click Count"]))

        let allMouseData = DatabaseManager.shared.getAllMouseHeatmapEntries()
        for entry in allMouseData {
            lines.append(csvRow([
                entry.date,
                "\(entry.screenId)",
                "\(entry.bucketX)",
                "\(entry.bucketY)",
                "\(entry.clickCount)"
            ]))
        }

        lines.append("")

        lines.append(csvRow(["Date", "Key Code", "Key Name", "Modifier Flags", "Count"]))

        let allKeyboardData = DatabaseManager.shared.getAllKeyboardEntries()
        for entry in allKeyboardData {
            let keyName = KeyCodeMapping.keyName(for: entry.keyCode)
            lines.append(csvRow([
                entry.date,
                "\(entry.keyCode)",
                keyName,
                "\(entry.modifierFlags)",
                "\(entry.count)"
            ]))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func backupDatabase() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "InputMetrics-Backup.db"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "db") ?? .database]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try DatabaseManager.shared.backupDatabase(to: url)
                    exportResult = .success("Database backed up successfully")
                } catch {
                    exportResult = .failure("Backup failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func restoreDatabase() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "db") ?? .database]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    try DatabaseManager.shared.restoreDatabase(from: url)
                    exportResult = .success("Database restored successfully")
                    refreshDatabaseInfo()
                } catch {
                    exportResult = .failure("Restore failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func resetData() {
        DatabaseManager.shared.resetAllData()
        MouseTracker.shared.reset()
        KeyboardTracker.shared.reset()
        exportResult = .success("All data has been reset")
        refreshDatabaseInfo()
    }

    private func refreshDatabaseInfo() {
        let sizeBytes = DatabaseManager.shared.getDatabaseFileSize()
        databaseSize = formatFileSize(sizeBytes)

        let counts = DatabaseManager.shared.getRecordCounts()
        totalRecords = counts.dailySummaries + counts.mouseHeatmap + counts.keyboardHeatmap + counts.hourlySummaries
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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

struct SettingsGroupView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct SettingsGroupItemView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
}
