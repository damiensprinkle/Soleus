import SwiftUI
import OSLog

struct ExerciseRow: View {
    let setIndex: Int
    @Binding var setInput: SetInput
    @State private var repsInput: String = ""
    @State private var originalReps: String = ""
    
    @State private var weightInput: String = ""
    @State private var originalWeight: String = ""
    
    @State private var distanceInput: String = ""
    @State private var originalDistance: String = ""
    
    @State private var timeInput: String = ""
    @State private var originalTime: String = ""
    
    @FocusState private var focusedField: FocusableField?
    @EnvironmentObject var focusManager: FocusManager
    
    @AppStorage("weightPreference") private var weightPreference: String = "Lbs"
    @AppStorage("distancePreference") private var distancePreference: String = "Mile"
    
    var exerciseIndex: Int = 0
    var exerciseQuantifier: String
    var exerciseMeasurement: String
    
    var body: some View {
        HStack {
            Text("\(setIndex)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
                .padding(.leading, 8)
            Spacer()
            Divider()
            
            if exerciseQuantifier == "Reps" {
                TextField("Reps", text: $repsInput)
                    .focused($focusedField, equals: .reps)
                    .onChange(of: focusedField) {
                        if focusedField == .reps {
                            focusManager.currentlyFocusedField = .reps
                            focusManager.focusedExerciseIndex = exerciseIndex
                            originalReps = repsInput
                            repsInput = ""
                        } else {
                            focusManager.focusedExerciseIndex = nil
                            if repsInput.isEmpty {
                                repsInput = originalReps
                            }
                        }
                    }
                    .onChange(of: repsInput) {
                        validateAndSetInputInt(&repsInput, for: &setInput.reps, maxLength: 3)
                        if !repsInput.isEmpty {
                            let newReps = Int32(repsInput) ?? 0
                            if setInput.reps != newReps {
                                setInput.reps = newReps
                            }
                        }
                    }
                    .onAppear {
                        if repsInput.isEmpty {
                            repsInput = "\(setInput.reps)"
                            originalReps = repsInput
                        }
                    }
                    .keyboardType(.numberPad)
                    .frame(width: 100, height: 20)
            }
            
            
            if exerciseQuantifier == "Distance" {
                TextField("Distance", text: $distanceInput)
                    .focused($focusedField, equals: .distance)
                    .onChange(of: focusedField) {
                        if focusedField == .distance {
                            focusManager.currentlyFocusedField = .distance
                            focusManager.focusedExerciseIndex = exerciseIndex
                            originalDistance = distanceInput
                            distanceInput = ""
                        } else {
                            focusManager.focusedExerciseIndex = nil
                            if distanceInput.isEmpty {
                                distanceInput = originalDistance
                            } else if let floatValue = Float(distanceInput) {
                                let numberFormatter = NumberFormatter()
                                numberFormatter.minimumFractionDigits = 1
                                numberFormatter.maximumFractionDigits = 2
                                distanceInput = numberFormatter.string(from: NSNumber(value: floatValue)) ?? distanceInput
                            }
                        }
                    }
                    .onChange(of: distanceInput) {
                        validateAndSetInputFloat(&distanceInput, for: &setInput.distance, maxLength: 5, maxDecimals: 2)
                        if !distanceInput.isEmpty {
                            let newDistance = Float(distanceInput) ?? 0.0
                            if setInput.distance != newDistance {
                                setInput.distance = newDistance
                            }
                        }
                    }
                    .onAppear {
                        if distanceInput.isEmpty {
                            distanceInput = String(setInput.distance)
                            originalDistance = distanceInput
                        }
                    }
                    .keyboardType(.decimalPad)
                    .frame(width: 100, height: 20)
                Spacer()
            }
            
            Divider()
            
            if exerciseMeasurement == "Weight" {
                TextField("Weight", text: $weightInput)
                    .focused($focusedField, equals: .weight)
                    .onChange(of: focusedField) {
                        if focusedField == .weight {
                            focusManager.currentlyFocusedField = .weight
                            focusManager.focusedExerciseIndex = exerciseIndex
                            originalWeight = weightInput
                            weightInput = ""
                        } else {
                            focusManager.focusedExerciseIndex = nil
                            if weightInput.isEmpty {
                                weightInput = originalWeight
                            } else if let weightValue = Float(weightInput) {
                                weightInput = String(format: "%.1f", weightValue)
                            }
                        }
                    }
                    .onChange(of: weightInput) {
                        validateAndSetInputFloat(&weightInput, for: &setInput.weight, maxLength: 5, maxDecimals: 2)
                        if !weightInput.isEmpty {
                            let newWeight = Float(weightInput) ?? 0.0
                            if setInput.weight != newWeight {
                                setInput.weight = newWeight
                            }
                        }
                    }
                    .onAppear {
                        if weightInput.isEmpty {
                            weightInput = String(setInput.weight)
                            originalWeight = weightInput
                        }
                    }
                    .keyboardType(.decimalPad)
                    .frame(width: 100, height: 20)
            }
            
            if exerciseMeasurement == "Time" {
                TextField("Time", text: $timeInput)
                    .focused($focusedField, equals: .time)
                    .onChange(of: focusedField) {
                        if focusedField == .time {
                            focusManager.currentlyFocusedField = .time
                            focusManager.focusedExerciseIndex = exerciseIndex
                            originalTime = timeInput
                            timeInput = ""
                        } else {
                            focusManager.focusedExerciseIndex = nil
                            if timeInput.isEmpty {
                                timeInput = originalTime
                            }
                        }
                    }
                    .onChange(of: timeInput) {
                        formatInput(timeInput)
                    }
                    .onAppear {
                        if timeInput.isEmpty {
                            let formattedTime = formatTimeFromSeconds(totalSeconds: Int(setInput.time))
                            timeInput = "\(formattedTime)"
                            originalTime = timeInput
                        }
                    }
                    .keyboardType(.numberPad)
                    .frame(width: 100, height: 20)
            }
        }
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
    
}
