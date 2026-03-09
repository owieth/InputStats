import Foundation
import CoreGraphics
import AppKit

enum ClickType: Sendable {
    case left, right, middle
}

@MainActor
class MouseTracker {
    static let shared = MouseTracker()

    private var lastPoint: CGPoint?
    private var accumulatedDistance: Double = 0
    private var leftClicks: Int = 0
    private var rightClicks: Int = 0
    private var middleClicks: Int = 0

    private var persistTimer: Timer?
    private let persistInterval: TimeInterval = 30.0

    private init() {
        setupPersistTimer()
    }

    func trackMovement(to point: CGPoint) {
        guard let last = lastPoint else {
            lastPoint = point
            return
        }

        let dx = point.x - last.x
        let dy = point.y - last.y
        let distance = sqrt(dx * dx + dy * dy)

        accumulatedDistance += distance
        lastPoint = point
    }

    func trackClick(type: ClickType, at point: CGPoint) {
        switch type {
        case .left:
            leftClicks += 1
        case .right:
            rightClicks += 1
        case .middle:
            middleClicks += 1
        }

        // Update heatmap
        let bucket = bucketForPoint(point)
        let screenId = getScreenId(for: point)
        let today = getTodayString()

        DatabaseManager.shared.updateMouseHeatmap(
            date: today,
            screenId: screenId,
            bucketX: bucket.x,
            bucketY: bucket.y
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
            mouseDistance: accumulatedDistance,
            leftClicks: leftClicks,
            rightClicks: rightClicks,
            middleClicks: middleClicks
        )

        // Reset all counters after persist
        let persistedDistance = accumulatedDistance
        let persistedLeft = leftClicks
        let persistedRight = rightClicks
        let persistedMiddle = middleClicks

        accumulatedDistance = 0
        leftClicks = 0
        rightClicks = 0
        middleClicks = 0

        print("Mouse data persisted: \(persistedDistance)px, L:\(persistedLeft) R:\(persistedRight) M:\(persistedMiddle)")
    }

    func getCurrentStats() -> (distance: Double, left: Int, right: Int, middle: Int) {
        return (accumulatedDistance, leftClicks, rightClicks, middleClicks)
    }

    private func bucketForPoint(_ point: CGPoint) -> (x: Int, y: Int) {
        // Get all screens and calculate combined bounds
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return (0, 0) }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for screen in screens {
            let frame = screen.frame
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)
        }

        let width = maxX - minX
        let height = maxY - minY

        // Normalize to 50x50 grid
        let normalizedX = (point.x - minX) / width
        let normalizedY = (point.y - minY) / height
        let bucketX = min(49, max(0, Int(normalizedX * 50)))
        let bucketY = min(49, max(0, Int(normalizedY * 50)))

        return (bucketX, bucketY)
    }

    private func getScreenId(for point: CGPoint) -> String {
        // Find which screen contains this point
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "primary"
            }
        }
        return "primary"
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
