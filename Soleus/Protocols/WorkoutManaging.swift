import Foundation
import CoreData
import Combine

/// Protocol defining the interface for managing workouts, sessions, and history
protocol WorkoutManaging: AnyObject, ObservableObject {

    // MARK: - Published Properties
    var workouts: [WorkoutInfo] { get set }

    // MARK: - Context Management
    var context: NSManagedObjectContext? { get set }

    // MARK: - Workout CRUD Operations

    /// Adds a new workout with exercise details
    func addWorkoutDetail(
        id: UUID,
        workoutTitle: String,
        exerciseName: String,
        color: String,
        orderIndex: Int32,
        sets: [SetInput],
        exerciseMeasurement: String,
        exerciseQuantifier: String,
        notes: String?,
        restDuration: Int32
    )

    /// Fetches a workout by its ID
    func fetchWorkoutById(for workoutId: UUID) -> Workouts?

    /// Loads all workouts with their IDs
    func loadWorkoutsWithId()

    /// Deletes a workout and all associated data
    func deleteWorkout(for workoutId: UUID)

    /// Duplicates an existing workout
    func duplicateWorkout(originalWorkoutId: UUID, completion: (() -> Void)?)

    /// Updates the title of a workout
    func updateWorkoutTitle(workoutId: UUID, to newTitle: String)

    /// Updates the color of a workout
    func updateWorkoutColor(workoutId: UUID, color: String)

    /// Updates workout details (exercises and sets)
    func updateWorkoutDetails(workoutId: UUID, workoutDetailsInput: [WorkoutDetailInput])

    /// Checks if a workout title already exists
    func titleExists(_ title: String) -> Bool

    /// Checks if a workout title already exists, ignoring a specific workout (used during edits)
    func titleExists(_ title: String, excludingId: UUID) -> Bool

    /// Saves the order of workouts by updating their orderIndex values
    func saveWorkoutOrder(workouts: [WorkoutInfo])

    // MARK: - Active Workout / Temporary Data Management

    /// Saves or updates sets during an active workout
    func saveOrUpdateSetsDuringActiveWorkout(
        workoutId: UUID,
        exerciseId: UUID,
        exerciseName: String,
        setsInput: [SetInput],
        orderIndex: Int32
    )

    /// Updates exercise notes during an active workout
    func updateExerciseNotesDuringActiveWorkout(
        workoutId: UUID,
        exerciseId: UUID,
        notes: String?
    )

    /// Adds a new exercise during an active workout and returns the generated exerciseId
    func addExerciseDuringActiveWorkout(
        workoutId: UUID,
        exerciseName: String,
        orderIndex: Int32,
        exerciseQuantifier: String,
        exerciseMeasurement: String,
        sets: [SetInput],
        notes: String?
    ) -> UUID?

    /// Loads temporary workout data for an active workout
    func loadTemporaryWorkoutData(for workoutId: UUID) -> [WorkoutDetailInput]

    /// Deletes all temporary workout details
    func deleteAllTemporaryWorkoutDetails()

    // MARK: - Session Management

    /// Gets all workout sessions
    func getSessions() -> [WorkoutSession]

    /// Gets the workout ID of the currently active session
    func getWorkoutIdOfActiveSession() -> UUID?

    /// Sets the session status (active/inactive) for a workout
    func setSessionStatus(workoutId: UUID, isActive: Bool)

    // MARK: - Workout History

    /// Saves workout history after completion
    func saveWorkoutHistory(
        workoutId: UUID,
        dateCompleted: Date,
        totalWeightLifted: Float,
        repsCompleted: Int32,
        workoutTimeToComplete: String,
        totalCardioTime: String,
        totalDistance: Float,
        workoutDetailsInput: [WorkoutDetailInput],
        completion: (() -> Void)?
    )

    /// Fetches the most recent workout history for a specific workout
    func fetchLatestWorkoutHistory(for workoutId: UUID) -> WorkoutHistory?

    /// Fetches all workout history for a specific month
    func fetchAllWorkoutHistory(for date: Date) -> [WorkoutHistory]?
    
    /// Fetches all workout history for all time
    func fetchAllWorkoutHistoryAllTime() -> [WorkoutHistory]?

    /// Fetches the earliest year in which a workout was completed
    func fetchEarliestHistoryYear() -> Int?

    /// Deletes a specific workout history entry
    func deleteWorkoutHistory(for historyId: UUID)
}
