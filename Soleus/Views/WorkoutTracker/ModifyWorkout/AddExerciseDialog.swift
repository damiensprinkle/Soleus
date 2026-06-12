import SwiftUI

struct AddExerciseDialog: View {
    @Binding var workoutDetails: [WorkoutDetailInput]
    @Binding var showingDialog: Bool
    var showPermanentNote: Bool = false
    /// When set, the dialog is embedded in the exercise picker sheet and the
    /// cancel action returns to the library instead of dismissing.
    var onBack: (() -> Void)? = nil
    @State private var selectedWorkoutQuantifier: String = "Reps"
    @State private var selectedWorkoutMeasurement: String = "Weight"

    @State private var exerciseName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Add Exercise")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.top, 40)
                .padding(.bottom, showPermanentNote ? 8 : 20)

            if showPermanentNote {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    Text("This exercise will be permanently saved to your workout plan, even if you cancel the workout.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            VStack(alignment: .leading, spacing: 20) {

                // Exercise Name
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Exercise Name")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(exerciseName.count)/30")
                            .font(.caption)
                            .foregroundColor(exerciseName.count >= 30 ? .red : .secondary)
                    }
                    .padding(.horizontal, 20)

                    TextField("e.g., Bench Press", text: $exerciseName)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                        .padding(.horizontal, 20)
                        .focused($isNameFieldFocused)
                        .onChange(of: exerciseName) {
                            if exerciseName.count > 30 {
                                exerciseName = String(exerciseName.prefix(30))
                            }
                        }
                        .accessibilityIdentifier(AccessibilityID.exerciseNameField)
                }

                // Track By
                VStack(alignment: .leading, spacing: 10) {
                    Text("Track By")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    HStack(spacing: 10) {
                        optionCard(
                            icon: "repeat",
                            label: "Reps",
                            isSelected: selectedWorkoutQuantifier == "Reps"
                        ) { selectedWorkoutQuantifier = "Reps" }
                        .accessibilityIdentifier(AccessibilityID.exerciseTrackByPicker)

                        optionCard(
                            icon: "figure.outdoor.cycle",
                            label: "Distance",
                            isSelected: selectedWorkoutQuantifier == "Distance"
                        ) { selectedWorkoutQuantifier = "Distance" }
                    }
                    .padding(.horizontal, 20)
                }

                // Measure With
                VStack(alignment: .leading, spacing: 10) {
                    Text("Measure With")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    HStack(spacing: 10) {
                        optionCard(
                            icon: "scalemass.fill",
                            label: "Weight",
                            isSelected: selectedWorkoutMeasurement == "Weight"
                        ) { selectedWorkoutMeasurement = "Weight" }
                        .accessibilityIdentifier(AccessibilityID.exerciseMeasureWithPicker)

                        optionCard(
                            icon: "timer",
                            label: "Time",
                            isSelected: selectedWorkoutMeasurement == "Time"
                        ) { selectedWorkoutMeasurement = "Time" }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer().frame(height: 24)

            // Buttons
            VStack(spacing: 10) {
                Button(action: { addNewExercise() }) {
                    Text("Add Exercise")
                        .font(.headline)
                        .foregroundColor(.staticWhite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.myBlue)
                        .cornerRadius(12)
                }
                .accessibilityIdentifier(AccessibilityID.exerciseDialogAddButton)
                .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(action: {
                    if let onBack = onBack {
                        onBack()
                    } else {
                        showingDialog = false
                    }
                }) {
                    Text(onBack == nil ? "Cancel" : "Back to Library")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .accessibilityIdentifier(AccessibilityID.exerciseDialogCancelButton)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 400)
        .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        .transformEffect(.identity)

    }

    @ViewBuilder
    private func optionCard(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .staticWhite : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.myBlue : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func addNewExercise() {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let measurement = selectedWorkoutMeasurement
        let quantifier = selectedWorkoutQuantifier
        let newIndex = workoutDetails.last?.orderIndex ?? 0
        let newDetail = WorkoutDetailInput(
            id: UUID(),
            exerciseName: trimmed,
            orderIndex: newIndex + 1,
            sets: [SetInput(
                id: UUID(),
                reps: 0,
                weight: 0,
                time: 0,
                distance: 0,
                isCompleted: false,
                setIndex: 1,
                exerciseQuantifier: quantifier,
                exerciseMeasurement: measurement
            )],
            exerciseQuantifier: quantifier,
            exerciseMeasurement: measurement
        )
        workoutDetails.append(newDetail)
        showingDialog = false
    }
}
