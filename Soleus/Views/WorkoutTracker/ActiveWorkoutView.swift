import SwiftUI
import Combine


struct ActiveWorkoutView: View {
    var workoutId: UUID

    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel

    @StateObject private var focusManager = FocusManager()
    @StateObject private var viewModel: ActiveWorkoutViewModel
    @StateObject private var restTimer = RestTimerManager()

    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = true
    @AppStorage("defaultRestDuration") private var defaultRestDuration: Int = 90
    @AppStorage("hasSeenSetToggleHint") private var hasSeenSetToggleHint: Bool = false
    @AppStorage("hasSeenRestTimerHint") private var hasSeenRestTimerHint: Bool = false

    // UI State only
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var showUpdateDialog = false
    @State private var showingStartConfirmation = false
    @State private var showEndWorkoutOption = false
    @State private var showCancelWorkoutOption = false
    @State private var activeAlert: ActiveWorkoutAlert = .updateValues
    @State private var endWorkoutConfirmationShown = false
    @State private var showTimer: Bool = false
    @State private var showAddExerciseDialog = false
    @State private var editMode: EditMode = .inactive
    @State private var showChangesPreview = false
    @State private var editingNotesIndex: Int? = nil
    @State private var editingNotesText: String = ""
    @FocusState private var isNotesFocused: Bool
    @State private var renamingExerciseIndex: Int? = nil
    @State private var renamingText: String = ""
    @FocusState private var isRenameFocused: Bool
    @State private var selectedExerciseIndexForDelete: Int?
    @State private var expandedExercises: Set<Int> = []

    init(workoutId: UUID) {
        self.workoutId = workoutId
        _viewModel = StateObject(wrappedValue: ActiveWorkoutViewModel(workoutId: workoutId))
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading workout...")
                    .font(.title)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            }
            else{
                VStack(spacing: 0) {
                    if showTimer && !focusManager.isAnyTextFieldFocused {
                        TimerHeaderView(showTimer: $showTimer)
                            .frame(height: 80)
                            .background(Color.black.opacity(0.8))
                            .zIndex(1)
                    }

                    // Rest timer at top — hidden while typing so it doesn't push
                    // the focused row up under the keyboard (timer keeps running)
                    if viewModel.workoutStarted && !focusManager.isAnyTextFieldFocused {
                        RestTimerView(restTimer: restTimer)
                            .padding(.top, 8)
                            .zIndex(1)
                    }

                    if restTimer.isResting && !hasSeenRestTimerHint && !focusManager.isAnyTextFieldFocused {
                        firstTimeHint(
                            icon: "timer",
                            title: "Rest timer started",
                            subtitle: "Tap Skip to end early, or ±30s to adjust"
                        ) {
                            hasSeenRestTimerHint = true
                        }
                    }

                    if editMode == .active {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Swipe left on a set to delete it")
                                Text("Tap ··· to rename, reorder, or delete an exercise")
                                Text("+ adds a new exercise")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if viewModel.workoutStarted && !hasSeenSetToggleHint {
                        firstTimeHint(
                            icon: "checkmark.circle.fill",
                            title: "Tap the slider to mark a set complete",
                            subtitle: "Sets auto-complete once required fields are filled"
                        ) {
                            hasSeenSetToggleHint = true
                        }
                    }

                    ScrollViewReader { proxy in
                        Form {
                            displayExerciseDetailsAndSets
                        }
                        .scrollContentBackground(.hidden)
                        .scrollDismissesKeyboard(.immediately)
                        // Single keyboard toolbar for all set fields — per-row
                        // ToolbarItems inside a Form don't render reliably
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                if focusManager.isAnyTextFieldFocused {
                                    Spacer()
                                    Button(action: dismissKeyboard) {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                    }
                                    .accessibilityLabel("Done")
                                    .accessibilityIdentifier(AccessibilityID.keyboardDoneButton)
                                }
                            }
                        }
                        .onChange(of: editingNotesIndex) {
                            guard let index = editingNotesIndex else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo("notesAnchor_\(index)", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .onTapGesture {
                        if focusManager.isAnyTextFieldFocused {
                            dismissKeyboard()
                        }
                    }

                    Spacer()

                    if !isNotesFocused {
                        startWorkoutButton
                            .padding(.top)
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color(.systemGroupedBackground))
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarItems(
            leading: Button("Back") {
                appViewModel.resetToWorkoutMainView()
            },
            trailing: viewModel.workoutStarted ? HStack(spacing: 20) {
                if editMode == .active {
                    Button(action: {
                        showAddExerciseDialog = true
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.primary)
                    }
                    .accessibilityIdentifier(AccessibilityID.activeAddExerciseButton)
                }
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }) {
                    Image(systemName: editMode == .active ? "checkmark.circle.fill" : "pencil.circle")
                        .foregroundColor(editMode == .active ? .green : .primary)
                }
                .accessibilityIdentifier(AccessibilityID.activeEditModeButton)
                Menu {
                    Button(action: {
                        activeAlert = .cancelWorkout
                        showAlert = true
                    }) {
                        Label("Cancel Workout", systemImage: "xmark.circle")
                    }
                    Button(action: {
                        showTimer.toggle()
                    }) {
                        Label("Timer", systemImage: "timer")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            } : nil
        )
            .alert(isPresented: $showAlert) {
                switch(activeAlert) {
                case .cancelWorkout:
                    return Alert(
                        title: Text("Cancel Workout"),
                        message: Text("Are you sure you want to cancel the workout? This will discard all progress."),
                        primaryButton: .destructive(Text("Cancel Workout"), action: {
                            viewModel.cancelWorkout()
                            showEndWorkoutOption = false
                        }),
                        secondaryButton: .cancel(Text("Keep Going"), action: {
                            showEndWorkoutOption = false
                        })
                    )

                case .updateValues:
                    return Alert(
                        title: Text("Update Workout"),
                        message: Text("You've made changes from your original workout, would you like to update it?"),
                        primaryButton: .default(Text("Update Values"), action: {
                            viewModel.completeWorkout(shouldUpdateTemplate: true)
                        }),
                        secondaryButton: .cancel(Text("Keep Original Values"), action: {
                            viewModel.completeWorkout(shouldUpdateTemplate: false)
                        }))

                case .deleteExercise:
                    return Alert(
                        title: Text("Delete Exercise"),
                        message: Text("This will permanently remove this exercise from your workout plan. Continue?"),
                        primaryButton: .destructive(Text("Delete"), action: {
                            if let index = selectedExerciseIndexForDelete {
                                deleteExercise(at: index)
                                selectedExerciseIndexForDelete = nil
                            }
                        }),
                        secondaryButton: .cancel()
                    )
                }

            }
            .id(workoutId)
            .onAppear {
                // Setup ViewModel with dependencies
                viewModel.setup(workoutController: workoutController, appViewModel: appViewModel)
                viewModel.loadWorkout()

                // Expand all exercises by default
                expandedExercises = Set(workoutController.workoutDetails.indices)
            }
            .onChange(of: workoutController.workoutDetails.count) { oldCount, newCount in
                // When exercises are added, expand them automatically
                if newCount > oldCount {
                    expandedExercises = Set(workoutController.workoutDetails.indices)

                    // If workout is active, save new exercises directly to template
                    if viewModel.workoutStarted {
                        saveNewExercisesToTemplate()
                    }
                }
            }
            .onDisappear {
                viewModel.cleanup()
                // Stop rest timer when leaving the view
                restTimer.skipRest()
            }
            // Covers every dismissal path (checkmark, scroll, tap) so the
            // focus flag can't stay stuck and keep the timers hidden
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                focusManager.isAnyTextFieldFocused = false
                focusManager.currentlyFocusedField = nil
            }
            .sheet(isPresented: $showAddExerciseDialog) {
                AddExerciseDialog(
                    workoutDetails: $workoutController.workoutDetails,
                    showingDialog: $showAddExerciseDialog,
                    showPermanentNote: true
                )
                .presentationDetents([.height(450)])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea(.keyboard)
            }
            .sheet(isPresented: $showChangesPreview) {
                WorkoutChangesPreviewView(
                    originalDetails: workoutController.originalWorkoutDetails,
                    currentDetails: workoutController.workoutDetails,
                    onUpdate: {
                        showChangesPreview = false
                        viewModel.completeWorkout(shouldUpdateTemplate: true)
                    },
                    onKeepOriginal: {
                        showChangesPreview = false
                        viewModel.completeWorkout(shouldUpdateTemplate: false)
                    }
                )
            }
        }

    private var displayExerciseDetailsAndSets: some View {
        ForEach(Array(workoutController.workoutDetails.enumerated()), id: \.element.exerciseId) { index, detail in
            Section(header: VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Chevron indicator (hidden while renaming)
                    if renamingExerciseIndex != index {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(expandedExercises.contains(index) ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: expandedExercises.contains(index))
                            .accessibilityHidden(true)
                    }

                    // Exercise name or inline rename field
                    if renamingExerciseIndex == index {
                        TextField("Exercise Name", text: $renamingText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .focused($isRenameFocused)
                            .onSubmit { commitRename(for: index) }
                            .onChange(of: renamingText) {
                                if renamingText.count > 30 {
                                    renamingText = String(renamingText.prefix(30))
                                }
                            }
                            .onChange(of: isRenameFocused) {
                                if !isRenameFocused { commitRename(for: index) }
                            }
                            .toolbar {
                                ToolbarItem(placement: .keyboard) {
                                    if isRenameFocused {
                                        Button("Done") { commitRename(for: index) }
                                    }
                                }
                            }
                    } else {
                        Text(workoutController.workoutDetails[index].exerciseName)
                            .font(.title2)
                            .foregroundColor(Color.myBlack)
                            .accessibilityAddTraits(.isHeader)
                    }

                    Spacer()

                    // Edit mode: notes icon + ellipsis menu
                    if editMode == .active {
                        let hasNotes = workoutController.workoutDetails[index].notes != nil && !workoutController.workoutDetails[index].notes!.isEmpty
                        HStack(spacing: 16) {
                            Button(action: {
                                guard viewModel.workoutStarted else { return }
                                editingNotesText = workoutController.workoutDetails[index].notes ?? ""
                                editingNotesIndex = index
                                isNotesFocused = true
                            }) {
                                Image(systemName: hasNotes ? "note.text.badge.plus" : "note.text")
                                    .font(.body)
                                    .foregroundColor(hasNotes ? .orange : .gray)
                            }
                            .disabled(!viewModel.workoutStarted)
                            .accessibilityIdentifier("note_button_\(index)")

                            Menu {
                                Button(action: {
                                    guard viewModel.workoutStarted else { return }
                                    renamingText = workoutController.workoutDetails[index].exerciseName
                                    renamingExerciseIndex = index
                                    isRenameFocused = true
                                }) {
                                    Label("Rename Exercise", systemImage: "pencil")
                                }
                                .disabled(!viewModel.workoutStarted)

                                if index > 0 {
                                    Button(action: { moveExercise(from: index, direction: .up) }) {
                                        Label("Move Up", systemImage: "arrow.up")
                                    }
                                    .disabled(focusManager.isAnyTextFieldFocused)
                                }

                                if index < workoutController.workoutDetails.count - 1 {
                                    Button(action: { moveExercise(from: index, direction: .down) }) {
                                        Label("Move Down", systemImage: "arrow.down")
                                    }
                                    .disabled(focusManager.isAnyTextFieldFocused)
                                }

                                Menu {
                                    Button(action: { workoutController.workoutDetails[index].restDuration = 0 }) {
                                        if workoutController.workoutDetails[index].restDuration == 0 {
                                            Label("Default (\(RestDuration.format(defaultRestDuration)))", systemImage: "checkmark")
                                        } else {
                                            Text("Default (\(RestDuration.format(defaultRestDuration)))")
                                        }
                                    }
                                    Divider()
                                    ForEach(RestDuration.options, id: \.self) { option in
                                        Button(action: { workoutController.workoutDetails[index].restDuration = Int32(option) }) {
                                            if workoutController.workoutDetails[index].restDuration == Int32(option) {
                                                Label(RestDuration.format(option), systemImage: "checkmark")
                                            } else {
                                                Text(RestDuration.format(option))
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Rest Timer", systemImage: "timer")
                                }

                                Divider()

                                Button(role: .destructive, action: {
                                    selectedExerciseIndexForDelete = index
                                    activeAlert = .deleteExercise
                                    showAlert = true
                                }) {
                                    Label("Delete Exercise", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .accessibilityIdentifier("exercise_menu_\(index)")
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard renamingExerciseIndex != index else { return }
                    withAnimation {
                        if expandedExercises.contains(index) {
                            expandedExercises.remove(index)
                        } else {
                            expandedExercises.insert(index)
                        }
                    }
                }
                .accessibilityLabel("\(workoutController.workoutDetails[index].exerciseName), \(expandedExercises.contains(index) ? "expanded" : "collapsed")")
                .accessibilityHint("Double tap to \(expandedExercises.contains(index) ? "collapse" : "expand") exercise details")
                .accessibilityAddTraits(.isButton)

                // Notes inline edit / display
                if editingNotesIndex == index {
                    TextField("Add a note…", text: $editingNotesText, axis: .vertical)
                        .font(.subheadline)
                        .focused($isNotesFocused)
                        .padding(10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 4)
                        .id("notes_\(index)")
                        .accessibilityIdentifier("notes_field_\(index)")
                        .onChange(of: editingNotesText) {
                            if editingNotesText.hasSuffix("\n") &&
                               editingNotesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                commitActiveNotes(for: index)
                            }
                        }
                        .onChange(of: isNotesFocused) {
                            if !isNotesFocused { commitActiveNotes(for: index) }
                        }
                        .toolbar {
                            ToolbarItem(placement: .keyboard) {
                                if isNotesFocused {
                                    Button("Done") { commitActiveNotes(for: index) }
                                }
                            }
                        }
                    Color.clear.frame(height: 24).id("notesAnchor_\(index)")
                } else if let notes = workoutController.workoutDetails[index].notes, !notes.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
            }) {
                if expandedExercises.contains(index) {
                    if !workoutController.workoutDetails[index].sets.isEmpty {
                        SetHeaders(exerciseQuantifier: workoutController.workoutDetails[index].exerciseQuantifier, exerciseMeasurement: workoutController.workoutDetails[index].exerciseMeasurement, active: true)
                    }

                    ForEach(workoutController.workoutDetails[index].sets.indices, id: \.self) { setIndex in
                        ExerciseRowActive(
                            setInput: $workoutController.workoutDetails[index].sets[setIndex],
                            setIndex: setIndex + 1,
                            workoutDetails: workoutController.workoutDetails[index],
                            workoutId: workoutId,
                            workoutStarted: viewModel.workoutStarted,
                            workoutCancelled: viewModel.workoutCancelled,
                            exerciseQuantifier: workoutController.workoutDetails[index].exerciseQuantifier,
                            exerciseMeasurement: workoutController.workoutDetails[index].exerciseMeasurement
                        )
                        .environmentObject(focusManager)
                        .environmentObject(workoutController)
                        .environmentObject(restTimer)
                        .listRowInsets(EdgeInsets())
                    }
                    .onDelete(perform: editMode == .active ? { offsets in
                        workoutController.workoutDetails[index].sets.remove(atOffsets: offsets)
                    } : nil)

                    if viewModel.workoutStarted && editMode == .active {
                        Button("Add Set") {
                            addSet(to: index)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .accessibilityIdentifier("add_set_button_\(index)")
                    }
                }
            }
            .id("exercise_\(index)")
        }
    }

    private func dismissKeyboard() {
        focusManager.isAnyTextFieldFocused = false
        focusManager.currentlyFocusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func commitRename(for index: Int) {
        let trimmed = renamingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            workoutController.renameExercise(at: index, to: trimmed)
        }
        renamingExerciseIndex = nil
        isRenameFocused = false
    }

    private func commitActiveNotes(for index: Int) {
        let trimmed = editingNotesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let newNotes: String? = trimmed.isEmpty ? nil : trimmed
        workoutController.workoutDetails[index].notes = newNotes
        if let exerciseId = workoutController.workoutDetails[index].exerciseId {
            workoutController.workoutManager.updateExerciseNotesDuringActiveWorkout(
                workoutId: workoutId,
                exerciseId: exerciseId,
                notes: newNotes
            )
        }
        editingNotesIndex = nil
        isNotesFocused = false
    }

    private func addSet(to exerciseIndex: Int) {
        let detail = workoutController.workoutDetails[exerciseIndex]
        let maxSetIndex = detail.sets.max(by: { $0.setIndex < $1.setIndex })?.setIndex ?? 0
        let newSetIndex = maxSetIndex + 1

        // Pre-populate with the last set's values
        let newSet = detail.sets.last.map {
            SetInput(
                id: UUID(),
                reps: $0.reps,
                weight: $0.weight,
                time: $0.time,
                distance: $0.distance,
                isCompleted: false,
                setIndex: newSetIndex,
                exerciseQuantifier: detail.exerciseQuantifier,
                exerciseMeasurement: detail.exerciseMeasurement
            )
        } ?? SetInput(
            id: UUID(),
            reps: 0,
            weight: 0,
            time: 0,
            distance: 0,
            isCompleted: false,
            setIndex: newSetIndex,
            exerciseQuantifier: detail.exerciseQuantifier,
            exerciseMeasurement: detail.exerciseMeasurement
        )

        workoutController.workoutDetails[exerciseIndex].sets.append(newSet)
    }

    private enum MoveDirection {
        case up, down
    }

    private func moveExercise(from index: Int, direction: MoveDirection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let targetIndex: Int
            switch direction {
            case .up:
                targetIndex = index - 1
            case .down:
                targetIndex = index + 1
            }

            // Move the exercise in the array
            workoutController.workoutDetails.move(
                fromOffsets: IndexSet(integer: index),
                toOffset: targetIndex > index ? targetIndex + 1 : targetIndex
            )

            // CRITICAL: Update orderIndex for all exercises after reordering
            for (newIndex, _) in workoutController.workoutDetails.enumerated() {
                workoutController.workoutDetails[newIndex].orderIndex = Int32(newIndex)
            }

            // Save the updated order to CoreData
            guard let workout = workoutController.workoutManager.fetchWorkoutById(for: workoutId) else {
                AppLogger.activeWorkout.error("Failed to fetch workout for reordering")
                return
            }

            // Update temporary workout details order
            if let tempDetails = workout.detailsTemp as? Set<TemporaryWorkoutDetail> {
                for detail in workoutController.workoutDetails {
                    if let exerciseId = detail.exerciseId,
                       let tempDetail = tempDetails.first(where: { $0.exerciseId == exerciseId }) {
                        tempDetail.orderIndex = Int32(Int16(detail.orderIndex))
                    }
                }
            }

            // Save the context
            if let context = workoutController.workoutManager.context {
                do {
                    try context.save()
                    HapticManager.shared.exerciseReordered()
                    AppLogger.activeWorkout.info("Successfully reordered exercises and saved to CoreData")
                } catch {
                    AppLogger.activeWorkout.error("Failed to save reordered exercises: \(error.localizedDescription)")
                }
            }
        }
    }

    private func deleteExercise(at index: Int) {
        guard index < workoutController.workoutDetails.count else { return }

        let detail = workoutController.workoutDetails[index]

        // Remove from in-memory array
        workoutController.workoutDetails.remove(at: index)

        // Remove from workout template and temporary data if it has an exerciseId
        if let exerciseId = detail.exerciseId {
            guard let context = workoutController.workoutManager.context else { return }
            guard let workout = workoutController.workoutManager.fetchWorkoutById(for: workoutId) else { return }

            // Delete from CoreData template (WorkoutDetail)
            if let details = workout.details as? Set<WorkoutDetail>,
               let detailToDelete = details.first(where: { $0.exerciseId == exerciseId }) {
                context.delete(detailToDelete)
            }

            // Delete from temporary workout details (TemporaryWorkoutDetail)
            if let tempDetails = workout.detailsTemp as? Set<TemporaryWorkoutDetail>,
               let tempDetailToDelete = tempDetails.first(where: { $0.exerciseId == exerciseId }) {
                context.delete(tempDetailToDelete)
            }

            do {
                try context.save()
                HapticManager.shared.exerciseDeleted()
                AppLogger.activeWorkout.info("Deleted exercise '\(detail.exerciseName)' from workout template and temporary data")
            } catch {
                AppLogger.activeWorkout.error("Failed to delete exercise: \(error)")
            }
        }

        // Update expanded exercises set
        expandedExercises = Set(workoutController.workoutDetails.indices)
    }

    private func buttonAction() {
        if viewModel.workoutStarted {
            if showEndWorkoutOption {
                endWorkoutConfirmationShown = true
            } else {
                focusManager.clearFocus()
                showEndWorkoutOption = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.showEndWorkoutOption = false
                }
            }
        } else {
            showingStartConfirmation = true
        }
    }

    private func endWorkout() {
        if viewModel.hasWorkoutChanged() {
            showChangesPreview = true
        } else {
            viewModel.completeWorkout(shouldUpdateTemplate: false)
        }
    }

    private func saveNewExercisesToTemplate() {
        guard let workout = workoutController.workoutManager.fetchWorkoutById(for: workoutId) else {
            AppLogger.activeWorkout.error("Failed to fetch workout")
            return
        }

        var exerciseWasAdded = false

        // Find exercises without exerciseId and save them to the template
        for index in workoutController.workoutDetails.indices {
            if workoutController.workoutDetails[index].exerciseId == nil {
                let detail = workoutController.workoutDetails[index]

                // Save directly to workout template
                workoutController.workoutManager.addWorkoutDetail(
                    id: detail.id ?? UUID(),
                    workoutTitle: workout.name ?? "",
                    exerciseName: detail.exerciseName,
                    color: workout.color ?? "",
                    orderIndex: detail.orderIndex,
                    sets: detail.sets,
                    exerciseMeasurement: detail.exerciseMeasurement,
                    exerciseQuantifier: detail.exerciseQuantifier,
                    notes: detail.notes,
                    restDuration: detail.restDuration
                )

                // Fetch the workout again to get the newly created exerciseId
                if let updatedWorkout = workoutController.workoutManager.fetchWorkoutById(for: workoutId),
                   let details = updatedWorkout.details as? Set<WorkoutDetail>,
                   let newDetail = details.first(where: { $0.exerciseName == detail.exerciseName && $0.orderIndex == detail.orderIndex }),
                   let newExerciseId = newDetail.exerciseId {

                    // Update the exerciseId in memory so saves work
                    workoutController.workoutDetails[index].exerciseId = newExerciseId
                    AppLogger.activeWorkout.info("Added exercise '\(detail.exerciseName)' to workout template with exerciseId: \(newExerciseId)")
                    exerciseWasAdded = true
                }
            }
        }

        if exerciseWasAdded {
            AppLogger.activeWorkout.info("Exercise(s) saved to workout template")
        }
    }

    private var startWorkoutButton: some View {
        Button(action: buttonAction) {
            HStack(spacing: 8) {
                if viewModel.workoutStarted {
                    if showEndWorkoutOption {
                        Image(systemName: "stop.circle.fill")
                            .font(.title3)
                    } else {
                        Image(systemName: "timer")
                            .font(.title3)
                    }
                } else {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                }
                Text(workoutButtonText)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.staticWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        showEndWorkoutOption ? Color.red : Color.myBlue,
                        showEndWorkoutOption ? Color.red.opacity(0.8) : Color.myBlue.opacity(0.8)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: (showEndWorkoutOption ? Color.red : Color.myBlue).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .accessibilityLabel(workoutButtonAccessibilityLabel)
        .accessibilityHint(workoutButtonAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(AccessibilityID.startWorkoutButton)
        .padding(.horizontal, 20)
        .disabled(!viewModel.workoutStarted && showEndWorkoutOption || viewModel.isAnyOtherSessionActive())
        .confirmationDialog("Are you sure you want to end this workout?", isPresented: $endWorkoutConfirmationShown, titleVisibility: .visible) {
            Button("End Workout", action: endWorkout)
            Button("Cancel", role: .cancel) {
                self.showEndWorkoutOption = false
            }
        }
        .confirmationDialog("Are you sure you want to start this workout?", isPresented: $showingStartConfirmation, titleVisibility: .visible) {
            Button("Start", action: { viewModel.startWorkout() })
            Button("Cancel", role: .cancel) {}
        }
    }

    private var workoutButtonAccessibilityLabel: String {
        if viewModel.workoutStarted {
            return showEndWorkoutOption ? "End workout" : "Workout timer: \(viewModel.elapsedTimeFormatted)"
        } else {
            return "Start workout"
        }
    }

    private var workoutButtonAccessibilityHint: String {
        if viewModel.workoutStarted {
            return showEndWorkoutOption ? "Double tap to confirm ending workout" : "Tap to end workout"
        } else {
            return "Double tap to begin tracking your workout"
        }
    }

    private var workoutButtonText: String {
        if viewModel.workoutStarted {
            return showEndWorkoutOption ? "End Workout" : viewModel.elapsedTimeFormatted
        } else {
            return "Start Workout"
        }
    }

    @ViewBuilder
    private func firstTimeHint(
        icon: String,
        title: String,
        subtitle: String,
        onDismiss: @escaping () -> Void
    ) -> some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.25)) { onDismiss() }
        }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.myBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

enum ActiveWorkoutAlert {
    case updateValues, cancelWorkout, deleteExercise
}

// MARK: - Workout Changes Preview
struct WorkoutChangesPreviewView: View {
    let originalDetails: [WorkoutDetailInput]
    let currentDetails: [WorkoutDetailInput]
    let onUpdate: () -> Void
    let onKeepOriginal: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout Changes")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Review the changes you made during this workout")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // Changes summary
                    ForEach(currentDetails.indices, id: \.self) { index in
                        if let originalIndex = originalDetails.firstIndex(where: { $0.exerciseId == currentDetails[index].exerciseId }) {
                            let original = originalDetails[originalIndex]
                            let current = currentDetails[index]

                            if hasChanges(original: original, current: current) {
                                ExerciseChangesCard(
                                    exerciseName: current.exerciseName,
                                    original: original,
                                    current: current
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    // New exercises added
                    ForEach(currentDetails, id: \.exerciseId) { detail in
                        if !originalDetails.contains(where: { $0.exerciseId == detail.exerciseId }) {
                            NewExerciseCard(exerciseName: detail.exerciseName, sets: detail.sets.count)
                                .padding(.horizontal)
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button(action: {
                        onUpdate()
                    }) {
                        Text("Update Workout Template")
                            .font(.headline)
                            .foregroundColor(.staticWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.myBlue)
                            .cornerRadius(12)
                    }

                    Button(action: {
                        onKeepOriginal()
                    }) {
                        Text("Keep Original Template")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    private func hasChanges(original: WorkoutDetailInput, current: WorkoutDetailInput) -> Bool {
        if original.notes != current.notes || original.sets.count != current.sets.count {
            return true
        }

        for (index, originalSet) in original.sets.enumerated() {
            if index < current.sets.count {
                let currentSet = current.sets[index]
                if originalSet.reps != currentSet.reps ||
                   originalSet.weight != currentSet.weight ||
                   originalSet.time != currentSet.time ||
                   originalSet.distance != currentSet.distance {
                    return true
                }
            }
        }

        return false
    }
}

struct ExerciseChangesCard: View {
    let exerciseName: String
    let original: WorkoutDetailInput
    let current: WorkoutDetailInput

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.orange)
                Text(exerciseName)
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                if original.notes != current.notes {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let note = current.notes, !note.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "note.text")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            Text("(removed)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }

                if original.sets.count != current.sets.count {
                    HStack {
                        Text("Sets:")
                            .fontWeight(.medium)
                        Text("\(original.sets.count)")
                            .foregroundColor(.secondary)
                            .strikethrough()
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(current.sets.count)")
                            .foregroundColor(.orange)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }

                ForEach(current.sets.indices, id: \.self) { index in
                    if index < original.sets.count {
                        let originalSet = original.sets[index]
                        let currentSet = current.sets[index]

                        if hasSetChanged(original: originalSet, current: currentSet) {
                            SetChangeRow(
                                setNumber: index + 1,
                                original: originalSet,
                                current: currentSet,
                                quantifier: current.exerciseQuantifier,
                                measurement: current.exerciseMeasurement
                            )
                        }
                    } else {
                        NewSetRow(
                            setNumber: index + 1,
                            set: current.sets[index],
                            quantifier: current.exerciseQuantifier,
                            measurement: current.exerciseMeasurement
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func hasSetChanged(original: SetInput, current: SetInput) -> Bool {
        return original.reps != current.reps ||
               original.weight != current.weight ||
               original.time != current.time ||
               original.distance != current.distance
    }
}

struct SetChangeRow: View {
    let setNumber: Int
    let original: SetInput
    let current: SetInput
    let quantifier: String
    let measurement: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set \(setNumber)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                if quantifier == "Reps" && original.reps != current.reps {
                    ValueChangeView(
                        label: "Reps",
                        original: "\(original.reps)",
                        current: "\(current.reps)"
                    )
                }

                if quantifier == "Distance" && original.distance != current.distance {
                    ValueChangeView(
                        label: "Distance",
                        original: String(format: "%.1f", original.distance),
                        current: String(format: "%.1f", current.distance)
                    )
                }

                if measurement == "Weight" && original.weight != current.weight {
                    ValueChangeView(
                        label: "Weight",
                        original: String(format: "%.1f", original.weight),
                        current: String(format: "%.1f", current.weight)
                    )
                }

                if measurement == "Time" && original.time != current.time {
                    ValueChangeView(
                        label: "Time",
                        original: formatTime(Int(original.time)),
                        current: formatTime(Int(current.time))
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

struct ValueChangeView: View {
    let label: String
    let original: String
    let current: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            HStack(spacing: 4) {
                Text(original)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .strikethrough()
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                Text(current)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct NewSetRow: View {
    let setNumber: Int
    let set: SetInput
    let quantifier: String
    let measurement: String

    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text("Set \(setNumber) (New)")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.vertical, 2)
    }
}

struct NewExerciseCard: View {
    let exerciseName: String
    let sets: Int

    var body: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(exerciseName)
                    .font(.headline)
                Text("New exercise with \(sets) set(s)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
