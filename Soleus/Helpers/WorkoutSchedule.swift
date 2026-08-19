import Foundation

/// Parses and serializes the `Workouts.scheduledDays` attribute — a
/// comma-separated list of Calendar weekday numbers (1 = Sunday … 7 = Saturday).
enum WorkoutSchedule {
    static func parse(_ stored: String?) -> Set<Int> {
        guard let stored, !stored.isEmpty else { return [] }
        return Set(stored.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
    }

    /// Returns nil for an empty set so unscheduled workouts keep a nil attribute.
    static func serialize(_ days: Set<Int>) -> String? {
        guard !days.isEmpty else { return nil }
        return days.sorted().map(String.init).joined(separator: ",")
    }

    /// The seven weekday numbers ordered per the user's calendar, starting at `firstWeekday`.
    static func orderedWeekdays(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }

    static func weekdayName(_ weekday: Int, calendar: Calendar = .current) -> String {
        guard (1...7).contains(weekday) else { return "" }
        return calendar.weekdaySymbols[weekday - 1]
    }

    static func shortWeekdayName(_ weekday: Int, calendar: Calendar = .current) -> String {
        guard (1...7).contains(weekday) else { return "" }
        return calendar.shortWeekdaySymbols[weekday - 1]
    }
}
