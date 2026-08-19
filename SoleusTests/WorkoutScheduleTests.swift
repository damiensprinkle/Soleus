import XCTest
import CoreData
@testable import Soleus

final class WorkoutScheduleTests: XCTestCase {
    var manager: WorkoutManager!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController.forUITesting
        context = persistence.container.viewContext
        manager = WorkoutManager()
        manager.context = context
    }

    override func tearDown() {
        let workoutRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
        if let workouts = try? context.fetch(workoutRequest) {
            workouts.forEach { context.delete($0) }
        }
        let historyRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        if let histories = try? context.fetch(historyRequest) {
            histories.forEach { context.delete($0) }
        }
        try? context.save()
        manager = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Helpers

    @discardableResult
    private func makeWorkout(name: String = "Test Workout", orderIndex: Int32 = 0) -> Workouts {
        let workout = Workouts(context: context)
        workout.id = UUID()
        workout.name = name
        workout.orderIndex = orderIndex
        try? context.save()
        return workout
    }

    // MARK: - Parse

    func testParse_NilOrEmpty_ReturnsEmptySet() {
        XCTAssertEqual(WorkoutSchedule.parse(nil), [])
        XCTAssertEqual(WorkoutSchedule.parse(""), [])
    }

    func testParse_ValidString_ReturnsDays() {
        XCTAssertEqual(WorkoutSchedule.parse("1,3,5"), [1, 3, 5])
    }

    func testParse_IgnoresInvalidEntries() {
        XCTAssertEqual(WorkoutSchedule.parse("0,8,abc,3"), [3])
    }

    // MARK: - Serialize

    func testSerialize_EmptySet_ReturnsNil() {
        XCTAssertNil(WorkoutSchedule.serialize([]))
    }

    func testSerialize_SortsDays() {
        XCTAssertEqual(WorkoutSchedule.serialize([5, 1, 3]), "1,3,5")
    }

    func testParseSerialize_RoundTrips() {
        let days: Set<Int> = [2, 4, 7]
        XCTAssertEqual(WorkoutSchedule.parse(WorkoutSchedule.serialize(days)), days)
    }

    // MARK: - Ordered Weekdays

    func testOrderedWeekdays_SundayFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        XCTAssertEqual(WorkoutSchedule.orderedWeekdays(calendar: calendar), [1, 2, 3, 4, 5, 6, 7])
    }

    func testOrderedWeekdays_MondayFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        XCTAssertEqual(WorkoutSchedule.orderedWeekdays(calendar: calendar), [2, 3, 4, 5, 6, 7, 1])
    }

    // MARK: - WorkoutManager Schedule CRUD

    func testSetAndGetScheduledDays_RoundTripsThroughCoreData() {
        let workout = makeWorkout()

        manager.setScheduledDays([2, 4, 6], for: workout.id!)

        XCTAssertEqual(manager.scheduledDays(for: workout.id!), [2, 4, 6])
        XCTAssertEqual(workout.scheduledDays, "2,4,6")
    }

    func testSetScheduledDays_EmptySet_ClearsSchedule() {
        let workout = makeWorkout()
        manager.setScheduledDays([1], for: workout.id!)

        manager.setScheduledDays([], for: workout.id!)

        XCTAssertEqual(manager.scheduledDays(for: workout.id!), [])
        XCTAssertNil(workout.scheduledDays)
    }

    func testScheduledDays_UnknownWorkout_ReturnsEmptySet() {
        XCTAssertEqual(manager.scheduledDays(for: UUID()), [])
    }

    func testWeeklySchedule_GroupsWorkoutsByDay() {
        let push = makeWorkout(name: "Push", orderIndex: 0)
        let pull = makeWorkout(name: "Pull", orderIndex: 1)
        manager.setScheduledDays([2, 5], for: push.id!)
        manager.setScheduledDays([2], for: pull.id!)

        let schedule = manager.weeklySchedule()

        XCTAssertEqual(schedule[2]?.map(\.name), ["Push", "Pull"])
        XCTAssertEqual(schedule[5]?.map(\.name), ["Push"])
        XCTAssertNil(schedule[3])
    }

    func testWeeklySchedule_NoScheduledWorkouts_ReturnsEmpty() {
        makeWorkout()
        XCTAssertTrue(manager.weeklySchedule().isEmpty)
    }

    // MARK: - Completed Workouts For Day

    func testCompletedWorkoutIds_ReturnsOnlyWorkoutsCompletedThatDay() {
        let calendar = Calendar.current
        let completedToday = makeWorkout(name: "Today")
        let completedYesterday = makeWorkout(name: "Yesterday", orderIndex: 1)

        let todayHistory = WorkoutHistory(context: context)
        todayHistory.id = UUID()
        todayHistory.workoutDate = Date()
        todayHistory.workoutR = completedToday

        let yesterdayHistory = WorkoutHistory(context: context)
        yesterdayHistory.id = UUID()
        yesterdayHistory.workoutDate = calendar.date(byAdding: .day, value: -1, to: Date())
        yesterdayHistory.workoutR = completedYesterday
        try? context.save()

        let completed = manager.completedWorkoutIds(on: Date())

        XCTAssertEqual(completed, [completedToday.id!])
    }
}
