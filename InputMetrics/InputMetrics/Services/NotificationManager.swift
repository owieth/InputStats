import Foundation
import UserNotifications

@MainActor
class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendDailySummaryNotification(keystrokes: Int, distance: String, clicks: Int) {
        guard UserPreferences.shared.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily Summary"
        content.body = "Today: \(keystrokes) keystrokes, \(distance) distance, \(clicks) clicks"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "daily-summary-\(DateHelper.todayString())", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func sendMilestoneNotification(title: String, body: String) {
        guard UserPreferences.shared.notificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: "milestone-\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func scheduleDailySummary() {
        guard UserPreferences.shared.notificationsEnabled else { return }

        // Schedule for end of day (6 PM)
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Daily Summary Ready"
        content.body = "Check your InputMetrics stats for today!"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "daily-summary-reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func checkMilestones() {
        guard UserPreferences.shared.notificationsEnabled else { return }

        let totals = DatabaseManager.shared.getAllTimeTotals()
        let totalClicks = totals.totalClicks
        let totalKeystrokes = totals.keystrokes

        let clickMilestones = [1000, 5000, 10_000, 50_000, 100_000, 500_000, 1_000_000]
        let keystrokeMilestones = [10_000, 50_000, 100_000, 500_000, 1_000_000]

        let lastClickMilestone = UserDefaults.standard.integer(forKey: "lastClickMilestone")
        let lastKeystrokeMilestone = UserDefaults.standard.integer(forKey: "lastKeystrokeMilestone")

        if let milestone = clickMilestones.first(where: { $0 > lastClickMilestone && totalClicks >= $0 }) {
            sendMilestoneNotification(title: "Click Milestone!", body: "You've reached \(milestone) total clicks!")
            UserDefaults.standard.set(milestone, forKey: "lastClickMilestone")
        }

        if let milestone = keystrokeMilestones.first(where: { $0 > lastKeystrokeMilestone && totalKeystrokes >= $0 }) {
            sendMilestoneNotification(title: "Keystroke Milestone!", body: "You've reached \(milestone) total keystrokes!")
            UserDefaults.standard.set(milestone, forKey: "lastKeystrokeMilestone")
        }
    }
}
