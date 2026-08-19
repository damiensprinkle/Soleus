import SwiftUI

struct DevMenuView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel
    @EnvironmentObject var achievementManager: AchievementManager

    @State private var showingConfirmation = false
    @State private var confirmationAction: (() -> Void)?
    @State private var confirmationTitle = ""
    @State private var confirmationMessage = ""
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var showingLogViewer = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Data Generation")) {
                    Button(action: {
                        confirmationTitle = "Create Sample Workouts"
                        confirmationMessage = "This will create 10 sample workouts with exercises. Continue?"
                        confirmationAction = { createSampleWorkouts() }
                        showingConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create 10 Sample Workouts")
                                    .foregroundColor(.primary)
                                Text("Creates workouts with exercises")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isProcessing)

                    Button(action: {
                        confirmationTitle = "Generate Test Data"
                        confirmationMessage = "This will create 10 sample workout history entries with random data. Continue?"
                        confirmationAction = { generateSampleWorkoutHistory(count: 10) }
                        showingConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Generate 10 Workout Histories")
                                    .foregroundColor(.primary)
                                Text("Creates sample data for testing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isProcessing)

                    Button(action: {
                        confirmationTitle = "Generate Large Dataset"
                        confirmationMessage = "This will create 50 sample workout history entries. This may take a moment. Continue?"
                        confirmationAction = { generateSampleWorkoutHistory(count: 50) }
                        showingConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Generate 50 Workout Histories")
                                    .foregroundColor(.primary)
                                Text("Large dataset for performance testing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(isProcessing)
                }

                Section(header: Text("Debugging")) {
                    Button(action: {
                        showingLogViewer = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("View App Logs")
                                    .foregroundColor(.primary)
                                Text("Real-time log viewer with filters")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("App State")) {
                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "hasSeenLongPressTooltip")
                        statusMessage = "Long press tooltip reset"
                    }) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Long Press Tooltip")
                                    .foregroundColor(.primary)
                                Text("Shows tooltip again on next app launch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "hasSeenSetToggleHint")
                        UserDefaults.standard.removeObject(forKey: "hasSeenRestTimerHint")
                        statusMessage = "Active workout hints reset"
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Active Workout Hints")
                                    .foregroundColor(.primary)
                                Text("Shows set toggle and rest timer hints again")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "hasSeenDashboardHint")
                        statusMessage = "Dashboard hint reset"
                    }) {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Dashboard Hint")
                                    .foregroundColor(.primary)
                                Text("Shows the dashboard welcome card again")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "lastSeenVersion")
                        statusMessage = "Release notes reset"
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Release Notes Banner")
                                    .foregroundColor(.primary)
                                Text("Shows release notes card again on next launch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button(action: {
                        UserDefaults.standard.removeObject(forKey: "hasSeenLongPressTooltip")
                        UserDefaults.standard.removeObject(forKey: "hasSeenSetToggleHint")
                        UserDefaults.standard.removeObject(forKey: "hasSeenRestTimerHint")
                        UserDefaults.standard.removeObject(forKey: "hasSeenDashboardHint")
                        UserDefaults.standard.removeObject(forKey: "lastSeenVersion")
                        statusMessage = "All app state reset"
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset All App State")
                                    .foregroundColor(.primary)
                                Text("Resets all of the above at once")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section(header: Text("Data Management")) {
                    Button(action: {
                        confirmationTitle = "Delete All Workouts"
                        confirmationMessage = "⚠️ This will permanently delete ALL workouts and their exercises. This cannot be undone. Continue?"
                        confirmationAction = { deleteAllWorkouts() }
                        showingConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete All Workouts")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isProcessing)

                    Button(action: {
                        confirmationTitle = "Delete All History"
                        confirmationMessage = "⚠️ This will permanently delete ALL workout history. This cannot be undone. Continue?"
                        confirmationAction = { deleteAllWorkoutHistory() }
                        showingConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete All Workout History")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isProcessing)

                    Button(action: {
                        confirmationTitle = "Reset Achievements"
                        confirmationMessage = "⚠️ This will clear all unlocked achievements. This cannot be undone. Continue?"
                        confirmationAction = {
                            achievementManager.clearUnlockedAchievements()
                            statusMessage = "✅ Achievements reset"
                        }
                        showingConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.red)
                            Text("Reset Achievements")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isProcessing)
                }

                if !statusMessage.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: isProcessing ? "hourglass" : "checkmark.circle.fill")
                                .foregroundColor(isProcessing ? .orange : .green)
                            Text(statusMessage)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .navigationTitle("Developer Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(confirmationTitle, isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(confirmationTitle.contains("Delete") ? "Delete" : "Generate", role: confirmationTitle.contains("Delete") ? .destructive : .none) {
                    confirmationAction?()
                }
            } message: {
                Text(confirmationMessage)
            }
            .sheet(isPresented: $showingLogViewer) {
                LogViewerView()
            }
        }
    }

    private func generateSampleWorkoutHistory(count: Int) {
        isProcessing = true
        statusMessage = "Generating \(count) workout histories..."

        // Load workouts first on main thread
        workoutController.workoutManager.loadWorkoutsWithId()

        DispatchQueue.global(qos: .userInitiated).async {
            let exerciseNames = [
                "Bench Press", "Squat", "Deadlift", "Overhead Press", "Pull-ups",
                "Rows", "Lunges", "Dips", "Leg Press", "Shoulder Press",
                "Bicep Curls", "Tricep Extensions", "Lat Pulldown", "Leg Curls"
            ]

            // Get workouts from manager
            let workouts = workoutController.workoutManager.workouts
            guard !workouts.isEmpty else {
                DispatchQueue.main.async {
                    statusMessage = "Error: No workouts found. Create a workout first."
                    isProcessing = false
                }
                return
            }

            // Generate random dates over the past year
            let now = Date()
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now

            var generatedCount = 0

            for _ in 0..<count {
                // Random date in the past year
                let randomTimeInterval = TimeInterval.random(in: oneYearAgo.timeIntervalSince1970...now.timeIntervalSince1970)
                let randomDate = Date(timeIntervalSince1970: randomTimeInterval)

                // Pick random workout
                let randomIndex = Int.random(in: 0..<workouts.count)
                let workoutId = workouts[randomIndex].id

                // Generate random workout data
                let duration = Int.random(in: 1800...5400) // 30-90 minutes
                let hours = duration / 3600
                let minutes = (duration % 3600) / 60
                let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"

                // Create workout details
                let exerciseCount = Int.random(in: 3...6)
                var workoutDetails: [WorkoutDetailInput] = []
                var totalWeight: Float = 0
                var totalReps: Int32 = 0

                for i in 0..<exerciseCount {
                    let exerciseName = exerciseNames.randomElement() ?? "Exercise \(i+1)"
                    let setCount = Int.random(in: 3...5)

                    var sets: [SetInput] = []
                    for setNum in 0..<setCount {
                        let reps = Int32.random(in: 8...12)
                        let weight = Float.random(in: 45...225)

                        totalWeight += weight * Float(reps)
                        totalReps += reps

                        let setInput = SetInput(
                            id: UUID(),
                            reps: reps,
                            weight: weight,
                            time: 0,
                            distance: 0,
                            isCompleted: true,
                            setIndex: Int32(setNum),
                            exerciseQuantifier: "Reps",
                            exerciseMeasurement: "Weight"
                        )
                        sets.append(setInput)
                    }

                    let detailInput = WorkoutDetailInput(
                        id: UUID(),
                        exerciseId: UUID(),
                        exerciseName: exerciseName,
                        notes: nil,
                        orderIndex: Int32(i),
                        sets: sets,
                        exerciseQuantifier: "Reps",
                        exerciseMeasurement: "Weight"
                    )
                    workoutDetails.append(detailInput)
                }

                // Save workout history
                DispatchQueue.main.async {
                    workoutController.workoutManager.saveWorkoutHistory(
                        workoutId: workoutId,
                        dateCompleted: randomDate,
                        totalWeightLifted: totalWeight,
                        repsCompleted: totalReps,
                        workoutTimeToComplete: timeString,
                        totalCardioTime: "0m",
                        totalDistance: 0,
                        workoutDetailsInput: workoutDetails
                    ) {
                        generatedCount += 1
                    }
                }
            }

            // Wait for all operations to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = "✅ Generated \(count) workout histories"
                isProcessing = false
            }
        }
    }

    private func createSampleWorkouts() {
        isProcessing = true
        statusMessage = "Creating 10 sample workouts..."

        DispatchQueue.global(qos: .userInitiated).async {
            let workouts = [
                ("Push Day", "MyBlue", ["Bench Press", "Dumbbell Press", "Cable Fly", "Shoulder Press"]),
                ("Pull Day", "MyGreen", ["Pull-ups", "Rows", "Lat Pulldown", "Face Pulls"]),
                ("Leg Day", "MyRed", ["Squat", "Leg Press", "Lunges", "Leg Curls"]),
                ("Upper Body", "MyPurple", ["Bench Press", "Pull-ups", "Shoulder Press", "Bicep Curls"]),
                ("Full Body", "MyOrchid", ["Deadlift", "Overhead Press", "Rows", "Squat"]),
                ("Core & Cardio", "MyOrange", ["Plank", "Russian Twists", "Bicycle Crunches", "Mountain Climbers"]),
                ("Arms", "MyLightBlue", ["Bicep Curls", "Tricep Extensions", "Hammer Curls", "Skull Crushers"]),
                ("Back & Shoulders", "MyBrown", ["Deadlift", "Rows", "Shoulder Press", "Lateral Raises"]),
                ("Chest & Triceps", "MyGreyBlue", ["Bench Press", "Cable Fly", "Dips", "Tricep Pushdowns"]),
                ("Legs & Glutes", "MyTan", ["Squat", "Romanian Deadlift", "Hip Thrusts", "Calf Raises"])
            ]

            let colors = ["MyBlue", "MyGreen", "MyRed", "MyPurple", "MyOrchid", "MyOrange", "MyLightBlue", "MyBrown", "MyGreyBlue", "MyTan"]

            for (index, workout) in workouts.enumerated() {
                let workoutName = workout.0
                let workoutColor = colors[index % colors.count]
                let exercises = workout.2

                for (exerciseIndex, exerciseName) in exercises.enumerated() {
                    // Create 3 sample sets for each exercise
                    let sampleSets = [
                        SetInput(reps: 10, weight: 135, exerciseQuantifier: "Reps", exerciseMeasurement: "Weight"),
                        SetInput(reps: 10, weight: 135, exerciseQuantifier: "Reps", exerciseMeasurement: "Weight"),
                        SetInput(reps: 10, weight: 135, exerciseQuantifier: "Reps", exerciseMeasurement: "Weight")
                    ]

                    DispatchQueue.main.async {
                        workoutController.workoutManager.addWorkoutDetail(
                            id: UUID(),
                            workoutTitle: workoutName,
                            exerciseName: exerciseName,
                            color: workoutColor,
                            orderIndex: Int32(exerciseIndex),
                            sets: sampleSets,
                            exerciseMeasurement: "Weight",
                            exerciseQuantifier: "Reps",
                            notes: nil,
                            restDuration: 0
                        )
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                statusMessage = "✅ Created 10 sample workouts"
                isProcessing = false
                // Reload workouts
                workoutController.workoutManager.loadWorkoutsWithId()
            }
        }
    }

    private func deleteAllWorkouts() {
        isProcessing = true
        statusMessage = "Deleting all workouts..."

        DispatchQueue.global(qos: .userInitiated).async {
            // Load workouts first
            workoutController.workoutManager.loadWorkoutsWithId()
            let workouts = workoutController.workoutManager.workouts

            guard !workouts.isEmpty else {
                DispatchQueue.main.async {
                    statusMessage = "No workouts to delete"
                    isProcessing = false
                }
                return
            }

            let count = workouts.count

            for workout in workouts {
                DispatchQueue.main.async {
                    workoutController.workoutManager.deleteWorkout(for: workout.id)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                statusMessage = "✅ Deleted \(count) workouts"
                isProcessing = false
                // Reload workouts
                workoutController.workoutManager.loadWorkoutsWithId()
            }
        }
    }

    private func deleteAllWorkoutHistory() {
        isProcessing = true
        statusMessage = "Deleting all workout history..."

        DispatchQueue.global(qos: .userInitiated).async {
            guard let allHistory = workoutController.workoutManager.fetchAllWorkoutHistoryAllTime() else {
                DispatchQueue.main.async {
                    statusMessage = "Error: Could not fetch history"
                    isProcessing = false
                }
                return
            }

            let count = allHistory.count

            for history in allHistory {
                if let historyId = history.id {
                    workoutController.workoutManager.deleteWorkoutHistory(for: historyId)
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                statusMessage = "✅ Deleted \(count) workout histories"
                isProcessing = false
            }
        }
    }
}

#Preview {
    DevMenuView()
}
