import Cocoa
import Carbon.HIToolbox

@MainActor
class HotkeyManager {
    static let shared = HotkeyManager()

    private var globalMonitor: Any?

    private init() {}

    func start(toggleAction: @escaping () -> Void) {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                if self.matchesHotkey(event) {
                    toggleAction()
                }
            }
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func matchesHotkey(_ event: NSEvent) -> Bool {
        let requiredFlags: NSEvent.ModifierFlags = [.option, .shift]
        let keyCode = Int(event.keyCode)

        let hasRequiredFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(requiredFlags)
        let isCorrectKey = keyCode == kVK_ANSI_I

        return hasRequiredFlags && isCorrectKey
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
