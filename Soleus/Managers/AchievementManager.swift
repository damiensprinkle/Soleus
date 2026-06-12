import Foundation
import CoreData

class AchievementManager: ObservableObject {
    @Published var achievements: [Achievement] = []
    var workoutManager: WorkoutManager?

    private let unlockedAchievementsKey = "unlockedAchievements"

    init() {
        loadAchievements()
    }

    private func loadAchievements() {
        guard let url = Bundle.main.url(forResource: "achievements", withExtension: "json") else {
            AppLogger.workout.error("Failed to locate achievements.json in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let achievementsList = try decoder.decode(AchievementsList.self, from: data)
            self.achievements = achievementsList.achievements
            AppLogger.workout.info("Loaded \(achievements.count) achievements")
        } catch {
            AppLogger.workout.error("Failed to load achievements: \(error)")
        }
    }

    func getAchievementProgress() -> [AchievementProgress] {
        let persistedNames = getUnlockedAchievementNames()

        guard workoutManager != nil else {
            return achievements.map { achievement in
                let wasUnlocked = persistedNames.contains(achievement.name)
                return AchievementProgress(achievement: achievement, isUnlocked: wasUnlocked, currentProgress: wasUnlocked ? 1 : 0, targetValue: 1)
            }
        }

        let stats = calculateWorkoutStats()

        return achievements.map { achievement in
            let (isUnlocked, current, target) = checkAchievement(achievement, stats: stats)
            // An achievement stays unlocked once earned, even if history is later cleared
            let finalUnlocked = isUnlocked || persistedNames.contains(achievement.name)
            return AchievementProgress(
                achievement: achievement,
                isUnlocked: finalUnlocked,
                currentProgress: finalUnlocked ? target : current,
                targetValue: target
            )
        }
    }

    /// Returns current workout statistics
    func getWorkoutStats() -> WorkoutStats {
        return calculateWorkoutStats()
    }

    /// Returns personal records from workout history
    func getPersonalRecords() -> PersonalRecords {
        guard let context = workoutManager?.context else {
            return PersonalRecords()
        }

        let fetchRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()

        do {
            let histories = try context.fetch(fetchRequest)

            var records = PersonalRecords()

            for history in histories {
                // Track heaviest weight in single workout
                if Double(history.totalWeightLifted) > records.heaviestWeight {
                    records.heaviestWeight = Double(history.totalWeightLifted)
                }

                // Track most reps in single workout
                if Int(history.repsCompleted) > records.mostReps {
                    records.mostReps = Int(history.repsCompleted)
                }

                // Track furthest distance in single workout
                if Double(history.totalDistance) > records.furthestDistance {
                    records.furthestDistance = Double(history.totalDistance)
                }

                // Track longest workout
                if let timeString = history.workoutTimeToComplete {
                    let workoutMinutes = parseTimeString(timeString) / 60
                    if workoutMinutes > records.longestWorkoutMinutes {
                        records.longestWorkoutMinutes = workoutMinutes
                    }
                }
            }

            return records
        } catch {
            AppLogger.workout.error("Failed to fetch workout history for PRs: \(error)")
            return PersonalRecords()
        }
    }

    /// Returns the start-of-day dates in the current week that have at least
    /// one completed workout. Used by the dashboard "This Week" widget.
    func getWorkoutDaysThisWeek() -> Set<Date> {
        guard let histories = workoutManager?.fetchAllWorkoutHistoryAllTime(),
              let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }

        let calendar = Calendar.current
        var days = Set<Date>()
        for history in histories {
            guard let date = history.workoutDate, weekInterval.contains(date) else { continue }
            days.insert(calendar.startOfDay(for: date))
        }
        return days
    }

    /// Returns the most recently completed workout, if any. Used by the
    /// dashboard "Last Workout" widget.
    func getMostRecentWorkout() -> WorkoutHistory? {
        // fetchAllWorkoutHistoryAllTime sorts by workoutDate descending
        return workoutManager?.fetchAllWorkoutHistoryAllTime()?.first
    }

    /// Returns achievements that were newly unlocked (not previously stored as unlocked)
    func getNewlyUnlockedAchievements() -> [Achievement] {
        let currentProgress = getAchievementProgress()
        let currentlyUnlocked = currentProgress.filter { $0.isUnlocked }.map { $0.achievement }

        // Get previously unlocked achievement names from UserDefaults
        let previouslyUnlockedNames = getUnlockedAchievementNames()

        // Find achievements that are unlocked now but weren't before
        let newlyUnlocked = currentlyUnlocked.filter { achievement in
            !previouslyUnlockedNames.contains(achievement.name)
        }

        // Save the newly unlocked achievements
        if !newlyUnlocked.isEmpty {
            saveUnlockedAchievements(currentlyUnlocked)
        }

        return newlyUnlocked
    }

    private func getUnlockedAchievementNames() -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: unlockedAchievementsKey),
           let names = try? JSONDecoder().decode([String].self, from: data) {
            return Set(names)
        }
        return Set()
    }

    func clearUnlockedAchievements() {
        UserDefaults.standard.removeObject(forKey: unlockedAchievementsKey)
    }

    private func saveUnlockedAchievements(_ achievements: [Achievement]) {
        let names = achievements.map { $0.name }
        if let data = try? JSONEncoder().encode(names) {
            UserDefaults.standard.set(data, forKey: unlockedAchievementsKey)
        }
    }

    private func calculateWorkoutStats() -> WorkoutStats {
        guard let context = workoutManager?.context else {
            return WorkoutStats()
        }

        let fetchRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: true)]

        do {
            let histories = try context.fetch(fetchRequest)

            let totalWorkouts = histories.count
            var totalWeightLifted: Float = 0
            var totalTimeInSeconds: Double = 0
            var totalDistance: Float = 0
            var totalReps: Int32 = 0
            var currentStreak = 0
            var longestStreak = 0
            var workedOutToday = false
            var longestWorkoutInMinutes: Double = 0
            var hasShortWorkout = false

            // Calculate totals
            for history in histories {
                totalWeightLifted += history.totalWeightLifted
                totalDistance += history.totalDistance
                totalReps += history.repsCompleted

                // Parse time string (format: "HH:MM:SS" or "MM:SS")
                if let timeString = history.workoutTimeToComplete {
                    let workoutDuration = parseTimeString(timeString)
                    totalTimeInSeconds += workoutDuration

                    // Track longest workout
                    let workoutMinutes = workoutDuration / 60
                    longestWorkoutInMinutes = max(longestWorkoutInMinutes, workoutMinutes)

                    // Check if any workout is under 2 minutes
                    if workoutMinutes < 2 {
                        hasShortWorkout = true
                    }
                }
            }

            // Calculate streaks
            if !histories.isEmpty {
                let calendar = Calendar.current
                var streak = 1
                var previousDate = histories[0].workoutDate

                for i in 1..<histories.count {
                    if let current = histories[i].workoutDate,
                       let previous = previousDate {
                        let daysBetween = calendar.dateComponents([.day], from: calendar.startOfDay(for: previous), to: calendar.startOfDay(for: current)).day ?? 0

                        if daysBetween == 1 {
                            streak += 1
                        } else if daysBetween > 1 {
                            longestStreak = max(longestStreak, streak)
                            streak = 1
                        }
                    }
                    previousDate = histories[i].workoutDate
                }
                longestStreak = max(longestStreak, streak)

                // Check current streak
                if let lastWorkoutDate = histories.last?.workoutDate {
                    let daysSinceLastWorkout = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastWorkoutDate), to: calendar.startOfDay(for: Date())).day ?? 0
                    currentStreak = daysSinceLastWorkout <= 1 ? streak : 0
                    workedOutToday = daysSinceLastWorkout == 0
                }
            }

            // Calculate weekly and monthly workout counts
            let (workoutsThisWeek, workoutsThisMonth, maxWeek, maxMonth) = calculateWeeklyMonthlyStats(histories: histories)

            return WorkoutStats(
                totalWorkouts: totalWorkouts,
                totalWeightLifted: Double(totalWeightLifted),
                totalTimeInHours: totalTimeInSeconds / 3600,
                totalDistance: Double(totalDistance),
                totalReps: Int(totalReps),
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                workedOutToday: workedOutToday,
                longestWorkoutInMinutes: longestWorkoutInMinutes,
                hasShortWorkout: hasShortWorkout,
                workoutsThisWeek: workoutsThisWeek,
                workoutsThisMonth: workoutsThisMonth,
                maxWorkoutsInAnyWeek: maxWeek,
                maxWorkoutsInAnyMonth: maxMonth
            )
        } catch {
            AppLogger.workout.error("Failed to fetch workout history: \(error)")
            return WorkoutStats()
        }
    }

    private func parseTimeString(_ timeString: String) -> Double {
        let components = timeString.split(separator: ":").compactMap { Double($0) }
        if components.count == 3 {
            // HH:MM:SS
            return components[0] * 3600 + components[1] * 60 + components[2]
        } else if components.count == 2 {
            // MM:SS
            return components[0] * 60 + components[1]
        }
        return 0
    }

    private func calculateWeeklyMonthlyStats(histories: [WorkoutHistory]) -> (thisWeek: Int, thisMonth: Int, maxWeek: Int, maxMonth: Int) {
        guard !histories.isEmpty else { return (0, 0, 0, 0) }

        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now

        var workoutsThisWeek = 0
        var workoutsThisMonth = 0

        // Track workouts per week and month
        var weekCounts: [Date: Int] = [:]
        var monthCounts: [Date: Int] = [:]

        for history in histories {
            guard let workoutDate = history.workoutDate else { continue }

            // Count workouts in current week
            if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: workoutDate),
               weekInterval.start == currentWeekStart {
                workoutsThisWeek += 1
            }

            // Count workouts in current month
            if let monthInterval = calendar.dateInterval(of: .month, for: workoutDate),
               monthInterval.start == currentMonthStart {
                workoutsThisMonth += 1
            }

            // Track all weeks and months for max calculation
            if let weekStart = calendar.dateInterval(of: .weekOfYear, for: workoutDate)?.start {
                weekCounts[weekStart, default: 0] += 1
            }

            if let monthStart = calendar.dateInterval(of: .month, for: workoutDate)?.start {
                monthCounts[monthStart, default: 0] += 1
            }
        }

        let maxWorkoutsInWeek = weekCounts.values.max() ?? 0
        let maxWorkoutsInMonth = monthCounts.values.max() ?? 0

        return (workoutsThisWeek, workoutsThisMonth, maxWorkoutsInWeek, maxWorkoutsInMonth)
    }

    private func checkAchievement(_ achievement: Achievement, stats: WorkoutStats) -> (isUnlocked: Bool, current: Double, target: Double) {
        let desc = achievement.description.lowercased()

        // Workout count achievements
        if desc.contains("first workout") {
            return (stats.totalWorkouts >= 1, Double(stats.totalWorkouts), 1)
        } else if desc.contains("10th workout") {
            return (stats.totalWorkouts >= 10, Double(stats.totalWorkouts), 10)
        } else if desc.contains("25th workout") {
            return (stats.totalWorkouts >= 25, Double(stats.totalWorkouts), 25)
        } else if desc.contains("50th workout") {
            return (stats.totalWorkouts >= 50, Double(stats.totalWorkouts), 50)
        } else if desc.contains("100th workout") {
            return (stats.totalWorkouts >= 100, Double(stats.totalWorkouts), 100)
        }

        // Weight lifted achievements
        else if desc.contains("1,000 pounds") {
            return (stats.totalWeightLifted >= 1000, stats.totalWeightLifted, 1000)
        } else if desc.contains("10,000 pounds") {
            return (stats.totalWeightLifted >= 10000, stats.totalWeightLifted, 10000)
        } else if desc.contains("50,000 pounds") {
            return (stats.totalWeightLifted >= 50000, stats.totalWeightLifted, 50000)
        } else if desc.contains("100,000 pounds") {
            return (stats.totalWeightLifted >= 100000, stats.totalWeightLifted, 100000)
        } else if desc.contains("500,000 pounds") {
            return (stats.totalWeightLifted >= 500000, stats.totalWeightLifted, 500000)
        } else if desc.contains("1,000,000 pounds") {
            return (stats.totalWeightLifted >= 1000000, stats.totalWeightLifted, 1000000)
        } else if desc.contains("5,000,000 pounds") {
            return (stats.totalWeightLifted >= 5000000, stats.totalWeightLifted, 5000000)
        } else if desc.contains("10,000,000 pounds") {
            return (stats.totalWeightLifted >= 10000000, stats.totalWeightLifted, 10000000)
        }

        // Time achievements
        else if desc.contains("1 hour total") {
            return (stats.totalTimeInHours >= 1, stats.totalTimeInHours, 1)
        } else if desc.contains("10 hours total") {
            return (stats.totalTimeInHours >= 10, stats.totalTimeInHours, 10)
        } else if desc.contains("100 hours total") {
            return (stats.totalTimeInHours >= 100, stats.totalTimeInHours, 100)
        }

        // Distance achievements
        else if desc.contains("1 mile") && !desc.contains("10") {
            return (stats.totalDistance >= 1, stats.totalDistance, 1)
        } else if desc.contains("10 miles") {
            return (stats.totalDistance >= 10, stats.totalDistance, 10)
        } else if desc.contains("100 miles") {
            return (stats.totalDistance >= 100, stats.totalDistance, 100)
        } else if desc.contains("1000 miles") {
            return (stats.totalDistance >= 1000, stats.totalDistance, 1000)
        }

        // Streak achievements
        else if desc.contains("2 days in a row") {
            return (stats.longestStreak >= 2, Double(stats.longestStreak), 2)
        } else if desc.contains("5 days in a row") {
            return (stats.longestStreak >= 5, Double(stats.longestStreak), 5)
        } else if desc.contains("7 days in a row") {
            return (stats.longestStreak >= 7, Double(stats.longestStreak), 7)
        } else if desc.contains("14 days in a row") {
            return (stats.longestStreak >= 14, Double(stats.longestStreak), 14)
        } else if desc.contains("30 days in a row") {
            return (stats.longestStreak >= 30, Double(stats.longestStreak), 30)
        } else if desc.contains("100 days in a row") {
            return (stats.longestStreak >= 100, Double(stats.longestStreak), 100)
        }

        // Workout duration achievements
        else if desc.contains("longer than 1 hour") {
            let isUnlocked = stats.longestWorkoutInMinutes >= 60
            return (isUnlocked, stats.longestWorkoutInMinutes, 60)
        } else if desc.contains("under 2 minutes") {
            return (stats.hasShortWorkout, stats.hasShortWorkout ? 1 : 0, 1)
        }

        // Rep achievements
        else if desc.contains("1,000 total reps") {
            return (stats.totalReps >= 1000, Double(stats.totalReps), 1000)
        } else if desc.contains("10,000 total reps") {
            return (stats.totalReps >= 10000, Double(stats.totalReps), 10000)
        } else if desc.contains("50,000 total reps") {
            return (stats.totalReps >= 50000, Double(stats.totalReps), 50000)
        } else if desc.contains("100,000 total reps") {
            return (stats.totalReps >= 100000, Double(stats.totalReps), 100000)
        }

        // Weekly achievements (based on best week ever, not just current week)
        else if desc.contains("3 workouts in a week") {
            return (stats.maxWorkoutsInAnyWeek >= 3, Double(stats.maxWorkoutsInAnyWeek), 3)
        } else if desc.contains("5 workouts in a week") {
            return (stats.maxWorkoutsInAnyWeek >= 5, Double(stats.maxWorkoutsInAnyWeek), 5)
        }

        // Monthly achievements (based on best month ever, not just current month)
        else if desc.contains("20 workouts in a month") {
            return (stats.maxWorkoutsInAnyMonth >= 20, Double(stats.maxWorkoutsInAnyMonth), 20)
        }

        // Perfect month achievement (placeholder - requires goal tracking)
        else if desc.contains("perfect month") {
            // This would require tracking weekly goals - for now return not unlocked
            return (false, 0, 1)
        }

        // Default: not unlocked
        return (false, 0, 1)
    }
}

struct WorkoutStats {
    var totalWorkouts: Int = 0
    var totalWeightLifted: Double = 0
    var totalTimeInHours: Double = 0
    var totalDistance: Double = 0
    var totalReps: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var workedOutToday: Bool = false
    var longestWorkoutInMinutes: Double = 0
    var hasShortWorkout: Bool = false // < 2 minutes
    var workoutsThisWeek: Int = 0 // Current week
    var workoutsThisMonth: Int = 0 // Current month
    var maxWorkoutsInAnyWeek: Int = 0 // Best week ever
    var maxWorkoutsInAnyMonth: Int = 0 // Best month ever
}

struct PersonalRecords {
    var heaviestWeight: Double = 0 // Single workout
    var mostReps: Int = 0 // Single workout
    var longestWorkoutMinutes: Double = 0 // Single workout
    var furthestDistance: Double = 0 // Single workout
}
