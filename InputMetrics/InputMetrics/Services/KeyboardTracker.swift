import Foundation
import CoreGraphics
import os

@MainActor
class KeyboardTracker {
    static let shared = KeyboardTracker()

    private var totalKeystrokes: Int = 0
    private var persistTimer: Timer?
    private let persistInterval: TimeInterval = 30.0

    private struct HeatmapKey: Hashable {
        let keyCode: Int
        let modifierFlags: Int
    }

    private var heatmapBuffer: [HeatmapKey: Int] = [:]

    private init() {
        setupPersistTimer()
    }

    func trackKeystroke(keyCode: Int, modifierFlags: CGEventFlags) {
        totalKeystrokes += 1

        let meaningfulFlags = modifierFlags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        let modifierInt = Int(meaningfulFlags.rawValue)

        let key = HeatmapKey(keyCode: keyCode, modifierFlags: modifierInt)
        heatmapBuffer[key, default: 0] += 1
    }

    private func setupPersistTimer() {
        persistTimer = Timer.scheduledTimer(withTimeInterval: persistInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.persistData()
            }
        }
    }

    func persistData() {
        let today = DateHelper.todayString()
        let currentHour = getCurrentHour()

        DatabaseManager.shared.updateDailySummary(
            date: today,
            keystrokes: totalKeystrokes
        )

        DatabaseManager.shared.updateHourlySummary(
            date: today,
            hour: currentHour,
            keystrokes: totalKeystrokes
        )

        let bufferedEntries = heatmapBuffer
        heatmapBuffer.removeAll(keepingCapacity: true)

        if !bufferedEntries.isEmpty {
            DatabaseManager.shared.updateKeyboardBatch(
                date: today,
                entries: bufferedEntries.map { (key, count) in
                    (keyCode: key.keyCode, modifierFlags: key.modifierFlags, count: count)
                }
            )
        }

        let count = totalKeystrokes
        totalKeystrokes = 0

        AppLogger.keyboard.debug("Persisted: \(count) keystrokes, \(bufferedEntries.count) unique keys")
    }

    func reset() {
        totalKeystrokes = 0
        heatmapBuffer.removeAll()
    }

    func getCurrentKeystrokes() -> Int {
        return totalKeystrokes
    }

    private func getCurrentHour() -> Int {
        Calendar.current.component(.hour, from: Date())
    }

    nonisolated deinit {
        MainActor.assumeIsolated {
            persistTimer?.invalidate()
        }
    }
}
