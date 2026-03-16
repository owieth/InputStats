import Foundation

enum DataRetentionPeriod: String, CaseIterable, Identifiable {
    case threeMonths = "3months"
    case sixMonths = "6months"
    case oneYear = "1year"
    case forever = "forever"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .oneYear: return "1 year"
        case .forever: return "Forever"
        }
    }

    var days: Int? {
        switch self {
        case .threeMonths: return 90
        case .sixMonths: return 180
        case .oneYear: return 365
        case .forever: return nil
        }
    }
}

@MainActor
class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var distanceUnit: DistanceUnit {
        didSet {
            UserDefaults.standard.set(distanceUnit.rawValue, forKey: "distanceUnit")
        }
    }

    @Published var showLiveStats: Bool {
        didSet {
            UserDefaults.standard.set(showLiveStats, forKey: "showLiveStats")
        }
    }

    @Published var hotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hotkeyEnabled, forKey: "hotkeyEnabled")
        }
    }

    @Published var dataRetentionPeriod: DataRetentionPeriod {
        didSet {
            UserDefaults.standard.set(dataRetentionPeriod.rawValue, forKey: "dataRetentionPeriod")
        }
    }

    @Published var goalConfig: GoalConfig {
        didSet {
            if let data = try? JSONEncoder().encode(goalConfig) {
                UserDefaults.standard.set(data, forKey: "goalConfig")
            }
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    @Published var dismissedKeyboardPermissionWarning: Bool {
        didSet {
            UserDefaults.standard.set(dismissedKeyboardPermissionWarning, forKey: "dismissedKeyboardPermissionWarning")
        }
    }

    private init() {
        let savedUnit = UserDefaults.standard.string(forKey: "distanceUnit") ?? DistanceUnit.metric.rawValue
        self.distanceUnit = DistanceUnit(rawValue: savedUnit) ?? .metric
        self.showLiveStats = UserDefaults.standard.object(forKey: "showLiveStats") as? Bool ?? true
        self.hotkeyEnabled = UserDefaults.standard.object(forKey: "hotkeyEnabled") as? Bool ?? true

        let savedRetention = UserDefaults.standard.string(forKey: "dataRetentionPeriod") ?? "forever"
        self.dataRetentionPeriod = DataRetentionPeriod(rawValue: savedRetention) ?? .forever

        if let data = UserDefaults.standard.data(forKey: "goalConfig"),
           let config = try? JSONDecoder().decode(GoalConfig.self, from: data) {
            self.goalConfig = config
        } else {
            self.goalConfig = .default
        }

        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? false
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.dismissedKeyboardPermissionWarning = UserDefaults.standard.bool(forKey: "dismissedKeyboardPermissionWarning")
    }
}
