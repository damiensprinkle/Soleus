import Foundation
import UIKit
import CoreData
import OSLog

class WorkoutManager: ObservableObject, WorkoutManaging {
    var context: NSManagedObjectContext? {
        didSet {
            AppLogger.coreData.info("Context set in WorkoutManager")
            if let context = context {
                loadWorkoutsWithId()
                context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                // Automatically merge changes from background contexts
                context.automaticallyMergesChangesFromParent = true
            }
        }
    }

    @Published var workouts: [WorkoutInfo] = []
    var errorHandler: ErrorHandler?
    var healthKitManager: HealthKitManager?
    var exerciseLibrary: ExerciseLibraryManager?

    // MARK: - Background Context Helpers

    /// Creates a background context for performing heavy operations off the main thread
    private func createBackgroundContext() -> NSManagedObjectContext? {
        guard let context = self.context else { return nil }

        let backgroundContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        backgroundContext.parent = context
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return backgroundContext
    }

    /// Saves a background context and propagates changes to parent context
    private func saveBackgroundContext(_ backgroundContext: NSManagedObjectContext, completion: @escaping (Result<Void, CoreDataError>) -> Void) {
        backgroundContext.perform {
            do {
                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }

                // Save parent context on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let mainContext = self.context else {
                        completion(.failure(.contextNotAvailable))
                        return
                    }

                    do {
                        if mainContext.hasChanges {
                            try mainContext.save()
                        }
                        completion(.success(()))
                    } catch {
                        completion(.failure(.saveFailed(error)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.saveFailed(error)))
                }
            }
        }
    }
    
    
    // MARK: Core Data Operations
    
    func addWorkoutDetail(id: UUID, workoutTitle: String, exerciseName: String, color: String , orderIndex: Int32, sets: [SetInput], exerciseMeasurement: String, exerciseQuantifier: String, notes: String? = nil, restDuration: Int32 = 0) {
        guard let context = self.context,
              let workout = findOrCreateWorkout(withTitle: workoutTitle, color: color) else { return }

        // Create and configure a new WorkoutDetail instance
        let newExerciseDetail = WorkoutDetail(context: context)
        newExerciseDetail.id = id
        newExerciseDetail.exerciseId = UUID()
        newExerciseDetail.exerciseName = exerciseName
        newExerciseDetail.orderIndex = orderIndex
        newExerciseDetail.exerciseQuantifier = exerciseQuantifier
        newExerciseDetail.exerciseMeasurement = exerciseMeasurement
        newExerciseDetail.notes = notes
        newExerciseDetail.restDuration = restDuration
        exerciseLibrary?.recordUsage(name: exerciseName, quantifier: exerciseQuantifier, measurement: exerciseMeasurement)
        AppLogger.workout.debug("Adding exercise '\(exerciseName)' at order index \(orderIndex)")
        // Add sets to the exercise detail
        for setInput in sets {
            let newSet = WorkoutSet(context: context)
            newSet.id = setInput.id ?? UUID()
            newSet.reps = setInput.reps
            newSet.weight = setInput.weight
            newSet.time = setInput.time
            newSet.distance = setInput.distance
            newSet.setIndex = setInput.setIndex
            newExerciseDetail.addToSets(newSet)
        }

        workout.addToDetails(newExerciseDetail)

        let result = saveContext()
        switch result {
        case .success:
            AppLogger.workout.info("Created exercise with ID: \(String(describing: newExerciseDetail.exerciseId)) for workout: \(String(describing: workout.id))")
        case .failure(let error):
            AppLogger.coreData.error("Error saving workout: \(error.localizedDescription)")
            errorHandler?.handle(error)
        }
    }
    
    func saveOrUpdateSetsDuringActiveWorkout(workoutId: UUID, exerciseId: UUID, exerciseName: String, setsInput: [SetInput], orderIndex: Int32) {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        // Fetch the Workout entity directly
        let workoutRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
        workoutRequest.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)

        do {
            guard let workout = try context.fetch(workoutRequest).first else {
                AppLogger.workout.error("No workout found with ID: \(workoutId)")
                errorHandler?.handle(.workoutNotFound(workoutId))
                return
            }

            if let tempDetails = workout.detailsTemp as? Set<TemporaryWorkoutDetail> {
                // Check if there's an existing detail for this exercise

                let detailToUpdate: TemporaryWorkoutDetail
                if let existingDetail = tempDetails.first(where: { $0.exerciseId == exerciseId }) {
                    context.refresh(existingDetail, mergeChanges: true) // Refresh the object
                    detailToUpdate = existingDetail
                } else {
                    // Create a new TemporaryWorkoutDetail
                    detailToUpdate = TemporaryWorkoutDetail(context: context)
                    detailToUpdate.id = UUID()
                    detailToUpdate.exerciseId = exerciseId
                    detailToUpdate.exerciseName = exerciseName
                    detailToUpdate.orderIndex = orderIndex
                    workout.addToDetailsTemp(detailToUpdate)
                }

                // Update or add sets to the detail
                updateOrAddSetsForTempDetail(forDetail: detailToUpdate, withSetsInput: setsInput, inContext: context)

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            AppLogger.coreData.error("Failed to save or update temporary workout details: \(error.localizedDescription)")
            errorHandler?.handle(.saveFailed(error))
        }
    }

    func updateExerciseNotesDuringActiveWorkout(workoutId: UUID, exerciseId: UUID, notes: String?) {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        // Fetch the Workout entity
        let workoutRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
        workoutRequest.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)

        do {
            guard let workout = try context.fetch(workoutRequest).first else {
                AppLogger.workout.error("No workout found with ID: \(workoutId)")
                errorHandler?.handle(.workoutNotFound(workoutId))
                return
            }

            if let tempDetails = workout.detailsTemp as? Set<TemporaryWorkoutDetail> {
                // Find the existing detail for this exercise
                if let existingDetail = tempDetails.first(where: { $0.exerciseId == exerciseId }) {
                    context.refresh(existingDetail, mergeChanges: true)
                    existingDetail.notes = notes

                    if context.hasChanges {
                        try context.save()
                        AppLogger.workout.info("Exercise notes updated for exerciseId: \(exerciseId)")
                    }
                } else {
                    AppLogger.workout.warning("No temporary workout detail found for exerciseId: \(exerciseId)")
                }
            }
        } catch {
            AppLogger.coreData.error("Failed to update exercise notes: \(error.localizedDescription)")
            errorHandler?.handle(.saveFailed(error))
        }
    }

    func addExerciseDuringActiveWorkout(workoutId: UUID, exerciseName: String, orderIndex: Int32, exerciseQuantifier: String, exerciseMeasurement: String, sets: [SetInput], notes: String? = nil) -> UUID? {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return nil
        }

        // Fetch the Workout entity
        let workoutRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
        workoutRequest.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)

        do {
            guard let workout = try context.fetch(workoutRequest).first else {
                AppLogger.workout.error("No workout found with ID: \(workoutId)")
                errorHandler?.handle(.workoutNotFound(workoutId))
                return nil
            }

            // Generate a new exerciseId
            let newExerciseId = UUID()

            // Create a new TemporaryWorkoutDetail
            let newTempDetail = TemporaryWorkoutDetail(context: context)
            newTempDetail.id = UUID()
            newTempDetail.exerciseId = newExerciseId
            newTempDetail.exerciseName = exerciseName
            newTempDetail.orderIndex = orderIndex
            newTempDetail.exerciseQuantifier = exerciseQuantifier
            newTempDetail.exerciseMeasurement = exerciseMeasurement
            newTempDetail.notes = notes
            exerciseLibrary?.recordUsage(name: exerciseName, quantifier: exerciseQuantifier, measurement: exerciseMeasurement)

            // Add initial sets
            for setInput in sets {
                let newSet = WorkoutSet(context: context)
                newSet.id = setInput.id ?? UUID()
                newSet.reps = setInput.reps
                newSet.weight = setInput.weight
                newSet.time = setInput.time
                newSet.distance = setInput.distance
                newSet.isCompleted = setInput.isCompleted
                newSet.setIndex = setInput.setIndex
                newTempDetail.addToSets(newSet)
            }

            // Add to workout
            workout.addToDetailsTemp(newTempDetail)

            if context.hasChanges {
                try context.save()
                AppLogger.workout.info("New exercise '\(exerciseName)' added during active workout with exerciseId: \(newExerciseId)")
            }

            return newExerciseId

        } catch {
            AppLogger.coreData.error("Failed to add exercise during active workout: \(error.localizedDescription)")
            errorHandler?.handle(.saveFailed(error))
            return nil
        }
    }

    private func updateOrAddSetsForTempDetail(forDetail tempDetail: TemporaryWorkoutDetail, withSetsInput setsInput: [SetInput], inContext context: NSManagedObjectContext) {
        let existingSets = tempDetail.sets as? Set<WorkoutSet> ?? Set()
        
        setsInput.forEach { setInput in
            let set: WorkoutSet
            if let existingSet = existingSets.first(where: { $0.id == setInput.id }) {
                set = existingSet
            } else {
                set = WorkoutSet(context: context)
                tempDetail.addToSets(set)
            }
            
            set.id = setInput.id ?? UUID()
            set.reps = setInput.reps
            set.weight = setInput.weight
            set.time = setInput.time
            set.distance = setInput.distance
            set.isCompleted = setInput.isCompleted
            set.setIndex = setInput.setIndex
        }
    }
    
    func deleteAllTemporaryWorkoutDetails() {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TemporaryWorkoutDetail.fetchRequest()

        // Create a batch delete request using the fetch request
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            // Execute the batch delete and properly validate the result
            guard let result = try context.execute(deleteRequest) as? NSBatchDeleteResult else {
                AppLogger.coreData.warning("Batch delete returned unexpected result type")
                return
            }

            // Validate that we got object IDs back
            guard let objectIDArray = result.result as? [NSManagedObjectID], !objectIDArray.isEmpty else {
                AppLogger.coreData.info("No temporary workout details to delete")
                return
            }

            AppLogger.coreData.info("Successfully deleted \(objectIDArray.count) temporary workout details")

            // Properly merge the changes into the context
            let changes = [NSDeletedObjectsKey: objectIDArray]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable : Any], into: [context])

            // Refresh to ensure the context is clean
            context.refreshAllObjects()

        } catch let error as NSError {
            AppLogger.coreData.error("Failed to delete temporary workout details: \(error.localizedDescription)")
            errorHandler?.handle(.deleteFailed(error))
        }
    }
    
    private func saveContext() -> Result<Void, CoreDataError> {
        guard let context = self.context else {
            return .failure(.contextNotAvailable)
        }

        guard context.hasChanges else {
            return .success(()) // No changes to save
        }

        do {
            try context.save()
            loadWorkoutsWithId()
            return .success(())
        } catch {
            return .failure(.saveFailed(error))
        }
    }
    
    //good
    private func findOrCreateWorkout(withTitle title: String, color: String) -> Workouts? {
        guard let context = self.context else {
            AppLogger.coreData.error("CoreData context unavailable when creating workout")
            return nil
        }

        let request = NSFetchRequest<Workouts>(entityName: "Workouts")
        request.predicate = NSPredicate(format: "name == %@", title)

        if let existingWorkout = (try? context.fetch(request))?.first {
            return existingWorkout
        } else {
            // Get the maximum orderIndex
            let maxOrderRequest = NSFetchRequest<Workouts>(entityName: "Workouts")
            maxOrderRequest.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: false)]
            maxOrderRequest.fetchLimit = 1
            let maxOrderIndex = (try? context.fetch(maxOrderRequest))?.first?.orderIndex ?? -1

            let newWorkout = Workouts(context: context)
            newWorkout.id = UUID()
            newWorkout.name = title
            newWorkout.color = color
            newWorkout.orderIndex = maxOrderIndex + 1
            return newWorkout
        }
    }
    
    func fetchWorkoutById(for workoutId: UUID) -> Workouts? {
        guard let context = self.context else {
            return nil
        }
        let request = NSFetchRequest<Workouts>(entityName: "Workouts")
        request.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)
        do {
            let result = try context.fetch(request)
            return result.first
        } catch {
            AppLogger.coreData.error("Error fetching workout by ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Weekly Schedule

    func scheduledDays(for workoutId: UUID) -> Set<Int> {
        guard let workout = fetchWorkoutById(for: workoutId) else { return [] }
        return WorkoutSchedule.parse(workout.scheduledDays)
    }

    func setScheduledDays(_ days: Set<Int>, for workoutId: UUID) {
        guard let workout = fetchWorkoutById(for: workoutId) else {
            AppLogger.workout.warning("Cannot schedule workout: no workout found for id \(workoutId)")
            return
        }
        workout.scheduledDays = WorkoutSchedule.serialize(days)

        if case .failure(let error) = saveContext() {
            AppLogger.coreData.error("Error saving workout schedule: \(error.localizedDescription)")
            errorHandler?.handle(error)
        }
    }

    /// All scheduled workouts keyed by Calendar weekday number (1 = Sunday … 7 = Saturday).
    /// Workouts within a day keep the card grid's orderIndex order.
    func weeklySchedule() -> [Int: [WorkoutInfo]] {
        guard let context = self.context else { return [:] }

        let request = NSFetchRequest<Workouts>(entityName: "Workouts")
        request.predicate = NSPredicate(format: "scheduledDays != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]

        var schedule: [Int: [WorkoutInfo]] = [:]
        do {
            for workout in try context.fetch(request) {
                guard let id = workout.id, let name = workout.name else { continue }
                for day in WorkoutSchedule.parse(workout.scheduledDays) {
                    schedule[day, default: []].append(WorkoutInfo(id: id, name: name))
                }
            }
        } catch {
            AppLogger.coreData.error("Failed to fetch weekly schedule: \(error.localizedDescription)")
            errorHandler?.handle(.fetchFailed(error))
        }
        return schedule
    }

    /// IDs of workouts that have a history entry on the given calendar day.
    func completedWorkoutIds(on date: Date) -> Set<UUID> {
        guard let context = self.context else { return [] }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }

        let request: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        request.predicate = NSPredicate(format: "workoutDate >= %@ AND workoutDate < %@", dayStart as NSDate, dayEnd as NSDate)

        do {
            let histories = try context.fetch(request)
            return Set(histories.compactMap { $0.workoutR?.id })
        } catch {
            AppLogger.coreData.error("Failed to fetch completed workouts for day: \(error.localizedDescription)")
            return []
        }
    }

    func duplicateWorkout(originalWorkoutId: UUID, completion: (() -> Void)? = nil) {
        guard let backgroundContext = createBackgroundContext() else {
            AppLogger.coreData.error("Failed to create background context")
            errorHandler?.handle(.contextNotAvailable)
            completion?()
            return
        }

        // Perform heavy duplication on background thread
        backgroundContext.perform { [weak self] in
            // Fetch original workout in background context
            let fetchRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", originalWorkoutId as CVarArg)

            do {
                guard let originalWorkout = try backgroundContext.fetch(fetchRequest).first else {
                    DispatchQueue.main.async {
                        AppLogger.workout.error("Failed to fetch original workout with ID \(originalWorkoutId)")
                        self?.errorHandler?.handle(.workoutNotFound(originalWorkoutId))
                        completion?()
                    }
                    return
                }

                let newWorkout = Workouts(context: backgroundContext)
                newWorkout.id = UUID()
                newWorkout.name = Self.uniqueCopyName(for: originalWorkout.name ?? "", in: backgroundContext)
                newWorkout.color = originalWorkout.color

                // Copy all details from the original workout to the new workout
                if let originalDetails = originalWorkout.details as? Set<WorkoutDetail> {
                    for originalDetail in originalDetails {
                        let newDetail = WorkoutDetail(context: backgroundContext)
                        newDetail.id = UUID()
                        newDetail.exerciseId = UUID()
                        newDetail.exerciseName = originalDetail.exerciseName
                        newDetail.orderIndex = originalDetail.orderIndex
                        newDetail.exerciseQuantifier = originalDetail.exerciseQuantifier
                        newDetail.exerciseMeasurement = originalDetail.exerciseMeasurement
                        newDetail.restDuration = originalDetail.restDuration

                        // Copy all sets from the original detail to the new detail
                        if let originalSets = originalDetail.sets as? Set<WorkoutSet> {
                            for originalSet in originalSets {
                                let newSet = WorkoutSet(context: backgroundContext)
                                newSet.id = UUID()
                                newSet.reps = originalSet.reps
                                newSet.weight = originalSet.weight
                                newSet.time = originalSet.time
                                newSet.distance = originalSet.distance
                                newSet.setIndex = originalSet.setIndex
                                newDetail.addToSets(newSet)
                            }
                        }

                        newWorkout.addToDetails(newDetail)
                    }
                }

                // Save background context
                try backgroundContext.save()

                // Save parent context on main thread
                DispatchQueue.main.async {
                    guard let mainContext = self?.context else {
                        completion?()
                        return
                    }
                    do {
                        if mainContext.hasChanges {
                            try mainContext.save()
                        }
                        AppLogger.workout.info("Successfully duplicated workout with ID: \(originalWorkoutId)")
                        completion?()
                    } catch {
                        AppLogger.coreData.error("Error saving main context: \(error.localizedDescription)")
                        self?.errorHandler?.handle(.saveFailed(error))
                        completion?()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    AppLogger.coreData.error("Error duplicating workout: \(error.localizedDescription)")
                    self?.errorHandler?.handle(.saveFailed(error))
                    completion?()
                }
            }
        }
    }
    
    
    
    func loadWorkoutsWithId() {
        guard let context = self.context else {
            AppLogger.coreData.error("Context is nil in loadWorkoutsWithId")
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        let request = NSFetchRequest<Workouts>(entityName: "Workouts")
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        do {
            let results = try context.fetch(request)
            let mapped = results.compactMap { workout -> WorkoutInfo? in
                guard let id = workout.id, let name = workout.name else {
                    AppLogger.validation.warning("Skipping workout with missing id or name")
                    return nil
                }
                return WorkoutInfo(id: id, name: name)
            }
            if Thread.isMainThread {
                self.workouts = mapped
                AppLogger.workout.debug("Loaded \(self.workouts.count) workouts")
            } else {
                DispatchQueue.main.async {
                    self.workouts = mapped
                    AppLogger.workout.debug("Loaded \(self.workouts.count) workouts")
                }
            }

        } catch {
            AppLogger.coreData.error("Failed to fetch workouts: \(error.localizedDescription)") 
            errorHandler?.handle(.fetchFailed(error))
        }
    }
    
    
    func deleteWorkout(for workoutId: UUID) {
        guard let backgroundContext = createBackgroundContext() else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        // Perform heavy delete operation on background thread
        backgroundContext.perform { [weak self] in
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "Workouts")
            fetchRequest.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)

            do {
                let workoutsToDelete = try backgroundContext.fetch(fetchRequest) as? [Workouts] ?? []

                guard !workoutsToDelete.isEmpty else {
                    DispatchQueue.main.async {
                        self?.errorHandler?.handle(.workoutNotFound(workoutId))
                    }
                    return
                }

                let deletedOrderIndex = workoutsToDelete.first?.orderIndex ?? 0

                for workout in workoutsToDelete {
                    // IMPORTANT: Preserve WorkoutHistory for achievements!
                    // Break the relationship instead of deleting history records
                    if let histories = workout.history as? Set<WorkoutHistory> {
                        for history in histories {
                            history.workoutR = nil
                        }
                    }

                    // Cascade delete rules will automatically handle:
                    // - WorkoutDetail (details relationship) and their WorkoutSets
                    // - TemporaryWorkoutDetail (detailsTemp relationship) and their WorkoutSets
                    // - WorkoutSession (sessions relationship)
                    // WorkoutHistory is preserved but relationship is broken above
                    backgroundContext.delete(workout)
                }

                // Reindex remaining workouts
                let reindexRequest = NSFetchRequest<Workouts>(entityName: "Workouts")
                reindexRequest.predicate = NSPredicate(format: "orderIndex > %d", deletedOrderIndex)
                if let remainingWorkouts = try? backgroundContext.fetch(reindexRequest) {
                    for workout in remainingWorkouts {
                        workout.orderIndex -= 1
                    }
                }

                // Save background context
                try backgroundContext.save()

                // Save parent context on main thread
                DispatchQueue.main.async {
                    guard let mainContext = self?.context else { return }
                    do {
                        if mainContext.hasChanges {
                            try mainContext.save()
                        }
                        AppLogger.workout.info("Workout and its associated entities deleted successfully")
                    } catch {
                        AppLogger.coreData.error("Error saving main context: \(error.localizedDescription)")
                        self?.errorHandler?.handle(.deleteFailed(error))
                    }
                }
            } catch let error as NSError {
                DispatchQueue.main.async {
                    AppLogger.coreData.error("Error deleting workout: \(error.localizedDescription)")
                    self?.errorHandler?.handle(.deleteFailed(error))
                }
            }
        }
    }
    
    
    func deleteWorkoutHistory(for historyId: UUID) {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "WorkoutHistory")
        fetchRequest.predicate = NSPredicate(format: "id == %@", historyId as CVarArg)

        do {
            let workoutsToDelete = try context.fetch(fetchRequest) as? [WorkoutHistory] ?? []

            for workout in workoutsToDelete {
                context.delete(workout)
            }

            try context.save()
            AppLogger.workout.info("Workout history deleted successfully")
        } catch let error as NSError {
            AppLogger.coreData.error("Error deleting workout history: \(error.localizedDescription)")
            errorHandler?.handle(.deleteFailed(error))
        }
    }
    
    func updateWorkoutTitle(workoutId: UUID, to newTitle: String) {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        // Fetch WorkoutDetail by ID
        let request = NSFetchRequest<Workouts>(entityName: "Workouts")
        request.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)
        do {
            let results = try context.fetch(request)

            guard !results.isEmpty else {
                errorHandler?.handle(.workoutNotFound(workoutId))
                return
            }

            results.forEach { detail in
                detail.name = newTitle
            }

            try context.save()

            // Update the local workouts array
            if let index = workouts.firstIndex(where: { $0.id == workoutId }) {
                workouts[index].name = newTitle
            }

            // Notify observers of the change
            objectWillChange.send()
        } catch {
            AppLogger.coreData.error("Error updating workout title: \(error.localizedDescription)")
            errorHandler?.handle(.saveFailed(error))
        }
    }
    
    
    func updateWorkoutColor(workoutId: UUID, color: String) {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        guard let workout = fetchWorkoutById(for: workoutId) else {
            AppLogger.workout.error("Failed to fetch workout for ID \(workoutId)")
            errorHandler?.handle(.workoutNotFound(workoutId))
            return
        }

        workout.color = color
        do {
            try context.save()
        } catch {
            AppLogger.coreData.error("Error saving context after updating workout color: \(error.localizedDescription)")
            errorHandler?.handle(.saveFailed(error))
        }
    }
    
    
    
    
    func updateWorkoutDetails(workoutId: UUID, workoutDetailsInput: [WorkoutDetailInput]) {
        guard let context = self.context else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        guard let workout = fetchWorkoutById(for: workoutId) else {
            AppLogger.workout.error("Failed to fetch workout for ID \(workoutId)")
            errorHandler?.handle(.workoutNotFound(workoutId))
            return
        }

        let existingDetails = workout.details as? Set<WorkoutDetail> ?? Set()
        let existingDetailsMap = existingDetails.reduce(into: [UUID: WorkoutDetail]()) { result, detail in
            if let exerciseId = detail.exerciseId {
                result[exerciseId] = detail
            }
        }

        workoutDetailsInput.forEach { inputDetail in
            let detail: WorkoutDetail
            if let exerciseId = inputDetail.exerciseId, let existingDetail = existingDetailsMap[exerciseId] {
                detail = existingDetail
            } else {
                detail = WorkoutDetail(context: context)
                workout.addToDetails(detail)
                detail.exerciseId = inputDetail.exerciseId ?? UUID()
                // Only newly added exercises count toward library usage —
                // re-saving an existing plan shouldn't inflate the counts.
                exerciseLibrary?.recordUsage(name: inputDetail.exerciseName, quantifier: inputDetail.exerciseQuantifier, measurement: inputDetail.exerciseMeasurement)
            }

            detail.exerciseName = inputDetail.exerciseName
            detail.orderIndex = inputDetail.orderIndex
            detail.exerciseQuantifier = inputDetail.exerciseQuantifier
            detail.exerciseMeasurement = inputDetail.exerciseMeasurement
            detail.notes = inputDetail.notes
            detail.restDuration = inputDetail.restDuration
            updateOrAddSets(forDetail: detail, withSetsInput: inputDetail.sets, inContext: context)
        }

        existingDetails.forEach { existingDetail in
            if !workoutDetailsInput.contains(where: { $0.exerciseId == existingDetail.exerciseId }) {
                if let sets = existingDetail.sets as? Set<WorkoutSet> {
                    sets.forEach { context.delete($0) }
                }
                context.delete(existingDetail)
            }
        }

        do {
            try context.save()
        } catch {
            AppLogger.coreData.error("Error saving context after updating workout details: \(error.localizedDescription)")
            errorHandler?.handle(.saveFailed(error))
        }
    }
    
    private func updateOrAddSets(forDetail detail: WorkoutDetail, withSetsInput setsInput: [SetInput], inContext context: NSManagedObjectContext) {
        let existingSets = detail.sets as? Set<WorkoutSet> ?? Set()
        
        setsInput.forEach { setInput in
            let set: WorkoutSet
            if let existingSet = existingSets.first(where: { $0.id == setInput.id }) {
                set = existingSet
            } else {
                set = WorkoutSet(context: context)
                detail.addToSets(set)
            }
            
            set.id = setInput.id ?? UUID()
            set.reps = setInput.reps
            set.weight = setInput.weight
            set.time = setInput.time
            set.distance = setInput.distance
            set.setIndex = setInput.setIndex
        }
        
        existingSets.forEach { existingSet in
            if !setsInput.contains(where: { $0.id == existingSet.id }) {
                context.delete(existingSet)
            }
        }
    }
}

extension WorkoutManager {
    
    func titleExists(_ title: String) -> Bool {
        guard let context = self.context else { return false }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Workouts")
        request.predicate = NSPredicate(format: "name ==[c] %@", title)
        request.includesSubentities = false

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            AppLogger.coreData.error("Error checking title existence: \(error.localizedDescription)")
            return false
        }
    }

    /// Returns a unique copy name for the given base title, e.g. "Push Day-copy", "Push Day-copy 2", etc.
    private static func uniqueCopyName(for baseName: String, in context: NSManagedObjectContext) -> String {
        let base = "\(baseName)-copy"
        var candidate = base
        var counter = 2

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Workouts")
        request.includesSubentities = false

        while true {
            request.predicate = NSPredicate(format: "name ==[c] %@", candidate)
            let count = (try? context.count(for: request)) ?? 0
            if count == 0 { return candidate }
            candidate = "\(base) \(counter)"
            counter += 1
        }
    }

    func titleExists(_ title: String, excludingId: UUID) -> Bool {
        guard let context = self.context else { return false }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Workouts")
        request.predicate = NSPredicate(format: "name ==[c] %@ AND id != %@", title, excludingId as CVarArg)
        request.includesSubentities = false

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            AppLogger.coreData.error("Error checking title existence (excluding id): \(error.localizedDescription)")
            return false
        }
    }
    
    func getSessions() -> [WorkoutSession] {
        guard let context = self.context else { return [] }
        let request = NSFetchRequest<WorkoutSession>(entityName: "WorkoutSession")
        request.predicate = NSPredicate(format: "isActive == %@", NSNumber(value: true))
        
        do {
            return try context.fetch(request)
        } catch {
            AppLogger.coreData.error("Error fetching active sessions: \(error.localizedDescription)")
            return []
        }
    }
    
    func getWorkoutIdOfActiveSession() -> UUID? {
        guard let context = self.context else { return nil }
        let request = NSFetchRequest<WorkoutSession>(entityName: "WorkoutSession")
        let currentDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? ""
        request.predicate = NSPredicate(
            format: "isActive == true AND (deviceIdentifier == %@ OR deviceIdentifier == nil)",
            currentDeviceId
        )
        
        do {
            if let activeSession = try context.fetch(request).first {
                return activeSession.workoutsR?.id
            }
        } catch {
            AppLogger.coreData.error("Error fetching active sessions: \(error.localizedDescription)")
        }

        return nil
    }
    
    func loadTemporaryWorkoutData(for workoutId: UUID) -> [WorkoutDetailInput] {
        guard let context = self.context else { return [] }
        
        let workoutRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
        workoutRequest.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)
        
        do {
            guard let workout = try context.fetch(workoutRequest).first else {
                AppLogger.workout.warning("No workout found with ID: \(workoutId)")
                return []
            }

            if let tempDetails = workout.detailsTemp as? Set<TemporaryWorkoutDetail> {
                return tempDetails.sorted(by: { $0.orderIndex < $1.orderIndex }).map { tempDetail in
                    let sets = tempDetail.sets?.allObjects as? [WorkoutSet] ?? []
                    return WorkoutDetailInput(
                        id: tempDetail.id,
                        exerciseId: tempDetail.exerciseId,
                        exerciseName: tempDetail.exerciseName ?? "",
                        orderIndex: tempDetail.orderIndex,
                        sets: sets.map { SetInput(id: $0.id, reps: $0.reps, weight: $0.weight, time: $0.time, distance: $0.distance, isCompleted: $0.isCompleted, setIndex: $0.setIndex) }
                    )
                }
            }
        } catch {
            AppLogger.coreData.error("Failed to load temporary workout data: \(error.localizedDescription)")
        }

        return []
    }
    
    func saveWorkoutHistory(workoutId: UUID, dateCompleted: Date, totalWeightLifted: Float, repsCompleted: Int32, workoutTimeToComplete: String, totalCardioTime: String, totalDistance: Float, workoutDetailsInput: [WorkoutDetailInput], completion: (() -> Void)? = nil) {
        guard let backgroundContext = createBackgroundContext() else {
            errorHandler?.handle(.contextNotAvailable)
            completion?()
            return
        }

        // Capture session start time before entering background context
        let sessionStartTime: Date = {
            let req: NSFetchRequest<WorkoutSession> = WorkoutSession.fetchRequest()
            req.predicate = NSPredicate(format: "workoutsR.id == %@", workoutId as CVarArg)
            req.fetchLimit = 1
            let sessions = try? self.context?.fetch(req)
            return sessions?.first?.startTime
                ?? dateCompleted.addingTimeInterval(-Double(convertToSeconds(workoutTimeToComplete)))
        }()

        // Perform heavy save operation on background thread
        backgroundContext.perform { [weak self] in
            // Fetch workout in background context
            let fetchRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)

            do {
                guard let workout = try backgroundContext.fetch(fetchRequest).first else {
                    DispatchQueue.main.async {
                        self?.errorHandler?.handle(.workoutNotFound(workoutId))
                        completion?()
                    }
                    return
                }

                let history = WorkoutHistory(context: backgroundContext)
                history.id = UUID()
                history.workoutDate = dateCompleted
                history.totalWeightLifted = totalWeightLifted
                history.repsCompleted = repsCompleted
                history.workoutTimeToComplete = workoutTimeToComplete
                history.totalDistance = totalDistance
                history.timeDoingCardio = totalCardioTime
                history.workoutR = workout

                for detailInput in workoutDetailsInput {
                    let detail = WorkoutDetail(context: backgroundContext)
                    detail.id = detailInput.id ?? UUID()
                    detail.exerciseId = detailInput.exerciseId
                    detail.exerciseName = detailInput.exerciseName
                    detail.orderIndex = detailInput.orderIndex
                    detail.history = history
                    detail.exerciseQuantifier = detailInput.exerciseQuantifier
                    detail.exerciseMeasurement = detailInput.exerciseMeasurement

                    for setInput in detailInput.sets {
                        let set = WorkoutSet(context: backgroundContext)
                        set.id = setInput.id ?? UUID()
                        set.reps = setInput.reps
                        set.weight = setInput.weight
                        set.time = setInput.time
                        set.distance = setInput.distance
                        set.details = detail
                    }
                }

                // Save background context
                try backgroundContext.save()

                // Save parent context on main thread
                DispatchQueue.main.async {
                    guard let mainContext = self?.context else {
                        completion?()
                        return
                    }
                    do {
                        if mainContext.hasChanges {
                            try mainContext.save()
                        }
                        AppLogger.workout.info("Workout history saved successfully")
                        // Reschedule inactivity reminder from today and clear streak reminder
                        // (user just completed a workout, so streak is safe for today)
                        let days = UserDefaults.standard.integer(forKey: "inactivityReminderDays")
                        let hour = UserDefaults.standard.integer(forKey: "inactivityReminderHour")
                        NotificationManager.scheduleInactivityReminder(afterDays: days > 0 ? days : 3, hour: hour > 0 ? hour : 9)
                        NotificationManager.cancelStreakReminder()
                        self?.healthKitManager?.saveWorkout(
                            startTime: sessionStartTime,
                            endTime: dateCompleted,
                            totalDistance: totalDistance,
                            workoutDetailsInput: workoutDetailsInput
                        )
                        completion?()
                    } catch {
                        AppLogger.coreData.error("Failed to save main context: \(error.localizedDescription)")
                        self?.errorHandler?.handle(.saveFailed(error))
                        completion?()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    AppLogger.coreData.error("Failed to save workout history: \(error.localizedDescription)")
                    self?.errorHandler?.handle(.saveFailed(error))
                    completion?()
                }
            }
        }
    }
    
    func fetchLatestWorkoutHistory(for workoutId: UUID) -> WorkoutHistory? {
        guard let context = self.context else { return nil }
        
        let fetchRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "workoutR.id == %@", workoutId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let histories = try context.fetch(fetchRequest)
            return histories.first
        } catch {
            AppLogger.coreData.error("Failed to fetch latest workout history: \(error.localizedDescription)")
            return nil
        }
    }
    
    func fetchAllWorkoutHistory(for date: Date) -> [WorkoutHistory]? {
        guard let context = self.context else { return nil }
        // Calculate the start and end of the month for the provided date
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: date))),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) else {
            AppLogger.coreData.error("Failed to compute month bounds for date: \(date)")
            return nil
        }

        let fetchRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        // Create a predicate to filter workouts within the start and end of the month
        fetchRequest.predicate = NSPredicate(format: "(workoutDate >= %@) AND (workoutDate <= %@)", argumentArray: [startOfMonth, endOfMonth])
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: true)]

        do {
            let histories = try context.fetch(fetchRequest)
            return histories
        } catch {
            AppLogger.coreData.error("Failed to fetch workout history: \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetches all workout history records (all time, no date filter)
    func fetchAllWorkoutHistoryAllTime() -> [WorkoutHistory]? {
        guard let context = self.context else { return nil }

        let fetchRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: false)]

        do {
            let histories = try context.fetch(fetchRequest)
            AppLogger.coreData.info("Fetched \(histories.count) workout histories (all time)")
            return histories
        } catch {
            AppLogger.coreData.error("Failed to fetch all workout history: \(error.localizedDescription)")
            return nil
        }
    }

    func fetchEarliestHistoryYear() -> Int? {
        guard let context = self.context else { return nil }
        let fetchRequest: NSFetchRequest<WorkoutHistory> = WorkoutHistory.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "workoutDate", ascending: true)]
        fetchRequest.fetchLimit = 1
        do {
            let result = try context.fetch(fetchRequest)
            guard let date = result.first?.workoutDate else { return nil }
            return Calendar.current.component(.year, from: date)
        } catch {
            AppLogger.coreData.error("Failed to fetch earliest history year: \(error.localizedDescription)")
            return nil
        }
    }

    func setSessionStatus(workoutId: UUID, isActive: Bool) {
        guard let context = self.context else { return }

        let workoutRequest = NSFetchRequest<Workouts>(entityName: "Workouts")
        workoutRequest.predicate = NSPredicate(format: "id == %@", workoutId as CVarArg)

        do {
            if let workout = try context.fetch(workoutRequest).first {
                context.refresh(workout, mergeChanges: true)
                if isActive {
                    let newSession = WorkoutSession(context: context)
                    newSession.id = UUID()
                    newSession.workoutsR = workout
                    newSession.startTime = Date()
                    newSession.isActive = true
                    newSession.deviceIdentifier = UIDevice.current.identifierForVendor?.uuidString
                    workout.sessions = newSession
                    NotificationManager.scheduleActiveWorkoutReminder()
                } else {
                    if let existingSession = workout.sessions, existingSession.isActive {
                        existingSession.isActive = false
                        existingSession.endTime = Date()
                    }
                    NotificationManager.cancelActiveWorkoutReminder()
                }

                try context.save()
            }
        } catch {
            AppLogger.coreData.error("Error setting session status: \(error.localizedDescription)")
        }
    }

    func saveWorkoutOrder(workouts: [WorkoutInfo]) {
        guard let backgroundContext = createBackgroundContext() else {
            errorHandler?.handle(.contextNotAvailable)
            return
        }

        backgroundContext.perform { [weak self] in
            do {
                // Update orderIndex for each workout based on array position
                for (index, workoutInfo) in workouts.enumerated() {
                    let fetchRequest: NSFetchRequest<Workouts> = Workouts.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", workoutInfo.id as CVarArg)

                    if let workout = try backgroundContext.fetch(fetchRequest).first {
                        workout.orderIndex = Int32(index)
                    }
                }

                // Save background context
                try backgroundContext.save()

                // Save parent context on main thread
                DispatchQueue.main.async {
                    guard let mainContext = self?.context else { return }
                    do {
                        if mainContext.hasChanges {
                            try mainContext.save()
                        }
                        AppLogger.workout.info("Workout order saved successfully")
                    } catch {
                        AppLogger.coreData.error("Error saving main context after reordering: \(error.localizedDescription)")
                        self?.errorHandler?.handle(.saveFailed(error))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    AppLogger.coreData.error("Error saving workout order: \(error.localizedDescription)")
                    self?.errorHandler?.handle(.saveFailed(error))
                }
            }
        }
    }
}
