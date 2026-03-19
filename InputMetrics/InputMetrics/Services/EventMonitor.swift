@preconcurrency import Cocoa
import CoreGraphics
import os

@MainActor
class EventMonitor {
    static let shared = EventMonitor()

    private var eventTap: CFMachPort?
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 30

    private var firstActiveAt: String?
    private var lastActiveAt: String?
    private var currentDate: String?

    private var lastEventTime: Date = Date()
    private var activeSeconds: TimeInterval = 0
    private let idleThreshold: TimeInterval = 300

    private var appBuffer: [String: (name: String, keystrokes: Int, clicks: Int)] = [:]
    private var appPersistTimer: Timer?

    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    private var mouseEventCount: Int = 0
    private var keyboardEventCount: Int = 0

    var isKeyboardPermissionLikelyMissing: Bool {
        mouseEventCount > 50 && keyboardEventCount == 0
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private init() {}

    func start() {
        startAppTracking()
        startSleepWakeObservers()
        if createAndStartEventTap() { return }

        AppLogger.events.warning("Event tap creation failed -- accessibility permission likely not granted")
        AppLogger.events.info("Please enable InputMetrics in System Settings > Privacy & Security > Accessibility")

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "InputMetrics needs Accessibility permission to track mouse and keyboard events.\n\n1. Open System Settings\n2. Go to Privacy & Security > Accessibility\n3. Enable InputMetrics\n\nThe app will start automatically once permission is granted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }

        startRetryTimer()
    }

    func stop() {
        appPersistTimer?.invalidate()
        appPersistTimer = nil
        persistAppUsage()
        retryTimer?.invalidate()
        retryTimer = nil
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        sleepObserver = nil
        wakeObserver = nil
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        CFMachPortInvalidate(eventTap)
        self.eventTap = nil
        AppLogger.events.info("Event monitoring stopped")
    }

    private func createAndStartEventTap() -> Bool {
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                       (1 << CGEventType.leftMouseDown.rawValue) |
                       (1 << CGEventType.rightMouseDown.rawValue) |
                       (1 << CGEventType.otherMouseDown.rawValue) |
                       (1 << CGEventType.keyDown.rawValue) |
                       (1 << CGEventType.scrollWheel.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let activeTap = EventMonitor.shared.eventTap {
                        CGEvent.tapEnable(tap: activeTap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                EventMonitor.shared.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            return false
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        AppLogger.events.info("Event monitoring started")
        return true
    }

    func startAppTracking() {
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.persistAppUsage()
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        appPersistTimer = timer
    }

    private func persistAppUsage() {
        let today = DateHelper.todayString()
        for (bundleId, data) in appBuffer {
            DatabaseManager.shared.updateAppUsage(
                date: today,
                bundleId: bundleId,
                appName: data.name,
                keystrokes: data.keystrokes,
                mouseClicks: data.clicks
            )
        }
        appBuffer.removeAll()
    }

    private func startRetryTimer() {
        retryCount = 0
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated {
                self.retryCount += 1
                if self.createAndStartEventTap() {
                    AppLogger.events.info("Event monitoring started after permission grant")
                    timer.invalidate()
                    self.retryTimer = nil
                } else if self.retryCount >= self.maxRetries {
                    AppLogger.events.warning("Permission not granted after \(self.maxRetries) retries -- please restart the app")
                    timer.invalidate()
                    self.retryTimer = nil
                }
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        retryTimer = timer
    }

    private func startSleepWakeObservers() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSleep() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }
    }

    private func handleSleep() {
        MouseTracker.shared.persistData()
        KeyboardTracker.shared.persistData()
        persistAppUsage()
    }

    private func handleWake() {
        lastEventTime = Date()
        let today = Self.dateFormatter.string(from: Date())
        if currentDate != today {
            firstActiveAt = nil
            lastActiveAt = nil
            currentDate = today
        }
    }

    func getActivityTimes() -> (first: String?, last: String?) {
        (firstActiveAt, lastActiveAt)
    }

    func getAppUsageSnapshot() -> [String: (name: String, keystrokes: Int, clicks: Int)] {
        appBuffer
    }

    func getAndResetActiveSeconds() -> TimeInterval {
        let seconds = activeSeconds
        activeSeconds = 0
        return seconds
    }

    nonisolated private func handleEvent(type: CGEventType, event: CGEvent) {
        let location = event.location
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let scrollDeltaY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let scrollDeltaX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)

        MainActor.assumeIsolated {
            let now = Date()
            let today = Self.dateFormatter.string(from: now)
            if currentDate != today {
                firstActiveAt = nil
                lastActiveAt = nil
                currentDate = today
            }
            let timeString = Self.timeFormatter.string(from: now)
            if firstActiveAt == nil {
                firstActiveAt = timeString
            }
            lastActiveAt = timeString

            let elapsed = now.timeIntervalSince(lastEventTime)
            if elapsed < idleThreshold {
                activeSeconds += elapsed
            }
            lastEventTime = now

            switch type {
            case .mouseMoved:
                mouseEventCount += 1
                MouseTracker.shared.trackMovement(to: location)

            case .leftMouseDown:
                mouseEventCount += 1
                MouseTracker.shared.trackClick(type: .left, at: location)

            case .rightMouseDown:
                mouseEventCount += 1
                MouseTracker.shared.trackClick(type: .right, at: location)

            case .otherMouseDown:
                mouseEventCount += 1
                MouseTracker.shared.trackClick(type: .middle, at: location)

            case .keyDown:
                keyboardEventCount += 1
                KeyboardTracker.shared.trackKeystroke(keyCode: keyCode, modifierFlags: flags)

            case .scrollWheel:
                mouseEventCount += 1
                MouseTracker.shared.trackScroll(deltaX: scrollDeltaX, deltaY: scrollDeltaY)

            default:
                break
            }

            if let app = NSWorkspace.shared.frontmostApplication,
               let bundleId = app.bundleIdentifier {
                let name = app.localizedName ?? bundleId
                var entry = appBuffer[bundleId] ?? (name: name, keystrokes: 0, clicks: 0)
                entry.name = name

                switch type {
                case .keyDown:
                    entry.keystrokes += 1
                case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                    entry.clicks += 1
                default:
                    break
                }

                appBuffer[bundleId] = entry
            }
        }
    }
}
