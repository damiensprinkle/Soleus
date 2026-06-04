import Foundation
import SwiftUI
import Combine
import OSLog

class ActiveWorkoutViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var workoutTitle: String = ""
    @Published var workoutStarted: Bool = false
    @Published var elapsedTime: Int = 0
    @Published var isLoading: Bool = true
    @Published var workoutCancelled: Bool = false

    // MARK: - Private Properties
    private var cancellableTimer: AnyCancellable?
    private var foregroundObserver: Any?
    private var backgroundObserver: Any?

    private let workoutId: UUID
    private var workoutController: WorkoutTrackerViewModel!
    private var appViewModel: AppViewModel!

    // MARK: - Computed Properties
    var elapsedTimeFormatted: String {
        let hours = elapsedTime / 3600
        let minutes = (elapsedTime % 3600) / 60
        let seconds = elapsedTime % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var workoutButtonText: String {
        if workoutStarted {
            return elapsedTimeFormatted
        } else {
            return "Start Workout"
        }
    }

    var hasActiveSession: Bool {
        workoutController.hasActiveSession
    }

    // MARK: - Initialization
    init(workoutId: UUID) {
        self.workoutId = workoutId
    }

    func setup(workoutController: WorkoutTrackerViewModel, appViewModel: AppViewModel) {
        self.workoutController = workoutController
        self.appViewModel = appViewModel
        setupNotificationObservers()
    }

    // MARK: - Lifecycle
    func loadWorkout() {
        if workoutController.workoutManager.fetchWorkoutById(for: workoutId) != nil {
            workoutController.loadWorkoutDetails(for: workoutId)
            workoutController.originalWorkoutDetails = workoutController.workoutDetails

            if let workout = workoutController.workoutManager.fetchWorkoutById(for: workoutId) {
                workoutTitle = workout.name ?? "Workout"
            }

            initSession()
            isLoading = false
            AppLogger.workout.info("Finished loading active workout")
        } else {
            isLoading = false
            AppLogger.workout.error("Error: workout details not found")
        }
    }

    func cleanup() {
        cancelTimer()
        removeNotificationObservers()
    }

    // MARK: - Session Management
    private func initSession() {
        if workoutController.hasActiveSession {
            self.workoutStarted = true
            guard let activeSession = workoutController.workoutManager.getSessions().first else {
                AppLogger.workout.error("No active session found despite hasActiveSession being true")
                self.workoutStarted = false
                return
            }
            if let startTime = activeSession.startTime {
                self.elapsedTime = Int(Date().timeIntervalSince(startTime))
                startTimer()
            }
            workoutController.loadTemporaryWorkoutDetails(for: workoutId)
        }
    }

    func startWorkout() {
        workoutStarted = true
        workoutCancelled = false
        elapsedTime = 0
        startTimer()
        workoutController.workoutManager.setSessionStatus(workoutId: workoutId, isActive: true)
        HapticManager.shared.workoutStarted()
        AppLogger.workout.info("Started workout with ID: \(self.workoutId)")
    }

    func cancelWorkout() {
        cancelTimer()
        workoutStarted = false
        workoutController.setSessionStatus(workoutId: workoutId, isActive: false)
        workoutController.workoutManager.deleteAllTemporaryWorkoutDetails()
        workoutController.loadWorkoutDetails(for: workoutId)
        workoutCancelled = true
        HapticManager.shared.workoutCancelled()
        AppLogger.workout.info("Canceled workout with ID: \(self.workoutId)")
    }

    func completeWorkout(shouldUpdateTemplate: Bool) {
        cancelTimer()

        if shouldUpdateTemplate {
            workoutController.workoutManager.updateWorkoutDetails(
                workoutId: workoutId,
                workoutDetailsInput: workoutController.workoutDetails
            )
            AppLogger.workout.info("Updated workout template after completion")
        }

        workoutStarted = false
        workoutController.setSessionStatus(workoutId: workoutId, isActive: false)
        HapticManager.shared.workoutCompleted()

        // Save workout history and navigate when complete
        workoutController.saveWorkoutHistory(elapsedTimeFormatted: elapsedTimeFormatted, workoutId: workoutId) { [weak self] in
            guard let self = self else { return }
            self.workoutController.workoutManager.deleteAllTemporaryWorkoutDetails()

            // Navigate to overview only after history is saved, pass elapsed time for immediate display
            self.appViewModel.navigateTo(.workoutOverview(workoutId, elapsedTimeFormatted))
            AppLogger.workout.info("Completed workout with ID: \(workoutId), elapsed time: \(elapsedTimeFormatted)")
        }
    }

    func hasWorkoutChanged() -> Bool {
        workoutController.hasWorkoutChanged()
    }

    func isAnyOtherSessionActive() -> Bool {
        guard let workoutController = workoutController else {
            return false
        }
        let sessionsWorkoutId = workoutController.workoutManager.getWorkoutIdOfActiveSession()
        if sessionsWorkoutId != workoutId {
            if sessionsWorkoutId == nil {
                return false
            }
            return true
        }
        return false
    }

    // MARK: - Timer Management
    private func startTimer() {
        guard cancellableTimer == nil else { return }
        cancellableTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.elapsedTime += 1
        }
    }

    private func cancelTimer() {
        cancellableTimer?.cancel()
        cancellableTimer = nil
    }

    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTimerForForeground()
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAppBackgrounding()
        }
    }

    private func removeNotificationObservers() {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func updateTimerForForeground() {
        if workoutStarted {
            let now = Date()
            if let startTime = workoutController.workoutManager.getSessions().first?.startTime {
                self.elapsedTime = Int(now.timeIntervalSince(startTime))
            }
        }
    }

    private func handleAppBackgrounding() {
        // Timer continues in background via startTime calculation
    }

    // MARK: - Deinit
    deinit {
        cleanup()
    }
}
