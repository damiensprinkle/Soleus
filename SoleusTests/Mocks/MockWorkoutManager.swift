import Foundation
import CoreData
import Combine
@testable import Soleus

class MockWorkoutManager: ObservableObject, WorkoutManaging {
    @Published var workouts: [WorkoutInfo] = []
    var context: NSManagedObjectContext?

    // Test data storage - simplified to avoid CoreData
    private var storedWorkoutData: [UUID: (name: String, color: String?)] = [:]
    private var storedSessions: [WorkoutSession] = []
    private var activeSessionWorkoutId: UUID?

    // Track method calls for verification
    var addWorkoutDetailCalled = false
    var deleteWorkoutCalled = false
    var updateWorkoutDetailsCalled = false
    var saveWorkoutHistoryCalled = false
    var setSessionStatusCalled = false
    var lastDeletedWorkoutId: UUID?
    var lastUpdatedWorkoutId: UUID?
    var lastSavedTotalWeight: Float?
    var lastSavedRepsCompleted: Int32?
    var lastSavedTotalCardioTime: String?
    var lastSavedTotalDistance: Float?
    var lastSavedWorkoutTime: String?

    // MARK: - Workout CRUD Operations

    func addWorkoutDetail(
        id: UUID,
        workoutTitle: String,
        exerciseName: String,
        color: String,
        orderIndex: Int32,
        sets: [SetInput],
        exerciseMeasurement: String,
        exerciseQuantifier: String,
        notes: String? = nil,
        restDuration: Int32 = 0
    ) {
        addWorkoutDetailCalled = true

        // Store workout data
        storedWorkoutData[id] = (name: workoutTitle, color: color)

        let workoutInfo = WorkoutInfo(id: id, name: workoutTitle)
        workouts.append(workoutInfo)
    }

    func saveWorkoutOrder(workouts: [WorkoutInfo]) {
        // Update the internal workouts array to match the new order
        self.workouts = workouts
    }

    // MARK: - Weekly Schedule

    private var storedSchedules: [UUID: Set<Int>] = [:]

    func scheduledDays(for workoutId: UUID) -> Set<Int> {
        return storedSchedules[workoutId] ?? []
    }

    func setScheduledDays(_ days: Set<Int>, for workoutId: UUID) {
        if days.isEmpty {
            storedSchedules.removeValue(forKey: workoutId)
        } else {
            storedSchedules[workoutId] = days
        }
    }

    func weeklySchedule() -> [Int: [WorkoutInfo]] {
        var schedule: [Int: [WorkoutInfo]] = [:]
        for workout in workouts {
            for day in storedSchedules[workout.id] ?? [] {
                schedule[day, default: []].append(workout)
            }
        }
        return schedule
    }

    func completedWorkoutIds(on date: Date) -> Set<UUID> {
        return []
    }

    func updateExerciseNotesDuringActiveWorkout(workoutId: UUID, exerciseId: UUID, notes: String?) {
        // Mock implementation - in real implementation this would update CoreData
        // For testing purposes, this is a no-op
    }

    func addExerciseDuringActiveWorkout(
        workoutId: UUID,
        exerciseName: String,
        orderIndex: Int32,
        exerciseQuantifier: String,
        exerciseMeasurement: String,
        sets: [SetInput],
        notes: String?
    ) -> UUID? {
        // Return a new UUID for the exercise
        return UUID()
    }

    func fetchAllWorkoutHistoryAllTime() -> [WorkoutHistory]? {
        return nil
    }

    func fetchWorkoutById(for workoutId: UUID) -> Workouts? {
        // Return nil for mock - tests don't need actual CoreData objects
        return nil
    }

    func loadWorkoutsWithId() {
        // In tests, we can directly set the workouts array
        // Only load from storedWorkoutData if workouts array is empty
        if workouts.isEmpty {
            workouts = storedWorkoutData.map { (id, data) in
                WorkoutInfo(id: id, name: data.name)
            }
        }
    }

    func deleteWorkout(for workoutId: UUID) {
        deleteWorkoutCalled = true
        lastDeletedWorkoutId = workoutId
        storedWorkoutData.removeValue(forKey: workoutId)
        workouts.removeAll { $0.id == workoutId }
    }

    func duplicateWorkout(originalWorkoutId: UUID, completion: (() -> Void)? = nil) {
        guard let original = storedWorkoutData[originalWorkoutId] else {
            completion?()
            return
        }

        let newId = UUID()
        storedWorkoutData[newId] = (name: "\(original.name)-copy", color: original.color)

        let workoutInfo = WorkoutInfo(id: newId, name: "\(original.name)-copy")
        workouts.append(workoutInfo)
        completion?()
    }

    func updateWorkoutTitle(workoutId: UUID, to newTitle: String) {
        if var data = storedWorkoutData[workoutId] {
            data.name = newTitle
            storedWorkoutData[workoutId] = data
        }
        if let index = workouts.firstIndex(where: { $0.id == workoutId }) {
            workouts[index] = WorkoutInfo(id: workoutId, name: newTitle)
        }
    }

    func updateWorkoutColor(workoutId: UUID, color: String) {
        if var data = storedWorkoutData[workoutId] {
            data.color = color
            storedWorkoutData[workoutId] = data
        }
    }

    func updateWorkoutDetails(workoutId: UUID, workoutDetailsInput: [WorkoutDetailInput]) {
        updateWorkoutDetailsCalled = true
        lastUpdatedWorkoutId = workoutId
    }

    func titleExists(_ title: String) -> Bool {
        return workouts.contains { $0.name.lowercased() == title.lowercased() }
    }

    func titleExists(_ title: String, excludingId: UUID) -> Bool {
        return workouts.contains { $0.name.lowercased() == title.lowercased() && $0.id != excludingId }
    }

    // MARK: - Active Workout / Temporary Data

    func saveOrUpdateSetsDuringActiveWorkout(
        workoutId: UUID,
        exerciseId: UUID,
        exerciseName: String,
        setsInput: [SetInput],
        orderIndex: Int32
    ) {
        // Mock implementation - do nothing
    }

    func loadTemporaryWorkoutData(for workoutId: UUID) -> [WorkoutDetailInput] {
        return []
    }

    func deleteAllTemporaryWorkoutDetails() {
        // Mock implementation - do nothing
    }

    // MARK: - Session Management

    func getSessions() -> [WorkoutSession] {
        return storedSessions
    }

    func getWorkoutIdOfActiveSession() -> UUID? {
        return activeSessionWorkoutId
    }

    func setSessionStatus(workoutId: UUID, isActive: Bool) {
        setSessionStatusCalled = true
        if isActive {
            activeSessionWorkoutId = workoutId
        } else {
            activeSessionWorkoutId = nil
        }
    }

    // MARK: - Workout History

    func saveWorkoutHistory(
        workoutId: UUID,
        dateCompleted: Date,
        totalWeightLifted: Float,
        repsCompleted: Int32,
        workoutTimeToComplete: String,
        totalCardioTime: String,
        totalDistance: Float,
        workoutDetailsInput: [WorkoutDetailInput],
        completion: (() -> Void)? = nil
    ) {
        saveWorkoutHistoryCalled = true
        lastSavedTotalWeight = totalWeightLifted
        lastSavedRepsCompleted = repsCompleted
        lastSavedWorkoutTime = workoutTimeToComplete
        lastSavedTotalCardioTime = totalCardioTime
        lastSavedTotalDistance = totalDistance
        completion?()
    }

    func fetchLatestWorkoutHistory(for workoutId: UUID) -> WorkoutHistory? {
        return nil
    }

    func fetchAllWorkoutHistory(for date: Date) -> [WorkoutHistory]? {
        return nil
    }

    func deleteWorkoutHistory(for historyId: UUID) {
        // No-op in mock
    }

    func fetchEarliestHistoryYear() -> Int? {
        return nil
    }
}

