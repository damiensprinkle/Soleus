import Foundation

/// The widgets that can appear on the dashboard. Raw values are persisted in
/// UserDefaults, so existing cases must never be renamed.
enum DashboardWidget: String, CaseIterable, Codable, Identifiable {
    case todaysWorkout
    case thisWeek
    case lastWorkout
    case achievements
    case streaks
    case lifetimeStats
    case personalRecords

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .todaysWorkout: return "Today's Workout"
        case .thisWeek: return "This Week"
        case .lastWorkout: return "Last Workout"
        case .achievements: return "Achievements"
        case .streaks: return "Workout Streaks"
        case .lifetimeStats: return "Lifetime Stats"
        case .personalRecords: return "Personal Records"
        }
    }

    var icon: String {
        switch self {
        case .todaysWorkout: return "calendar.badge.clock"
        case .thisWeek: return "calendar"
        case .lastWorkout: return "clock.arrow.circlepath"
        case .achievements: return "trophy.fill"
        case .streaks: return "flame.fill"
        case .lifetimeStats: return "chart.line.uptrend.xyaxis"
        case .personalRecords: return "medal.fill"
        }
    }
}

/// A widget plus its user-chosen visibility. Order within the stored array is
/// the display order on the dashboard.
struct DashboardWidgetSetting: Codable, Identifiable, Equatable {
    let widget: DashboardWidget
    var isVisible: Bool

    var id: String { widget.id }
}

/// Loads and saves the dashboard widget configuration. Tolerates configs
/// written by other app versions: unknown widgets fail the decode and fall
/// back to defaults, while widgets added after the config was saved are
/// appended as visible.
enum DashboardConfigStore {
    static let storageKey = "dashboardWidgetConfig"

    static var defaults: [DashboardWidgetSetting] {
        DashboardWidget.allCases.map { DashboardWidgetSetting(widget: $0, isVisible: true) }
    }

    static func load(from userDefaults: UserDefaults = .standard) -> [DashboardWidgetSetting] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return defaults
        }
        guard let stored = try? JSONDecoder().decode([DashboardWidgetSetting].self, from: data) else {
            AppLogger.ui.warning("Could not decode dashboard widget config, using defaults")
            return defaults
        }
        return reconcile(stored)
    }

    static func save(_ settings: [DashboardWidgetSetting], to userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(settings) else {
            AppLogger.ui.error("Failed to encode dashboard widget config")
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    /// Keeps the user's saved order, drops duplicate entries, and appends any
    /// widgets introduced after the config was saved (visible by default).
    static func reconcile(_ stored: [DashboardWidgetSetting]) -> [DashboardWidgetSetting] {
        var seen = Set<DashboardWidget>()
        var result = stored.filter { seen.insert($0.widget).inserted }
        let missing = DashboardWidget.allCases.filter { !seen.contains($0) }
        result.append(contentsOf: missing.map { DashboardWidgetSetting(widget: $0, isVisible: true) })
        return result
    }
}
