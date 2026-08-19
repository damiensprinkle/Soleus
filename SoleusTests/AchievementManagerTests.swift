import XCTest
import CoreData
@testable import Soleus

final class AchievementManagerTests: XCTestCase {
    var sut: AchievementManager!
    var workoutManager: WorkoutManager!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController.forUITesting
        context = persistence.container.viewContext
        workoutManager = WorkoutManager()
        workoutManager.context = context

        sut = AchievementManager()
        sut.workoutManager = workoutManager
    }

    override func tearDown() {
        let fetchRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        if let histories = try? context.fetch(fetchRequest) {
            histories.forEach { context.delete($0) }
            try? context.save()
        }
        let workoutRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
        if let workouts = try? context.fetch(workoutRequest) {
            workouts.forEach { context.delete($0) }
            try? context.save()
        }
        UserDefaults.standard.removeObject(forKey: "unlockedAchievements")
        sut = nil
        workoutManager = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func setAchievement(name: String, description: String, trophy: TrophyType = .bronze) {
        sut.achievements = [Achievement(name: name, description: description, trophy: trophy)]
    }

    @discardableResult
    private func makeHistory(
        totalWeightLifted: Float = 0,
        repsCompleted: Int32 = 0,
        totalDistance: Float = 0,
        workoutTimeToComplete: String? = "00:30:00",
        workoutDate: Date = Date()
    ) -> WorkoutHistory {
        let history = WorkoutHistory(context: context)
        history.id = UUID()
        history.totalWeightLifted = totalWeightLifted
        history.repsCompleted = repsCompleted
        history.totalDistance = totalDistance
        history.workoutTimeToComplete = workoutTimeToComplete
        history.workoutDate = workoutDate
        try? context.save()
        return history
    }

    private func consecutiveDates(count: Int, endingToday: Bool = true) -> [Date] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        let offset = endingToday ? -(count - 1) : -count
        return (0..<count).map { i in
            calendar.date(byAdding: .day, value: offset + i, to: anchor)!
        }
    }

    // MARK: - No WorkoutManager

    func testGetAchievementProgress_NoWorkoutManager_AllLocked() {
        setAchievement(name: "First Step Forward", description: "Completed your first workout")
        sut.workoutManager = nil

        let progress = sut.getAchievementProgress()

        XCTAssertEqual(progress.count, 1)
        XCTAssertFalse(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].currentProgress, 0)
        XCTAssertEqual(progress[0].targetValue, 1)
    }

    // MARK: - Workout Count Achievements

    func testFirstWorkout_Unlocked_WhenOneWorkoutExists() {
        setAchievement(name: "First Step Forward", description: "Completed your first workout")
        makeHistory()

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1)
    }

    func testFirstWorkout_Locked_WhenNoWorkoutsExist() {
        setAchievement(name: "First Step Forward", description: "Completed your first workout")

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].currentProgress, 0)
    }

    func test10thWorkout_Unlocked_AtExactlyTen() {
        setAchievement(name: "Double-Digit Dynamo", description: "Completed your 10th workout")
        for _ in 0..<10 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 10)
    }

    func test10thWorkout_Locked_AtNine() {
        setAchievement(name: "Double-Digit Dynamo", description: "Completed your 10th workout")
        for _ in 0..<9 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].currentProgress, 9)
    }

    func test25thWorkout_Unlocked_AtExactlyTwentyFive() {
        setAchievement(name: "Quarter Century Crusher", description: "Completed your 25th workout")
        for _ in 0..<25 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 25)
    }

    func test50thWorkout_Unlocked_AtExactlyFifty() {
        setAchievement(name: "Halfway Heavy Hitter", description: "Completed your 50th workout")
        for _ in 0..<50 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func test100thWorkout_Unlocked_AtExactlyOneHundred() {
        setAchievement(name: "Centurion Athlete", description: "Completed your 100th workout")
        for _ in 0..<100 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 100)
    }

    func test100thWorkout_Locked_AtNinetyNine() {
        setAchievement(name: "Centurion Athlete", description: "Completed your 100th workout")
        for _ in 0..<99 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    // MARK: - Weight Lifted Achievements

    func test1000PoundsLifted_Unlocked() {
        setAchievement(name: "Featherweight Lifter", description: "Lifted 1,000 pounds total")
        makeHistory(totalWeightLifted: 1000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1000)
    }

    func test1000PoundsLifted_Locked_WhenBelow() {
        setAchievement(name: "Featherweight Lifter", description: "Lifted 1,000 pounds total")
        makeHistory(totalWeightLifted: 999)

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test10000PoundsLifted_Unlocked() {
        setAchievement(name: "Iron Initiate", description: "Lifted 10,000 pounds total")
        makeHistory(totalWeightLifted: 10000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 10000)
    }

    func test50000PoundsLifted_Unlocked() {
        setAchievement(name: "Steel Specialist", description: "Lifted 50,000 pounds total")
        makeHistory(totalWeightLifted: 50000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func test100000PoundsLifted_Unlocked() {
        setAchievement(name: "Titan Trainee", description: "Lifted 100,000 pounds total")
        makeHistory(totalWeightLifted: 100000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func test500000PoundsLifted_Unlocked() {
        setAchievement(name: "Colossus Mode", description: "Lifted 500,000 pounds total")
        makeHistory(totalWeightLifted: 500000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func test1MillionPoundsLifted_Unlocked() {
        setAchievement(name: "Millennium Muscle", description: "Lifted 1,000,000 pounds total")
        makeHistory(totalWeightLifted: 1_000_000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1_000_000)
    }

    func test5MillionPoundsLifted_Unlocked() {
        setAchievement(name: "Five-Million Force", description: "Lifted 5,000,000 pounds total")
        makeHistory(totalWeightLifted: 5_000_000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func test10MillionPoundsLifted_Unlocked() {
        setAchievement(name: "Ten-Million Titan", description: "Lifted 10,000,000 pounds total")
        makeHistory(totalWeightLifted: 10_000_000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 10_000_000)
    }

    func testWeight_AccumulatesAcrossMultipleWorkouts() {
        setAchievement(name: "Featherweight Lifter", description: "Lifted 1,000 pounds total")
        makeHistory(totalWeightLifted: 600)
        makeHistory(totalWeightLifted: 400)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    // MARK: - Time Achievements

    func test1HourTotal_Unlocked_HHMMSSFormat() {
        setAchievement(name: "One-Hour Warrior", description: "Exercised for 1 hour total")
        makeHistory(workoutTimeToComplete: "01:00:00")

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1)
    }

    func test1HourTotal_Unlocked_MMSSFormat() {
        setAchievement(name: "One-Hour Warrior", description: "Exercised for 1 hour total")
        makeHistory(workoutTimeToComplete: "60:00")

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func test1HourTotal_Locked_WhenUnder1Hour() {
        setAchievement(name: "One-Hour Warrior", description: "Exercised for 1 hour total")
        makeHistory(workoutTimeToComplete: "00:59:59")

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test1HourTotal_Locked_WhenTimeStringNil() {
        setAchievement(name: "One-Hour Warrior", description: "Exercised for 1 hour total")
        makeHistory(workoutTimeToComplete: nil)

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test10HoursTotal_Unlocked_AcrossMultipleWorkouts() {
        setAchievement(name: "Endurance Engine", description: "Exercised for 10 hours total")
        for _ in 0..<10 { makeHistory(workoutTimeToComplete: "01:00:00") }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 10)
    }

    func test100HoursTotal_Unlocked_AcrossOneHundredWorkouts() {
        setAchievement(name: "Time-Forged Athlete", description: "Exercised for 100 hours total")
        for _ in 0..<100 { makeHistory(workoutTimeToComplete: "01:00:00") }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 100)
    }

    // MARK: - Distance Achievements

    func test1Mile_Unlocked() {
        setAchievement(name: "First Mile Milestone", description: "Traveled 1 mile")
        makeHistory(totalDistance: 1)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1)
    }

    func test1Mile_Locked_WhenBelow() {
        setAchievement(name: "First Mile Milestone", description: "Traveled 1 mile")
        makeHistory(totalDistance: 0.9)

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test10Miles_Unlocked() {
        setAchievement(name: "Trail Trekker", description: "Traveled 10 miles")
        makeHistory(totalDistance: 10)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 10)
    }

    func test100Miles_Unlocked() {
        setAchievement(name: "Centurion Strider", description: "Traveled 100 miles")
        makeHistory(totalDistance: 100)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 100)
    }

    func test1000Miles_Unlocked() {
        setAchievement(name: "Pathfinder Prodigy", description: "Traveled 1000 miles")
        makeHistory(totalDistance: 1000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1000)
    }

    func testDistance_AccumulatesAcrossWorkouts() {
        setAchievement(name: "Trail Trekker", description: "Traveled 10 miles")
        makeHistory(totalDistance: 6)
        makeHistory(totalDistance: 4)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    // MARK: - Streak Achievements

    func test2DayStreak_Unlocked_WhenConsecutive() {
        setAchievement(name: "Spark Starter", description: "Logged workouts 2 days in a row")
        consecutiveDates(count: 2).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 2)
    }

    func test2DayStreak_Locked_WhenGapExists() {
        setAchievement(name: "Spark Starter", description: "Logged workouts 2 days in a row")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        makeHistory(workoutDate: twoDaysAgo)
        makeHistory(workoutDate: today)

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test5DayStreak_Unlocked() {
        setAchievement(name: "Heatwave", description: "Logged workouts 5 days in a row")
        consecutiveDates(count: 5).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 5)
    }

    func test5DayStreak_Locked_AtFour() {
        setAchievement(name: "Heatwave", description: "Logged workouts 5 days in a row")
        consecutiveDates(count: 4).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test7DayStreak_Unlocked() {
        setAchievement(name: "One-Week Warrior", description: "Logged workouts 7 days in a row")
        consecutiveDates(count: 7).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 7)
    }

    func test14DayStreak_Unlocked() {
        setAchievement(name: "Two-Week Titan", description: "Logged workouts 14 days in a row")
        consecutiveDates(count: 14).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 14)
    }

    func test14DayStreak_Locked_AtThirteen() {
        setAchievement(name: "Two-Week Titan", description: "Logged workouts 14 days in a row")
        consecutiveDates(count: 13).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test30DayStreak_Unlocked() {
        setAchievement(name: "Consistency Conqueror", description: "Logged workouts 30 days in a row")
        consecutiveDates(count: 30).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 30)
    }

    func test100DayStreak_Unlocked() {
        setAchievement(name: "Unbreakable Streaker", description: "Logged workouts 100 days in a row")
        consecutiveDates(count: 100).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 100)
    }

    func test100DayStreak_Locked_AtNinetyNine() {
        setAchievement(name: "Unbreakable Streaker", description: "Logged workouts 100 days in a row")
        consecutiveDates(count: 99).forEach { makeHistory(workoutDate: $0) }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func testStreak_BrokenAndRestarted_UsesLongestStreak() {
        setAchievement(name: "Heatwave", description: "Logged workouts 5 days in a row")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // 5-day streak 3 weeks ago
        for i in stride(from: -25, through: -21, by: 1) {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: today)!)
        }
        // Only 2 days this week
        makeHistory(workoutDate: calendar.date(byAdding: .day, value: -1, to: today)!)
        makeHistory(workoutDate: today)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    // MARK: - Workout Duration Achievements

    func testWorkoutLongerThan1Hour_Unlocked_WhenExactly60Minutes() {
        setAchievement(name: "Marathon Mindset", description: "Complete a workout longer than 1 hour")
        makeHistory(workoutTimeToComplete: "01:00:00")

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 60)
    }

    func testWorkoutLongerThan1Hour_Unlocked_WhenOver60Minutes() {
        setAchievement(name: "Marathon Mindset", description: "Complete a workout longer than 1 hour")
        makeHistory(workoutTimeToComplete: "01:30:00")

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func testWorkoutLongerThan1Hour_Locked_WhenUnder60Minutes() {
        setAchievement(name: "Marathon Mindset", description: "Complete a workout longer than 1 hour")
        makeHistory(workoutTimeToComplete: "00:45:00")

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func testWorkoutUnder2Minutes_Unlocked_WhenShortWorkoutExists() {
        setAchievement(name: "Did You Even Lift?", description: "Logged a workout under 2 minutes")
        makeHistory(workoutTimeToComplete: "01:30") // 1m 30s in MM:SS

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1)
    }

    func testWorkoutUnder2Minutes_Locked_WhenAllWorkoutsLong() {
        setAchievement(name: "Did You Even Lift?", description: "Logged a workout under 2 minutes")
        makeHistory(workoutTimeToComplete: "00:02:00") // exactly 2 minutes

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func testWorkoutUnder2Minutes_Unlocked_WhenAtLeastOneShortAmongMany() {
        setAchievement(name: "Did You Even Lift?", description: "Logged a workout under 2 minutes")
        makeHistory(workoutTimeToComplete: "01:00:00")
        makeHistory(workoutTimeToComplete: "00:30:00")
        makeHistory(workoutTimeToComplete: "01:00") // 1 minute — under 2

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    // MARK: - Rep Achievements

    func test1000TotalReps_Unlocked() {
        setAchievement(name: "Rep Rookie", description: "Completed 1,000 total reps")
        makeHistory(repsCompleted: 1000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 1000)
    }

    func test1000TotalReps_Locked_WhenBelow() {
        setAchievement(name: "Rep Rookie", description: "Completed 1,000 total reps")
        makeHistory(repsCompleted: 999)

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test10000TotalReps_Unlocked() {
        setAchievement(name: "Repetition Renegade", description: "Completed 10,000 total reps")
        makeHistory(repsCompleted: 10000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 10000)
    }

    func test50000TotalReps_Unlocked() {
        setAchievement(name: "Volume Vanguard", description: "Completed 50,000 total reps")
        makeHistory(repsCompleted: 50000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 50000)
    }

    func test100000TotalReps_Unlocked() {
        setAchievement(name: "Master of Motion", description: "Completed 100,000 total reps")
        makeHistory(repsCompleted: 100000)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 100000)
    }

    func testReps_AccumulatesAcrossWorkouts() {
        setAchievement(name: "Rep Rookie", description: "Completed 1,000 total reps")
        makeHistory(repsCompleted: 600)
        makeHistory(repsCompleted: 400)

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    // MARK: - Weekly Achievements

    func test3WorkoutsInAWeek_Unlocked() {
        setAchievement(name: "Weekly Grinder", description: "3 workouts in a week")
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        for i in 0..<3 {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: weekStart)!)
        }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 3)
    }

    func test3WorkoutsInAWeek_Locked_WhenOnly2InBestWeek() {
        setAchievement(name: "Weekly Grinder", description: "3 workouts in a week")
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        makeHistory(workoutDate: weekStart)
        makeHistory(workoutDate: calendar.date(byAdding: .day, value: 1, to: weekStart)!)

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test3WorkoutsInAWeek_Unlocked_BasedOnPastBestWeek() {
        setAchievement(name: "Weekly Grinder", description: "3 workouts in a week")
        let calendar = Calendar.current
        let pastWeek = calendar.date(byAdding: .weekOfYear, value: -2, to: Date())!
        let pastWeekStart = calendar.dateInterval(of: .weekOfYear, for: pastWeek)!.start
        for i in 0..<3 {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: pastWeekStart)!)
        }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    func test5WorkoutsInAWeek_Unlocked() {
        setAchievement(name: "Relentless Rhythm", description: "5 workouts in a week")
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        for i in 0..<5 {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: weekStart)!)
        }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 5)
    }

    func test5WorkoutsInAWeek_Locked_AtFour() {
        setAchievement(name: "Relentless Rhythm", description: "5 workouts in a week")
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        for i in 0..<4 {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: weekStart)!)
        }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    // MARK: - Monthly Achievements

    func test20WorkoutsInAMonth_Unlocked() {
        setAchievement(name: "Calendar Crusher", description: "20 workouts in a month")
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())!.start
        for i in 0..<20 {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: monthStart)!)
        }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].targetValue, 20)
    }

    func test20WorkoutsInAMonth_Locked_AtNineteen() {
        setAchievement(name: "Calendar Crusher", description: "20 workouts in a month")
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: Date())!.start
        for i in 0..<19 {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: monthStart)!)
        }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
    }

    func test20WorkoutsInAMonth_Unlocked_BasedOnBestMonth() {
        setAchievement(name: "Calendar Crusher", description: "20 workouts in a month")
        let calendar = Calendar.current
        let pastMonth = calendar.date(byAdding: .month, value: -2, to: Date())!
        let pastMonthStart = calendar.dateInterval(of: .month, for: pastMonth)!.start
        for i in 0..<20 {
            makeHistory(workoutDate: calendar.date(byAdding: .day, value: i, to: pastMonthStart)!)
        }

        let progress = sut.getAchievementProgress()

        XCTAssertTrue(progress[0].isUnlocked)
    }

    // MARK: - Perfect Month Achievement

    func testPerfectMonth_AlwaysLocked() {
        setAchievement(name: "Month of Mastery", description: "Perfect month (met your goal every week)")
        for _ in 0..<30 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertFalse(progress[0].isUnlocked)
        XCTAssertEqual(progress[0].currentProgress, 0)
    }

    // MARK: - Progress Percentage

    func testProgressPercentage_HalfwayToTarget() {
        setAchievement(name: "Double-Digit Dynamo", description: "Completed your 10th workout")
        for _ in 0..<5 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertEqual(progress[0].progressPercentage, 50.0, accuracy: 0.001)
        XCTAssertFalse(progress[0].isUnlocked)
    }

    func testProgressPercentage_CappedAt100WhenExceeded() {
        setAchievement(name: "First Step Forward", description: "Completed your first workout")
        for _ in 0..<5 { makeHistory() }

        let progress = sut.getAchievementProgress()

        XCTAssertEqual(progress[0].progressPercentage, 100.0)
        XCTAssertTrue(progress[0].isUnlocked)
    }

    func testProgressPercentage_ZeroWhenNoProgress() {
        setAchievement(name: "Featherweight Lifter", description: "Lifted 1,000 pounds total")

        let progress = sut.getAchievementProgress()

        XCTAssertEqual(progress[0].progressPercentage, 0.0)
    }

    // MARK: - Scheduled Streaks

    /// Creates a workout scheduled on the weekdays of the given dates.
    private func makeScheduledWorkout(onWeekdaysOf dates: [Date]) {
        let calendar = Calendar.current
        let weekdays = Set(dates.map { calendar.component(.weekday, from: $0) })
        let workout = Workouts(context: context)
        workout.id = UUID()
        workout.name = "Scheduled Workout"
        workout.orderIndex = 0
        workout.scheduledDays = WorkoutSchedule.serialize(weekdays)
        try? context.save()
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: Date()))!
    }

    func testStreak_WithSchedule_UnscheduledRestDayDoesNotBreakStreak() {
        // Worked out 2 days ago and today; the rest day in between is unscheduled
        makeHistory(workoutDate: daysAgo(2))
        makeHistory(workoutDate: daysAgo(0))
        makeScheduledWorkout(onWeekdaysOf: [daysAgo(2), daysAgo(0)])

        let stats = sut.getWorkoutStats()

        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.longestStreak, 2)
    }

    func testStreak_WithSchedule_MissedScheduledDayBreaksStreak() {
        // The day in between was scheduled but skipped
        makeHistory(workoutDate: daysAgo(2))
        makeHistory(workoutDate: daysAgo(0))
        makeScheduledWorkout(onWeekdaysOf: [daysAgo(1)])

        let stats = sut.getWorkoutStats()

        XCTAssertEqual(stats.currentStreak, 1)
    }

    func testCurrentStreak_WithSchedule_SurvivesRestDaysSinceLastWorkout() {
        // Last workout 2 days ago; yesterday was unscheduled and today's
        // scheduled workout isn't missed while the day is still in progress
        makeHistory(workoutDate: daysAgo(2))
        makeScheduledWorkout(onWeekdaysOf: [daysAgo(2), daysAgo(0)])

        let stats = sut.getWorkoutStats()

        XCTAssertEqual(stats.currentStreak, 1)
    }

    func testCurrentStreak_WithSchedule_ZeroAfterMissingScheduledDay() {
        makeHistory(workoutDate: daysAgo(3))
        makeScheduledWorkout(onWeekdaysOf: [daysAgo(2)])

        let stats = sut.getWorkoutStats()

        XCTAssertEqual(stats.currentStreak, 0)
    }

    func testStreak_WithoutSchedule_GapStillBreaksStreak() {
        // Legacy behavior preserved when no schedule exists
        makeHistory(workoutDate: daysAgo(2))
        makeHistory(workoutDate: daysAgo(0))

        let stats = sut.getWorkoutStats()

        XCTAssertEqual(stats.currentStreak, 1)
    }

    // MARK: - getWorkoutStats

    func testGetWorkoutStats_NoWorkoutManager_ReturnsZeroedStats() {
        sut.workoutManager = nil

        let stats = sut.getWorkoutStats()

        XCTAssertEqual(stats.totalWorkouts, 0)
        XCTAssertEqual(stats.totalWeightLifted, 0)
        XCTAssertEqual(stats.totalReps, 0)
        XCTAssertEqual(stats.totalDistance, 0)
        XCTAssertEqual(stats.totalTimeInHours, 0)
    }

    func testGetWorkoutStats_WithOneWorkout_ReturnsCorrectTotals() {
        makeHistory(totalWeightLifted: 500, repsCompleted: 100, totalDistance: 2, workoutTimeToComplete: "00:30:00")

        let stats = sut.getWorkoutStats()

        XCTAssertEqual(stats.totalWorkouts, 1)
        XCTAssertEqual(stats.totalWeightLifted, 500, accuracy: 0.001)
        XCTAssertEqual(stats.totalReps, 100)
        XCTAssertEqual(stats.totalDistance, 2, accuracy: 0.001)
        XCTAssertEqual(stats.totalTimeInHours, 0.5, accuracy: 0.001)
    }

    // MARK: - getPersonalRecords

    func testGetPersonalRecords_NoWorkoutManager_ReturnsZeroedRecords() {
        sut.workoutManager = nil

        let records = sut.getPersonalRecords()

        XCTAssertEqual(records.heaviestWeight, 0)
        XCTAssertEqual(records.mostReps, 0)
        XCTAssertEqual(records.furthestDistance, 0)
        XCTAssertEqual(records.longestWorkoutMinutes, 0)
    }

    func testGetPersonalRecords_ReturnsMaxValuesAcrossWorkouts() {
        makeHistory(totalWeightLifted: 500, repsCompleted: 50, totalDistance: 3, workoutTimeToComplete: "00:30:00")
        makeHistory(totalWeightLifted: 1000, repsCompleted: 200, totalDistance: 5, workoutTimeToComplete: "01:30:00")
        makeHistory(totalWeightLifted: 200, repsCompleted: 30, totalDistance: 1, workoutTimeToComplete: "00:10:00")

        let records = sut.getPersonalRecords()

        XCTAssertEqual(records.heaviestWeight, 1000, accuracy: 0.001)
        XCTAssertEqual(records.mostReps, 200)
        XCTAssertEqual(records.furthestDistance, 5, accuracy: 0.001)
        XCTAssertEqual(records.longestWorkoutMinutes, 90, accuracy: 0.001)
    }

    func testGetPersonalRecords_SingleWorkout_ReturnsItsValues() {
        makeHistory(totalWeightLifted: 300, repsCompleted: 75, totalDistance: 4, workoutTimeToComplete: "00:45:00")

        let records = sut.getPersonalRecords()

        XCTAssertEqual(records.heaviestWeight, 300, accuracy: 0.001)
        XCTAssertEqual(records.mostReps, 75)
        XCTAssertEqual(records.furthestDistance, 4, accuracy: 0.001)
        XCTAssertEqual(records.longestWorkoutMinutes, 45, accuracy: 0.001)
    }

    // MARK: - getNewlyUnlockedAchievements

    func testGetNewlyUnlockedAchievements_FirstCall_ReturnsNewlyUnlocked() {
        setAchievement(name: "First Step Forward", description: "Completed your first workout")
        makeHistory()

        let newlyUnlocked = sut.getNewlyUnlockedAchievements()

        XCTAssertEqual(newlyUnlocked.count, 1)
        XCTAssertEqual(newlyUnlocked[0].name, "First Step Forward")
    }

    func testGetNewlyUnlockedAchievements_SecondCall_ReturnsEmpty() {
        setAchievement(name: "First Step Forward", description: "Completed your first workout")
        makeHistory()

        _ = sut.getNewlyUnlockedAchievements()
        let newlyUnlocked = sut.getNewlyUnlockedAchievements()

        XCTAssertEqual(newlyUnlocked.count, 0)
    }

    func testGetNewlyUnlockedAchievements_NoneUnlocked_ReturnsEmpty() {
        setAchievement(name: "Double-Digit Dynamo", description: "Completed your 10th workout")
        for _ in 0..<5 { makeHistory() }

        let newlyUnlocked = sut.getNewlyUnlockedAchievements()

        XCTAssertEqual(newlyUnlocked.count, 0)
    }

    func testGetNewlyUnlockedAchievements_NoWorkouts_ReturnsEmpty() {
        setAchievement(name: "First Step Forward", description: "Completed your first workout")

        let newlyUnlocked = sut.getNewlyUnlockedAchievements()

        XCTAssertEqual(newlyUnlocked.count, 0)
    }
}
