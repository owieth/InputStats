import Foundation
import CoreGraphics
import AppKit

enum ClickType: Sendable {
    case left, right, middle
}

struct HeatmapBucketKey: Hashable {
    let date: String
    let screenId: String
    let bucketX: Int
    let bucketY: Int
}

@MainActor
class MouseTracker {
    static let shared = MouseTracker()

    private var lastPoint: CGPoint?
    private var accumulatedDistance: Double = 0
    private var leftClicks: Int = 0
    private var rightClicks: Int = 0
    private var middleClicks: Int = 0
    private var scrollVertical: Double = 0
    private var scrollHorizontal: Double = 0

    private var heatmapBuffer: [HeatmapBucketKey: Int] = [:]

    private var persistTimer: Timer?
    private let persistInterval: TimeInterval = 30.0

    // Cached screen geometry — invalidated on display configuration changes
    private struct ScreenCache {
        let primaryHeight: CGFloat
        let boundingMinX: CGFloat
        let boundingMinY: CGFloat
        let boundingWidth: CGFloat
        let boundingHeight: CGFloat
        let screens: [(frame: CGRect, id: String)]
    }

    private var screenCache: ScreenCache?

    private init() {
        setupPersistTimer()
        rebuildScreenCache()
        DistanceConverter.refreshDPI()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildScreenCache()
            }
        }
    }

    private func rebuildScreenCache() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            screenCache = nil
            return
        }

        let primaryHeight = screens[0].frame.height

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        var cachedScreens: [(frame: CGRect, id: String)] = []

        for screen in screens {
            let frame = screen.frame
            minX = min(minX, frame.minX)
            minY = min(minY, frame.minY)
            maxX = max(maxX, frame.maxX)
            maxY = max(maxY, frame.maxY)

            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "primary"
            cachedScreens.append((frame: frame, id: id))
        }

        screenCache = ScreenCache(
            primaryHeight: primaryHeight,
            boundingMinX: minX,
            boundingMinY: minY,
            boundingWidth: maxX - minX,
            boundingHeight: maxY - minY,
            screens: cachedScreens
        )

        DistanceConverter.refreshDPI()
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

        let bucket = bucketForPoint(point)
        let screenId = getScreenId(for: point)
        let today = DateHelper.todayString()

        let key = HeatmapBucketKey(date: today, screenId: screenId, bucketX: bucket.x, bucketY: bucket.y)
        heatmapBuffer[key, default: 0] += 1
    }

    func trackScroll(deltaX: Double, deltaY: Double) {
        scrollVertical += abs(deltaY)
        scrollHorizontal += abs(deltaX)
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
            mouseDistance: accumulatedDistance,
            leftClicks: leftClicks,
            rightClicks: rightClicks,
            middleClicks: middleClicks,
            scrollVertical: scrollVertical,
            scrollHorizontal: scrollHorizontal
        )

        DatabaseManager.shared.updateHourlySummary(
            date: today,
            hour: currentHour,
            mouseDistance: accumulatedDistance,
            mouseClicks: leftClicks + rightClicks + middleClicks
        )

        if !heatmapBuffer.isEmpty {
            DatabaseManager.shared.batchUpdateMouseHeatmap(heatmapBuffer)
        }

        // Reset all counters after persist
        let persistedDistance = accumulatedDistance
        let persistedLeft = leftClicks
        let persistedRight = rightClicks
        let persistedMiddle = middleClicks
        let persistedScrollV = scrollVertical
        let persistedScrollH = scrollHorizontal
        let persistedHeatmapBuckets = heatmapBuffer.count

        accumulatedDistance = 0
        leftClicks = 0
        rightClicks = 0
        middleClicks = 0
        scrollVertical = 0
        scrollHorizontal = 0
        heatmapBuffer.removeAll()

        print("Mouse data persisted: \(persistedDistance)px, L:\(persistedLeft) R:\(persistedRight) M:\(persistedMiddle) SV:\(persistedScrollV) SH:\(persistedScrollH), heatmap buckets:\(persistedHeatmapBuckets)")
    }

    func reset() {
        accumulatedDistance = 0
        leftClicks = 0
        rightClicks = 0
        middleClicks = 0
        scrollVertical = 0
        scrollHorizontal = 0
        lastPoint = nil
        heatmapBuffer.removeAll()
    }

    func getCurrentStats() -> (distance: Double, left: Int, right: Int, middle: Int, scrollV: Double, scrollH: Double) {
        return (accumulatedDistance, leftClicks, rightClicks, middleClicks, scrollVertical, scrollHorizontal)
    }

    private func bucketForPoint(_ point: CGPoint) -> (x: Int, y: Int) {
        guard let cache = screenCache else { return (0, 0) }

        // Convert CG Y (origin bottom-left) to AppKit Y (origin top-left)
        let appKitY = cache.primaryHeight - point.y

        // Normalize to 50x50 grid
        let normalizedX = (point.x - cache.boundingMinX) / cache.boundingWidth
        let normalizedY = (appKitY - cache.boundingMinY) / cache.boundingHeight
        let bucketX = min(49, max(0, Int(normalizedX * 50)))
        let bucketY = min(49, max(0, Int(normalizedY * 50)))

        return (bucketX, bucketY)
    }

    private func getScreenId(for point: CGPoint) -> String {
        guard let cache = screenCache else { return "primary" }

        for screen in cache.screens {
            if screen.frame.contains(point) {
                return screen.id
            }
        }
        return "primary"
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
