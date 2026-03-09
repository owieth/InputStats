import Foundation
import CoreGraphics

@MainActor
class KeyboardTracker {
    static let shared = KeyboardTracker()

    private var totalKeystrokes: Int = 0
    private var persistTimer: Timer?
    private let persistInterval: TimeInterval = 30.0

    private init() {
        setupPersistTimer()
    }

    func trackKeystroke(keyCode: Int, modifierFlags: CGEventFlags) {
        totalKeystrokes += 1

        let today = getTodayString()
        let meaningfulFlags = modifierFlags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        let modifierInt = Int(meaningfulFlags.rawValue)

        // Update keyboard heatmap in database
        DatabaseManager.shared.updateKeyboard(
            date: today,
            keyCode: keyCode,
            modifierFlags: modifierInt
        )
    }

    private func setupPersistTimer() {
        persistTimer = Timer.scheduledTimer(withTimeInterval: persistInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.persistData()
            }
        }
    }

    func persistData() {
        let today = getTodayString()

        DatabaseManager.shared.updateDailySummary(
            date: today,
            keystrokes: totalKeystrokes
        )

        // Reset counter
        let count = totalKeystrokes
        totalKeystrokes = 0

        print("Keyboard data persisted: \(count) keystrokes")
    }

    func getCurrentKeystrokes() -> Int {
        return totalKeystrokes
    }

    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            persistTimer?.invalidate()
        }
    }
}
