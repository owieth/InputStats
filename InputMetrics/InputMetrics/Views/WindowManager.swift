import SwiftUI
import AppKit

@MainActor
class WindowManager: ObservableObject {
    static let shared = WindowManager()

    private var settingsWindow: NSWindow?
    private var dashboardWindow: NSWindow?

    private init() {}

    func openSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 500, height: 400))
        window.center()
        window.makeKeyAndOrderFront(nil)

        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func openDashboardWindow() {
        if let window = dashboardWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let dashboardView = MainWindowView()
        let hostingController = NSHostingController(rootView: dashboardView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "InputMetrics Dashboard"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
        window.makeKeyAndOrderFront(nil)

        dashboardWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}
