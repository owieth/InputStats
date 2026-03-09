import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var liveStatsTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize database
        _ = DatabaseManager.shared

        if !DatabaseManager.shared.isReady {
            let alert = NSAlert()
            alert.messageText = "Database Error"
            alert.informativeText = DatabaseManager.shared.initializationError
                ?? "Failed to initialize the database."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "InputMetrics")
            button.imagePosition = .imageLeading
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 420, height: 600)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())

        // Hide dock icon for menu bar-only app
        NSApp.setActivationPolicy(.accessory)

        // Start event monitoring on main actor
        Task { @MainActor in
            EventMonitor.shared.start()
        }

        // Start live stats timer
        startLiveStatsTimer()

        print("InputMetrics launched successfully")
    }

    @MainActor @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        guard let button = statusItem?.button else { return }

        // Check if it's a right-click
        if event.type == .rightMouseUp {
            // Show context menu
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit InputMetrics", action: #selector(quitApp), keyEquivalent: "q"))

            statusItem?.menu = menu
            button.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Left-click - toggle popover
            guard let popover = popover else { return }

            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    @MainActor @objc private func openSettings() {
        WindowManager.shared.openSettingsWindow()
    }

    @MainActor @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        liveStatsTimer?.invalidate()
        liveStatsTimer = nil

        MainActor.assumeIsolated {
            MouseTracker.shared.persistData()
            KeyboardTracker.shared.persistData()
            EventMonitor.shared.stop()
        }
    }

    // MARK: - Live Stats

    private func startLiveStatsTimer() {
        liveStatsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveStats()
            }
        }
    }

    @MainActor private func updateLiveStats() {
        guard let button = statusItem?.button else { return }
        guard UserPreferences.shared.showLiveStats else {
            button.title = ""
            return
        }

        let mouseStats = MouseTracker.shared.getCurrentStats()
        let keyboardStats = KeyboardTracker.shared.getCurrentKeystrokes()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        var totalDistance = mouseStats.distance
        var totalKeystrokes = keyboardStats

        if let summary = DatabaseManager.shared.getDailySummary(date: today) {
            totalDistance += summary.mouseDistancePx
            totalKeystrokes += summary.keystrokes
        }

        let distanceMeters = totalDistance / 4330.0
        let distanceText = formatDistance(distanceMeters)
        let keystrokesText = formatCount(totalKeystrokes)

        button.title = " \(distanceText) · \(keystrokesText)"
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000)
        } else {
            return String(format: "%.0fm", meters)
        }
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        } else {
            return "\(count)"
        }
    }
}
