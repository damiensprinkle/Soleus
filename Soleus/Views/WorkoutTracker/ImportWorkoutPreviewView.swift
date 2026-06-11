import SwiftUI

struct ImportWorkoutPreviewView: View {
    let shareableWorkout: ShareableWorkout
    @State private var workoutName: String
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var expandedExercises: Set<Int> = []
    @Binding var isPresented: Bool

    @EnvironmentObject var workoutController: WorkoutTrackerViewModel

    init(shareableWorkout: ShareableWorkout, isPresented: Binding<Bool>) {
        self.shareableWorkout = shareableWorkout
        self._isPresented = isPresented
        self._workoutName = State(initialValue: shareableWorkout.sanitizedWorkoutName)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Workout Name")) {
                    TextField("Enter Workout Name", text: $workoutName)
                        .accessibilityIdentifier(AccessibilityID.importPreviewNameField)
                }

                Section(header: Text("Exercises (\(shareableWorkout.exercises.count))")) {
                    ForEach(Array(shareableWorkout.exercises.enumerated()), id: \.offset) { index, exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                withAnimation {
                                    if expandedExercises.contains(index) {
                                        expandedExercises.remove(index)
                                    } else {
                                        expandedExercises.insert(index)
                                    }
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("\(exercise.sets.count) sets")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: expandedExercises.contains(index) ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            if expandedExercises.contains(index) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { setIndex, set in
                                        HStack {
                                            Text("Set \(setIndex + 1)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                                .frame(width: 50, alignment: .leading)

                                            Text(formatSetDetails(set: set, quantifier: exercise.quantifier, measurement: exercise.measurement))
                                                .font(.subheadline)
                                        }
                                        .padding(.leading, 8)
                                    }

                                    if let notes = exercise.notes, !notes.isEmpty {
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "note.text")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(notes)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.leading, 8)
                                        .padding(.top, 2)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Details")) {
                    HStack {
                        Text("Exported")
                        Spacer()
                        Text(shareableWorkout.exportDate, style: .date)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Import Workout")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                }
                .accessibilityIdentifier(AccessibilityID.importPreviewCancelButton),
                trailing: Button("Import") {
                    importWorkout()
                }
                .accessibilityIdentifier(AccessibilityID.importPreviewImportButton)
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Import Failed"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func formatSetDetails(set: ShareableWorkout.ShareableSet, quantifier: String, measurement: String) -> String {
        var details: [String] = []

        // Add quantifier (Reps or Distance)
        if quantifier == "Reps" && set.reps > 0 {
            details.append("\(set.reps) reps")
        } else if quantifier == "Distance" && set.distance > 0 {
            details.append(String(format: "%.1f mi", set.distance))
        }

        // Add measurement (Weight or Time)
        if measurement == "Weight" && set.weight > 0 {
            details.append(String(format: "%.1f lbs", set.weight))
        } else if measurement == "Time" && set.time > 0 {
            let minutes = set.time / 60
            let seconds = set.time % 60
            if minutes > 0 {
                details.append("\(minutes)m \(seconds)s")
            } else {
                details.append("\(seconds)s")
            }
        }

        return details.joined(separator: " × ")
    }

    private func importWorkout() {
        guard !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Please enter a workout name."
            showAlert = true
            return
        }

        // Check if workout name exists and add -copy suffix if needed
        var finalName = workoutName
        if workoutController.workoutManager.titleExists(finalName) {
            var copyNumber = 1
            while workoutController.workoutManager.titleExists("\(finalName)-copy\(copyNumber > 1 ? "\(copyNumber)" : "")") {
                copyNumber += 1
            }
            finalName = "\(finalName)-copy\(copyNumber > 1 ? "\(copyNumber)" : "")"
        }

        // Convert shareable workout to workout details
        let workoutDetails = shareableWorkout.toWorkoutDetails()

        // Temporarily set the workout details in the controller
        workoutController.workoutDetails = workoutDetails

        // Save the workout
        let result = workoutController.saveWorkout(
            title: finalName,
            update: false,
            workoutId: UUID()
        )

        switch result {
        case .success:
            isPresented = false
        case .failure(let error):
            switch error {
            case .emptyTitle:
                alertMessage = "A workout name is required, input a workout name before saving."
            case .noExerciseDetails:
                alertMessage = "Imported workout has no exercises."
            case .titleExists:
                alertMessage = "A workout with this name already exists, please input a new name."
            }
            showAlert = true
        }
    }
}
