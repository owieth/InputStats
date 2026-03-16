import Foundation
import CoreGraphics
import os

@MainActor
class KeyboardTracker {
    static let shared = KeyboardTracker()

    private var totalKeystrokes: Int = 0
    private var keystrokeTimestamps: [Date] = []
    private var peakWPM: Double = 0
    private var persistTimer: Timer?
    private let persistInterval: TimeInterval = 30.0

    private struct HeatmapKey: Hashable {
        let keyCode: Int
        let modifierFlags: Int
    }

    // Naturally bounded by unique key+modifier combinations (~100 keys)
    private var heatmapBuffer: [HeatmapKey: Int] = [:]

    private init() {
        setupPersistTimer()
    }

    func trackKeystroke(keyCode: Int, modifierFlags: CGEventFlags) {
        totalKeystrokes += 1

        let now = Date()
        keystrokeTimestamps.append(now)

        // Keep only last 60 seconds of timestamps for WPM calculation
        keystrokeTimestamps.removeAll { now.timeIntervalSince($0) > 60 }

        // Calculate current WPM (keystrokes per minute / 5 chars per word)
        if keystrokeTimestamps.count >= 2 {
            let timeSpan = keystrokeTimestamps.last!.timeIntervalSince(keystrokeTimestamps.first!)
            if timeSpan > 0 {
                let currentWPM = (Double(keystrokeTimestamps.count) / timeSpan) * 60.0 / 5.0
                peakWPM = max(peakWPM, currentWPM)
            }
        }

        let meaningfulFlags = modifierFlags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        let modifierInt = Int(meaningfulFlags.rawValue)

        let key = HeatmapKey(keyCode: keyCode, modifierFlags: modifierInt)
        heatmapBuffer[key, default: 0] += 1
    }

    func getSpeedStats() -> (peakWPM: Double, avgWPM: Double) {
        let avgWPM: Double
        if keystrokeTimestamps.count >= 2,
           let first = keystrokeTimestamps.first,
           let last = keystrokeTimestamps.last {
            let span = last.timeIntervalSince(first)
            avgWPM = span > 0 ? (Double(keystrokeTimestamps.count) / span) * 60.0 / 5.0 : 0
        } else {
            avgWPM = 0
        }
        return (peakWPM, avgWPM)
    }

    private func setupPersistTimer() {
        let timer = Timer(timeInterval: persistInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.persistData()
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        persistTimer = timer
    }

    func persistData() {
        let today = DateHelper.todayString()
        let currentHour = getCurrentHour()
        let activityTimes = EventMonitor.shared.getActivityTimes()
        let speedStats = getSpeedStats()

        DatabaseManager.shared.updateDailySummary(
            date: today,
            keystrokes: totalKeystrokes,
            firstActiveAt: activityTimes.first,
            lastActiveAt: activityTimes.last,
            peakWPM: speedStats.peakWPM
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
        peakWPM = 0
        keystrokeTimestamps.removeAll()

        AppLogger.keyboard.debug("Persisted: \(count) keystrokes, \(bufferedEntries.count) unique keys")
    }

    func reset() {
        totalKeystrokes = 0
        peakWPM = 0
        keystrokeTimestamps.removeAll()
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
