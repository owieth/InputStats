@preconcurrency import Cocoa
import CoreGraphics

@MainActor
class EventMonitor {
    static let shared = EventMonitor()

    private var eventTap: CFMachPort?

    private init() {}

    func start() {
        guard checkAccessibilityPermission() else {
            print("⚠️ Accessibility permission not granted")
            print("📋 Please enable InputMetrics in System Settings > Privacy & Security > Accessibility")
            requestAccessibilityPermission()

            // Show alert to user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "InputMetrics needs Accessibility permission to track mouse and keyboard events.\n\n1. Open System Settings\n2. Go to Privacy & Security > Accessibility\n3. Enable InputMetrics\n4. Restart the app"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "OK")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") else { return }
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        let eventMask = (1 << CGEventType.mouseMoved.rawValue) |
                       (1 << CGEventType.leftMouseDown.rawValue) |
                       (1 << CGEventType.rightMouseDown.rawValue) |
                       (1 << CGEventType.otherMouseDown.rawValue) |
                       (1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = EventMonitor.shared.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                EventMonitor.shared.handleEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap")
            return
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("Event monitoring started")
    }

    func stop() {
        guard let eventTap = eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)
        CFMachPortInvalidate(eventTap)
        self.eventTap = nil
        print("Event monitoring stopped")
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        // Extract all values synchronously before the callback returns,
        // since the CGEvent may be deallocated after the callback exits.
        let location = event.location
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        Task { @MainActor in
            switch type {
            case .mouseMoved:
                MouseTracker.shared.trackMovement(to: location)

            case .leftMouseDown:
                MouseTracker.shared.trackClick(type: .left, at: location)

            case .rightMouseDown:
                MouseTracker.shared.trackClick(type: .right, at: location)

            case .otherMouseDown:
                MouseTracker.shared.trackClick(type: .middle, at: location)

            case .keyDown:
                KeyboardTracker.shared.trackKeystroke(keyCode: keyCode, modifierFlags: flags)

            default:
                break
            }
        }
    }

    nonisolated private func checkAccessibilityPermission() -> Bool {
        let optionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [optionKey: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    nonisolated private func requestAccessibilityPermission() {
        let optionKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [optionKey: true]
        AXIsProcessTrustedWithOptions(options)
    }
}
