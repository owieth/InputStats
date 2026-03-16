import SwiftUI
import AppKit
import os

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var liveStatsTimer: Timer?
    private var milestoneTimer: Timer?
    private var backgroundActivity: NSObjectProtocol?
    private var keyboardPermissionTimer: Timer?
    private var isQuittingFromMenu = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent App Nap from suspending background event monitoring
        backgroundActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "Continuous input event monitoring"
        )

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
            let appIcon = NSImage(named: "AppIcon")
            appIcon?.size = NSSize(width: 18, height: 18)
            button.image = appIcon
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

        // Run data retention cleanup
        let retentionPeriod = UserPreferences.shared.dataRetentionPeriod
        if let days = retentionPeriod.days {
            DatabaseManager.shared.pruneOldData(olderThanDays: days)
        }

        // Start event monitoring on main actor
        Task { @MainActor in
            EventMonitor.shared.start()
        }

        // Start global hotkey
        if UserPreferences.shared.hotkeyEnabled {
            HotkeyManager.shared.start { [weak self] in
                self?.togglePopover()
            }
        }

        // Start live stats timer
        startLiveStatsTimer()

        // Setup notifications if enabled
        if UserPreferences.shared.notificationsEnabled {
            NotificationManager.shared.requestPermission()
            NotificationManager.shared.scheduleDailySummary()
        }

        // Start milestone check timer
        startMilestoneCheckTimer()

        // Show onboarding on first launch
        if !UserPreferences.shared.hasCompletedOnboarding {
            WindowManager.shared.openOnboardingWindow {
                WindowManager.shared.closeOnboardingWindow()
            }
        }

        // Delayed check for Input Monitoring permission
        scheduleKeyboardPermissionCheck()

        AppLogger.general.info("App launched")
    }

    @objc private func statusItemClicked() {
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
            togglePopover()
        }
    }

    func togglePopoverFromHotkey() {
        togglePopover()
    }

    private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openSettings() {
        WindowManager.shared.openSettingsWindow()
    }

    @objc private func quitApp() {
        isQuittingFromMenu = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isQuittingFromMenu {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Quit InputMetrics?"
        alert.informativeText = "InputMetrics runs in the menu bar to track your input. To quit, use the menu bar icon's right-click menu."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Keep Running")
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            return .terminateNow
        }
        return .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let activity = backgroundActivity {
            ProcessInfo.processInfo.endActivity(activity)
            backgroundActivity = nil
        }

        liveStatsTimer?.invalidate()
        liveStatsTimer = nil
        keyboardPermissionTimer?.invalidate()
        keyboardPermissionTimer = nil
        HotkeyManager.shared.stop()
        milestoneTimer?.invalidate()
        milestoneTimer = nil

        MainActor.assumeIsolated {
            MouseTracker.shared.persistData()
            KeyboardTracker.shared.persistData()
            EventMonitor.shared.stop()
        }
    }

    // MARK: - Keyboard Permission Check

    private func scheduleKeyboardPermissionCheck() {
        let timer = Timer(timeInterval: 30.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.checkKeyboardPermission()
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        keyboardPermissionTimer = timer
    }

    private func checkKeyboardPermission() {
        guard EventMonitor.shared.isKeyboardPermissionLikelyMissing else { return }
        guard !UserPreferences.shared.dismissedKeyboardPermissionWarning else { return }

        let alert = NSAlert()
        alert.messageText = "Input Monitoring Permission Required"
        alert.informativeText = "InputMetrics needs Input Monitoring permission to track keyboard events.\n\n1. Open System Settings\n2. Go to Privacy & Security > Input Monitoring\n3. Enable InputMetrics\n\nKeyboard tracking will start automatically once permission is granted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Live Stats

    private func startLiveStatsTimer() {
        let statsTimer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveStats()
            }
        }
        RunLoop.current.add(statsTimer, forMode: .common)
        liveStatsTimer = statsTimer
    }

    private func startMilestoneCheckTimer() {
        let timer = Timer(timeInterval: 300, repeats: true) { _ in
            Task { @MainActor in
                NotificationManager.shared.checkMilestones()
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        milestoneTimer = timer
    }

    private func updateLiveStats() {
        guard let button = statusItem?.button else { return }
        guard UserPreferences.shared.showLiveStats else {
            button.title = ""
            button.subviews.forEach { $0.removeFromSuperview() }
            let appIcon = NSImage(named: "AppIcon")
            appIcon?.size = NSSize(width: 18, height: 18)
            button.image = appIcon
            statusItem?.length = NSStatusItem.variableLength
            return
        }

        let mouseStats = MouseTracker.shared.getCurrentStats()
        let keyboardStats = KeyboardTracker.shared.getCurrentKeystrokes()

        let today = DateHelper.todayString()
        let summary = DatabaseManager.shared.getDailySummary(date: today)

        var totalDistance = mouseStats.distance
        var totalKeystrokes = keyboardStats

        if let summary {
            totalDistance += summary.mouseDistancePx
            totalKeystrokes += summary.keystrokes
        }

        let distanceMeters = totalDistance / 4330.0
        let distanceText = formatDistance(distanceMeters)
        let keystrokesText = formatCount(totalKeystrokes)

        button.title = ""
        button.image = nil
        configureStatusButton(button, distanceText: distanceText, keystrokesText: keystrokesText)
    }

    private func configureStatusButton(_ button: NSStatusBarButton, distanceText: String, keystrokesText: String) {
        button.subviews.forEach { $0.removeFromSuperview() }

        let container = NSStackView()
        container.orientation = .horizontal
        container.spacing = 2
        container.alignment = .centerY
        container.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let iconView = NSImageView()
        iconView.image = NSImage(named: "AppIcon")
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18)
        ])

        let statsStack = NSStackView()
        statsStack.orientation = .vertical
        statsStack.spacing = 0
        statsStack.alignment = .leading

        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)

        let distanceLabel = NSTextField(labelWithString: distanceText)
        distanceLabel.font = font
        distanceLabel.textColor = .labelColor

        let keystrokesLabel = NSTextField(labelWithString: keystrokesText)
        keystrokesLabel.font = font
        keystrokesLabel.textColor = .labelColor

        statsStack.addArrangedSubview(distanceLabel)
        statsStack.addArrangedSubview(keystrokesLabel)

        container.addArrangedSubview(iconView)
        container.addArrangedSubview(statsStack)

        container.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(container)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])

        let fittingSize = container.fittingSize
        statusItem?.length = fittingSize.width + 4
    }

    private func formatDistance(_ meters: Double) -> String {
        if UserPreferences.shared.distanceUnit == .imperial {
            let feet = meters / Constants.metersPerFoot
            if feet >= Constants.feetPerMile {
                return String(format: "%.1fmi", feet / Constants.feetPerMile)
            } else {
                return String(format: "%.0fft", feet)
            }
        } else {
            if meters >= 1000 {
                return String(format: "%.1fkm", meters / 1000)
            } else {
                return String(format: "%.0fm", meters)
            }
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
