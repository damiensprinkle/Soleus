import SwiftUI
import OSLog

struct ExerciseRowActive: View {
    @Binding var setInput: SetInput
    
    let setIndex: Int
    let workoutDetails: WorkoutDetailInput
    let workoutId: UUID
    let workoutStarted: Bool
    let workoutCancelled: Bool
    var exerciseQuantifier: String
    var exerciseMeasurement: String
    
    @FocusState private var focusedField: FocusableField?
    @State private var originalTimeInput: String = ""
    @State private var isExternalSync: Bool = false
    @State private var distanceInput: String = ""
    @State private var timeInput: String = ""
    @State private var weightInput: String = ""
    @State private var repsInput: String = ""
    @State private var checked: Bool = false
    @State private var repsModified: Bool = false
    @State private var distanceModified: Bool = false
    @State private var weightModified: Bool = false
    @State private var timeModified: Bool = false
    @State private var saveFailedError: Bool = false
    @State private var showSaveErrorMessage: Bool = false
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel
    @EnvironmentObject var restTimer: RestTimerManager

    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = true
    @AppStorage("defaultRestDuration") private var defaultRestDuration: Int = 90
    
    
    var body: some View {
        HStack {
            Spacer()
            Text("\(setIndex)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .center)
                .padding(.leading, 10)
            Divider()
            if exerciseQuantifier == "Reps" {
                repsTextField
                Spacer()
                Divider()
            }
            
            if exerciseQuantifier == "Distance" {
                distanceTextField
                Spacer()
                Divider()
            }
            if exerciseMeasurement == "Weight" {
                weightTextField
                Spacer()
                Divider()
            }
            
            if exerciseMeasurement == "Time"  {
                timeTextField
                Spacer()
                Divider()
            }
            
            Toggle(isOn: $checked) {
                Text("")
            }
            .onAppear {
                // Sync checked from setInput on first appear (handles resume with completed sets)
                if checked != setInput.isCompleted {
                    isExternalSync = true
                    checked = setInput.isCompleted
                }
            }
            .onChange(of: setInput.isCompleted) { _, newValue in
                // Sync when setInput changes externally (e.g., loadTemporaryWorkoutDetails)
                if checked != newValue {
                    isExternalSync = true
                    checked = newValue
                }
            }
            .onChange(of: checked) {
                let wasExternal = isExternalSync
                isExternalSync = false

                setInput.isCompleted = checked
                if !wasExternal {
                    saveWorkoutDetail()
                }

                // Haptic feedback for set completion
                if checked {
                    HapticManager.shared.setCompleted()
                } else {
                    HapticManager.shared.setUncompleted()
                }

                // Auto-start rest timer only for user-initiated completions
                if checked && autoStartRestTimer && workoutStarted && !wasExternal {
                    // Per-exercise override wins; 0 means use the global preference
                    let duration = workoutDetails.restDuration > 0 ? Int(workoutDetails.restDuration) : defaultRestDuration
                    restTimer.startRest(duration: duration)
                }
            }
            .frame(width: 50)
            .toggleStyle(SwitchToggleStyle(tint: Color(UIColor.green)))
            .scaleEffect(0.8)
            .padding(.trailing, 10)
            .accessibilityLabel("Set \(setIndex) completion")
            .accessibilityValue(checked ? "Completed" : "Not completed")
            .accessibilityHint("Double tap to mark set as \(checked ? "incomplete" : "complete")")
            .accessibilityIdentifier("complete_set_\(setIndex)")
            
        }
        .onChange(of: workoutCancelled) {
             if workoutCancelled {
                 resetWorkoutDetails()
             }
         }
        .disabled(!workoutStarted)
        .opacity(!workoutStarted ? 0.5 : 1)
        .foregroundColor(!workoutStarted ? .gray : .myBlack)
        .background(rowBackground)
        .overlay(errorBorder)
        .overlay(errorMessage)
    }

    private var rowBackground: some View {
        Group {
            if saveFailedError {
                Color.red.opacity(0.15)
            } else if checked {
                Color.green.opacity(0.2)
            } else {
                Color(.secondarySystemGroupedBackground)
            }
        }
    }

    @ViewBuilder
    private var errorBorder: some View {
        if saveFailedError {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.red, lineWidth: 2)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if showSaveErrorMessage {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Save failed - exercise not initialized")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(6)
                .background(Color.white)
                .cornerRadius(6)
                .shadow(radius: 4)
                .offset(y: -30)
            }
        }
    }

    private var repsTextField: some View {
        TextField("Reps", text: $repsInput)
            .focused($focusedField, equals: .reps)
            .multilineTextAlignment(.center)
            .onChange(of: focusedField) {
                if focusedField == .reps {
                    focusManager.isAnyTextFieldFocused = true
                    focusManager.currentlyFocusedField = .reps
                    repsInput = ""
                } else {
                    if repsInput.isEmpty {
                        repsInput = "\(setInput.reps)"
                        saveWorkoutDetail()
                    }
                }
            }
            .onChange(of: repsInput) {
                guard focusedField == .reps, !repsInput.isEmpty else { return }
                validateAndSetInputInt(&repsInput, for: &setInput.reps, maxLength: 3)
                repsModified = true
                saveWorkoutDetail()
                checkAutoComplete()
            }
            .onAppear {
                repsInput = "\(setInput.reps)"
            }
            .keyboardType(.numberPad)
            .frame(width: 100, height: 20)
            .accessibilityLabel("Reps for set \(setIndex)")
            .accessibilityValue("\(setInput.reps) reps")
            .accessibilityHint("Double tap to edit number of repetitions")
            .accessibilityIdentifier("reps_set_\(setIndex)")
    }
    
    private var distanceTextField: some View {
        TextField("Distance", text: $distanceInput)
            .focused($focusedField, equals: .distance)
            .multilineTextAlignment(.center)
            .onChange(of: focusedField) {
                if focusedField == .distance {
                    distanceInput = ""
                    focusManager.isAnyTextFieldFocused = true
                    focusManager.currentlyFocusedField = .distance
                } else {
                    if distanceInput.isEmpty {
                        distanceInput = "\(setInput.distance)"
                        saveWorkoutDetail()
                    }
                }
            }
            .onChange(of: distanceInput){
                guard focusedField == .distance, !distanceInput.isEmpty else { return }
                validateAndSetInputFloat(&distanceInput, for: &setInput.distance, maxLength: 5, maxDecimals: 2)
                distanceModified = true
                saveWorkoutDetail()
                checkAutoComplete()
            }
            .onAppear {
                distanceInput = "\(setInput.distance)"
            }
            .keyboardType(.numberPad)
            .frame(width: 100, height: 20)
            .accessibilityLabel("Distance for set \(setIndex)")
            .accessibilityValue("\(setInput.distance) miles")
            .accessibilityHint("Double tap to edit distance")
    }
    
    private var weightTextField: some View {
        TextField("Weight", text: $weightInput)
            .focused($focusedField, equals: .weight)
            .multilineTextAlignment(.center)
            .onChange(of: focusedField) {
                if focusedField == .weight {
                    focusManager.isAnyTextFieldFocused = true
                    focusManager.currentlyFocusedField = .weight
                    weightInput = ""
                } else {
                    if weightInput.isEmpty {
                        weightInput = "\(setInput.weight)"
                        saveWorkoutDetail()
                    }
                }
            }
            .onChange(of: weightInput){
                guard focusedField == .weight, !weightInput.isEmpty else { return }
                validateAndSetInputFloat(&weightInput, for: &setInput.weight, maxLength: 5, maxDecimals: 2)
                weightModified = true
                saveWorkoutDetail()
                checkAutoComplete()
            }
            .onAppear {
                weightInput = "\(setInput.weight)"
            }
            .keyboardType(.decimalPad)
            .frame(width: 100, height: 20)
            .accessibilityLabel("Weight for set \(setIndex)")
            .accessibilityValue("\(setInput.weight) pounds")
            .accessibilityHint("Double tap to edit weight amount")
            .accessibilityIdentifier("weight_set_\(setIndex)")
    }
    
    private var timeTextField : some View {
        TextField("Time", text: $timeInput)
            .focused($focusedField, equals: .time)
            .multilineTextAlignment(.center)
            .onChange(of: focusedField) {
                if focusedField == .time {
                    originalTimeInput = timeInput
                    timeInput = "00:00:00"
                    focusManager.isAnyTextFieldFocused = true
                    focusManager.currentlyFocusedField = .time
                } else {
                    if timeInput == "00:00:00" {
                        timeInput = originalTimeInput
                    } else {
                        formatInput(timeInput)
                        if !timeInput.isEmpty && timeInput != originalTimeInput {
                            saveWorkoutDetail()
                        }
                    }
                }
            }
            .onChange(of: timeInput){
                formatInput(timeInput)
                if(!timeInput.isEmpty){
                    let formattedTime = formatTimeFromSeconds(totalSeconds: Int(setInput.time))
                    if formattedTime != "00:00:00" && timeInput != formattedTime {
                        timeModified = true
                        saveWorkoutDetail()
                        checkAutoComplete()
                    }
                }
            }
            .onAppear {
                let formattedTime = formatTimeFromSeconds(totalSeconds: Int(setInput.time))
                timeInput = "\(formattedTime)"
            }

            .frame(width: 100, height: 20)
            .keyboardType(.numberPad)
            .accessibilityLabel("Time for set \(setIndex)")
            .accessibilityValue(timeInput)
            .accessibilityHint("Double tap to edit time duration in hours, minutes, and seconds")
    }
    
    func saveWorkoutDetail() {
        guard let exerciseId = workoutDetails.exerciseId else {
            AppLogger.validation.warning("Cannot save workout detail - exerciseId is nil")

            // Show visual error feedback to user
            saveFailedError = true
            showSaveErrorMessage = true

            // Auto-hide error message after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showSaveErrorMessage = false
            }

            return
        }

        // Clear any previous errors on successful save
        saveFailedError = false
        showSaveErrorMessage = false

        let setsInput = [setInput]
        workoutController.workoutManager.saveOrUpdateSetsDuringActiveWorkout(workoutId: workoutId, exerciseId: exerciseId, exerciseName: workoutDetails.exerciseName, setsInput: setsInput, orderIndex: workoutDetails.orderIndex)
    }
    
    private func formatInput(_ newValue: String) {
        let filtered = newValue.filter { "0123456789".contains($0) }
        let digits = String(filtered.suffix(6))
        let padded = String(repeating: "0", count: max(0, 6 - digits.count)) + digits
        let h = String(padded.prefix(2))
        let m = String(padded.dropFirst(2).prefix(2))
        let s = String(padded.suffix(2))
        timeInput = "\(h):\(m):\(s)"
        let hVal = Int(h) ?? 0
        let mVal = Int(m) ?? 0
        let sVal = Int(s) ?? 0
        setInput.time = Int32(hVal * 3600 + mVal * 60 + sVal)
    }
    
    private func resetWorkoutDetails() {
        guard let updatedWorkoutDetails = workoutController.workoutDetails.first(where: { $0.id == workoutDetails.id }) else {
            return
        }

        // Validate array bounds before accessing
        let arrayIndex = setIndex - 1
        guard arrayIndex >= 0 && arrayIndex < updatedWorkoutDetails.sets.count else {
            AppLogger.validation.error("Invalid set index \(setIndex) for exercise with \(updatedWorkoutDetails.sets.count) sets")
            return
        }

        setInput = updatedWorkoutDetails.sets[arrayIndex]
        repsInput = "\(setInput.reps)"
        distanceInput = "\(setInput.distance)"
        weightInput = "\(setInput.weight)"
        timeInput = formatTimeFromSeconds(totalSeconds: Int(setInput.time))
        // checked is synced via onChange(of: setInput.isCompleted)
    }

    private func checkAutoComplete() {
        // Only auto-complete if both required fields have been MODIFIED and not already checked
        guard !checked else { return }

        var shouldAutoComplete = false

        if exerciseQuantifier == "Reps" && exerciseMeasurement == "Weight" {
            // Check if both reps and weight have been modified
            shouldAutoComplete = repsModified && weightModified && setInput.reps > 0 && setInput.weight > 0
        } else if exerciseQuantifier == "Reps" && exerciseMeasurement == "Time" {
            // Check if both reps and time have been modified
            shouldAutoComplete = repsModified && timeModified && setInput.reps > 0 && setInput.time > 0
        } else if exerciseQuantifier == "Distance" && exerciseMeasurement == "Weight" {
            // Check if both distance and weight have been modified
            shouldAutoComplete = distanceModified && weightModified && setInput.distance > 0 && setInput.weight > 0
        } else if exerciseQuantifier == "Distance" && exerciseMeasurement == "Time" {
            // Check if both distance and time have been modified
            shouldAutoComplete = distanceModified && timeModified && setInput.distance > 0 && setInput.time > 0
        }

        if shouldAutoComplete {
            checked = true
            setInput.isCompleted = true
            saveWorkoutDetail()
            // Haptic feedback for auto-completion
            HapticManager.shared.setCompleted()
        }
    }

}
