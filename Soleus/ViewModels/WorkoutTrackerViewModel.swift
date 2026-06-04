import Foundation
import SwiftUI

class WorkoutTrackerViewModel: ObservableObject {
    @Published var workouts: [WorkoutInfo] = []
    @Published var hasActiveSession = false
    @Published var activeWorkoutName: String?
    @Published var activeWorkoutId: UUID?
    @Published var workoutDetails: [WorkoutDetailInput] = []
    @Published var originalWorkoutDetails: [WorkoutDetailInput] = []
    @Published var cardColor: String? // new
    @Published var selectedWorkoutName: String?
    private let colorManager = ColorManager()


    var workoutManager: any WorkoutManaging

    init(workoutManager: any WorkoutManaging) {
        self.workoutManager = workoutManager
    }
    
    func loadWorkouts() {
        workoutManager.loadWorkoutsWithId()
        workouts = workoutManager.workouts
        updateActiveSession()
    }
    
    func moveExercise(from source: Int, to destination: Int) {
        guard source >= 0, destination >= 0, source < workoutDetails.count, destination < workoutDetails.count else { return }
        
        let item = workoutDetails.remove(at: source)
        workoutDetails.insert(item, at: destination)
        
        for (index, _) in workoutDetails.enumerated() {
            workoutDetails[index].orderIndex = Int32(index)
        }
    }
    
    func deleteExercise(at index: Int) {
        guard index >= 0, index < workoutDetails.count else { return }
        workoutDetails.remove(at: index)
    }
    
    func renameExercise(at index: Int, to newName: String) {
        guard index >= 0, index < workoutDetails.count else { return }
        workoutDetails[index].exerciseName = newName
    }
    
    func saveWorkoutColor(workoutId: UUID) {
        guard let color = cardColor else {
            AppLogger.workout.warning("Cannot save workout color: cardColor is nil")
            return
        }
        workoutManager.updateWorkoutColor(workoutId: workoutId, color: color)
    }
    
    func saveWorkout(title: String, update: Bool, workoutId: UUID) -> Result<Void, WorkoutSaveError> {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.emptyTitle)
        }
        guard !workoutDetails.isEmpty else {
            return .failure(.noExerciseDetails)
        }
        if update {
            if workoutManager.titleExists(title, excludingId: workoutId) {
                return .failure(.titleExists)
            }
        } else {
            if workoutManager.titleExists(title) {
                return .failure(.titleExists)
            }
        }
        
        if update {
            AppLogger.workout.debug("update workoutDetails")
            updateWorkoutDetails(for: workoutId, for: title)
        } else {
            workoutDetails.forEach { detail in
                guard let detailId = detail.id else {
                    AppLogger.workout.warning("Skipping workout detail with missing id")
                    return
                }
                workoutManager.addWorkoutDetail(
                    id: detailId,
                    workoutTitle: title,
                    exerciseName: detail.exerciseName,
                    color: colorManager.getRandomColor(),
                    orderIndex: Int32(detail.orderIndex),
                    sets: detail.sets,
                    exerciseMeasurement: detail.exerciseMeasurement,
                    exerciseQuantifier: detail.exerciseQuantifier,
                    notes: detail.notes
                )
            }
        }
        loadWorkouts()

        return .success(())
    }
    
    func setSessionStatus(workoutId: UUID, isActive: Bool){
        workoutManager.setSessionStatus(workoutId: workoutId, isActive: isActive)
        if(isActive == false){
            hasActiveSession = false
            activeWorkoutId = nil
        }
        if(isActive == true){
            hasActiveSession = true
            activeWorkoutId = workoutId
        }
    }
    
    
    func hasWorkoutChanged() -> Bool {
        guard originalWorkoutDetails.count == workoutDetails.count else { return true }
        
        for (index, originalDetail) in originalWorkoutDetails.enumerated() {
            let updatedDetail = workoutDetails[index]
            
            if originalDetail.exerciseId != updatedDetail.exerciseId ||
                originalDetail.exerciseName != updatedDetail.exerciseName ||
                originalDetail.orderIndex != updatedDetail.orderIndex ||
                originalDetail.notes != updatedDetail.notes ||
                originalDetail.sets.count != updatedDetail.sets.count {
                return true
            }
            
            
            for (setIndex, originalSet) in originalDetail.sets.enumerated() {
                let updatedSet = updatedDetail.sets[setIndex]
                
                if originalSet.reps != updatedSet.reps ||
                    originalSet.weight != updatedSet.weight ||
                    originalSet.time != updatedSet.time ||
                    originalSet.distance != updatedSet.distance {
                    return true
                }
            }
        }
        
        return false
    }
    
    func saveWorkoutHistory(elapsedTimeFormatted: String, workoutId: UUID, completion: (() -> Void)? = nil) {
        let totalWeightLifted = workoutDetails.reduce(0) { detailSum, detail in
            detailSum + detail.sets.reduce(0) { setSum, setInput in
                let reps = setInput.reps > 0 ? Float(setInput.reps) : 1
                return setSum + (Float(setInput.weight) * reps)
            }
        }


        let totalReps = workoutDetails.reduce(0) { detailSum, detail in
            detailSum + detail.sets.reduce(0) { setSum, setInput in
                setSum + Int(setInput.reps)
            }
        }

        let workoutTimeToComplete = elapsedTimeFormatted

        let totalCardioTime = workoutDetails.reduce(0) { detailSum, detail in
            detailSum + detail.sets.reduce(0) { setSum, setInput in
                setSum + Int(setInput.time)
            }
        }

        let totalDistance = workoutDetails.reduce(0) { detailSum, detail in
            detailSum + detail.sets.reduce(0) { setSum, setInput in
                setSum + Float(setInput.distance)
            }
        }

        workoutManager.saveWorkoutHistory(
            workoutId: workoutId,
            dateCompleted: Date(),
            totalWeightLifted: Float(totalWeightLifted),
            repsCompleted: Int32(totalReps),
            workoutTimeToComplete: workoutTimeToComplete,
            totalCardioTime: "\(totalCardioTime)",
            totalDistance: Float(totalDistance),
            workoutDetailsInput: workoutDetails,
            completion: completion
        )
    }
    
    func loadWorkoutDetails(for workoutId: UUID) {
        guard let workout = workoutManager.fetchWorkoutById(for: workoutId) else {
            AppLogger.workout.warning("Could not find workout with ID \(workoutId)")
            return
        }

        selectedWorkoutName = workout.name ?? ""
        var workoutDetailsList: [WorkoutDetailInput] = []
        
        if let detailsSet = workout.details as? Set<WorkoutDetail> {
            let details = detailsSet.sorted { $0.orderIndex < $1.orderIndex }
            workoutDetailsList = details.compactMap { detail in
                guard let exerciseName = detail.exerciseName,
                      let exerciseQuantifier = detail.exerciseQuantifier,
                      let exerciseMeasurement = detail.exerciseMeasurement else {
                    AppLogger.workout.warning("Skipping workout detail with missing required fields")
                    return nil
                }

                let sortedSets = (detail.sets?.allObjects as? [WorkoutSet])?.sorted(by: { $0.setIndex < $1.setIndex }) ?? []
                let setInputs = sortedSets.map { ws in
                    SetInput(id: ws.id, reps: ws.reps, weight: ws.weight, time: ws.time, distance: ws.distance, isCompleted: ws.isCompleted, setIndex: ws.setIndex)
                }

                return WorkoutDetailInput(
                    id: detail.id,
                    exerciseId: detail.exerciseId,
                    exerciseName: exerciseName,
                    notes: detail.notes,
                    orderIndex: detail.orderIndex,
                    sets: setInputs,
                    exerciseQuantifier: exerciseQuantifier,
                    exerciseMeasurement: exerciseMeasurement
                )
            }
        }
        
        self.workoutDetails = workoutDetailsList
    }
    
    func loadWorkoutColors(for workoutId: UUID) {
        guard let workout = workoutManager.fetchWorkoutById(for: workoutId) else {
            AppLogger.workout.warning("Could not find workout with ID \(workoutId)")
            return
        }
        
        cardColor = workout.color ?? "MyBlue"
        selectedWorkoutName = workout.name ?? ""
    }
    
    func loadTemporaryWorkoutDetails(for workoutId: UUID){
        let temporaryDetails = workoutManager.loadTemporaryWorkoutData(for: workoutId)
        
        for tempDetail in temporaryDetails {
            if let index = workoutDetails.firstIndex(where: { $0.exerciseId == tempDetail.exerciseId }) {
                var existingSets = workoutDetails[index].sets
                
                for tempSet in tempDetail.sets {
                    if let setIndex = existingSets.firstIndex(where: { $0.id == tempSet.id }) {
                        existingSets[setIndex] = tempSet
                    }
                }
                
                let sortedSets = existingSets.sorted { $0.setIndex < $1.setIndex }
                
                workoutDetails[index].sets = sortedSets
            } else {
                let sortedSets = tempDetail.sets.sorted(by: { $0.setIndex < $1.setIndex })
                var newTempDetail = tempDetail
                newTempDetail.sets = sortedSets
                workoutDetails.append(newTempDetail)
            }
        }
        workoutDetails.sort { $0.orderIndex < $1.orderIndex }
    }
    
    func addSet(for workoutIndex: Int) {
        guard workoutIndex < workoutDetails.count else { return }
        
        let maxSetIndex = workoutDetails[workoutIndex].sets.max(by: { $0.setIndex < $1.setIndex })?.setIndex ?? 0
        let newSetIndex = maxSetIndex + 1
        
        let newSet = workoutDetails[workoutIndex].sets.last.map {
            SetInput(reps: $0.reps, weight: $0.weight, time: $0.time, distance: $0.distance, setIndex: newSetIndex)
        } ?? SetInput(reps: 0, weight: 0, time: 0, distance: 0, setIndex: newSetIndex)
        
        self.workoutDetails[workoutIndex].sets.append(newSet)
    }
    
    func deleteSet(for workoutIndex: Int, setIndex: Int32) {
        guard workoutIndex < workoutDetails.count else { return }
        
        if let setIndexToDelete = workoutDetails[workoutIndex].sets.firstIndex(where: { $0.setIndex == setIndex }) {
            workoutDetails[workoutIndex].sets.remove(at: setIndexToDelete)
        }
    }
    
    private func updateActiveSession() {
        guard let activeSession = workoutManager.getSessions().first(where: { $0.isActive }) else {
            hasActiveSession = false
            return
        }
        
        hasActiveSession = true
        activeWorkoutId = activeSession.workoutsR?.id
        activeWorkoutName = activeSession.workoutsR?.name
    }
    
    func updateWorkoutDetails(for workoutId: UUID, for workoutTitle: String){
        let filledDetails = workoutDetails.filter { detail in
            guard !detail.exerciseName.isEmpty else { return false }
            guard !detail.exerciseName.isEmpty else { return false }
            
            return !detail.sets.isEmpty
        }
    
        workoutManager.updateWorkoutDetails(workoutId: workoutId, workoutDetailsInput: filledDetails)
        workoutManager.updateWorkoutTitle(workoutId: workoutId, to: workoutTitle)
    }
    
    func deleteWorkout(_ workoutId: UUID) {
        workoutManager.deleteWorkout(for: workoutId)
        loadWorkouts()
    }
    
    
    func duplicateWorkout(_ workoutId: UUID) {
        workoutManager.duplicateWorkout(originalWorkoutId: workoutId) { [weak self] in
            self?.loadWorkouts()
        }
    }

    func exportWorkout(_ workoutId: UUID) -> Data? {
        guard let workout = workoutManager.fetchWorkoutById(for: workoutId) else {
            AppLogger.workout.warning("Could not find workout with ID \(workoutId)")
            return nil
        }

        loadWorkoutDetails(for: workoutId)

        let workoutName = workout.name ?? "Untitled Workout"
        let workoutColor = workout.color

        return ShareableWorkout.export(
            workoutName: workoutName,
            workoutColor: workoutColor,
            workoutDetails: workoutDetails
        )
    }
}
