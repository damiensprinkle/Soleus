import SwiftUI

struct AddWorkoutView: View {
    var workoutId: UUID
    let navigationTitle: String
    var update: Bool
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel
    @StateObject private var focusManager = FocusManager()
    
    @State private var swipeResetToken: Int = 0
    @State private var workoutTitle: String = ""
    @State private var showingRenameDialog = false
    @State private var errorMessage: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var indexToDelete: Int? = nil
    @State private var activeAlert: ActiveAlert = .error
    @State private var workoutSaveError: WorkoutSaveError = .emptyTitle
    @State private var initialWorkoutDetails: [WorkoutDetailInput] = []

    private let colorManager = ColorManager()
    @State private var showingExercisePicker = false
    @State private var showingCustomExerciseForm = false
    @State private var showingTemplatePickerSheet = false
    @State private var pendingTemplate: WorkoutTemplate? = nil
    @State private var formID = UUID()
    @State private var hasLoaded = false
    @FocusState private var isTitleFocused: Bool
    @EnvironmentObject var appViewModel: AppViewModel
    
    private var hasUnsavedChanges: Bool {
        if update {
            return workoutController.workoutDetails != initialWorkoutDetails
                || workoutTitle != (workoutController.selectedWorkoutName ?? "")
        } else {
            return !workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !workoutController.workoutDetails.isEmpty
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            alertMessage = "You have unsaved changes. Are you sure you want to cancel?"
                            activeAlert = .cancelConfirmation
                            showAlert = true
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.addWorkoutCancelButton)

                    Spacer()

                    Text(navigationTitle)
                        .font(.headline)

                    Spacer()

                    Button("Save") {
                        if update, workoutController.activeWorkoutId == workoutId {
                            errorMessage = "You cannot edit a workout that is in progress."
                            activeAlert = .error
                            showAlert = true
                            return
                        }
                        let result = workoutController.saveWorkout(title: workoutTitle, update: update, workoutId: workoutId)
                        switch result {
                        case .success:
                            presentationMode.wrappedValue.dismiss()
                        case .failure(let error):
                            handleSaveError(error)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.addWorkoutSaveButton)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))

                Divider()

                addWorkoutForm
                    .id(formID)

            }
            .background(Color(.systemGroupedBackground))
            .background(
                SheetDismissProtector(isProtected: hasUnsavedChanges) {
                    alertMessage = "You have unsaved changes. Are you sure you want to discard them?"
                    activeAlert = .cancelConfirmation
                    showAlert = true
                }
            )
        }
        .alert(isPresented: $showAlert) {
                switch activeAlert {
                case .error:
                    return Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
                case .deleteConfirmation:
                    return Alert(
                        title: Text("Confirm Deletion"),
                        message: Text(alertMessage),
                        primaryButton: .destructive(Text("Delete")) {
                            if let index = indexToDelete {
                                workoutController.workoutDetails.remove(at: index)
                                indexToDelete = nil
                            }
                        },
                        secondaryButton: .cancel {
                            indexToDelete = nil
                        }
                    )
                case .cancelConfirmation:
                    return Alert(
                        title: Text("Warning"),
                        message: Text(alertMessage),
                        primaryButton: .default(Text("Yes")) {
                            presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel(Text("No")) {
                            showAlert = false
                        }
                    )
                case .templateOverwriteConfirmation:
                    return Alert(
                        title: Text("Replace Workout?"),
                        message: Text("This will overwrite your current title and exercises. This cannot be undone."),
                        primaryButton: .destructive(Text("Replace")) {
                            if let template = pendingTemplate {
                                applyTemplate(template)
                            }
                            pendingTemplate = nil
                        },
                        secondaryButton: .cancel {
                            pendingTemplate = nil
                        }
                    )
                }
            }
            .onTapGesture { hideKeyboard() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                focusManager.isAnyTextFieldFocused = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                focusManager.isAnyTextFieldFocused = false
                focusManager.currentlyFocusedField = nil
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                workoutController.workoutDetails = []
                formID = UUID()
                if update {
                    workoutController.loadWorkoutDetails(for: workoutId)
                    workoutTitle = workoutController.selectedWorkoutName ?? ""
                    initialWorkoutDetails = workoutController.workoutDetails
                }
            }
            .sheet(isPresented: $showingTemplatePickerSheet) {
                TemplatePickerView(isPresented: $showingTemplatePickerSheet) { template in
                    let hasExistingContent = !workoutController.workoutDetails.isEmpty || !workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if hasExistingContent {
                        showingTemplatePickerSheet = false
                        pendingTemplate = template
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            activeAlert = .templateOverwriteConfirmation
                            showAlert = true
                        }
                    } else {
                        applyTemplate(template)
                        showingTemplatePickerSheet = false
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingExercisePicker, onDismiss: {
                showingCustomExerciseForm = false
            }) {
                // One sheet hosts both stages: the library picker and the
                // custom-exercise form swap in place, resizing the detent.
                Group {
                    if showingCustomExerciseForm {
                        AddExerciseDialog(
                            workoutDetails: $workoutController.workoutDetails,
                            showingDialog: $showingExercisePicker,
                            onBack: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showingCustomExerciseForm = false
                                }
                            }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        ExercisePickerView(
                            isPresented: $showingExercisePicker,
                            onSelect: { template in
                                addExercise(from: template)
                            },
                            onCreateCustom: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showingCustomExerciseForm = true
                                }
                            }
                        )
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .presentationDetents(showingCustomExerciseForm ? [.height(420)] : [.large])
                .presentationDragIndicator(.visible)
                .ignoresSafeArea(.keyboard)
            }

    }
    
    private var bottomButtons: some View {
        VStack(spacing: 8) {
            Button(action: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingExercisePicker = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Add Exercise")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.staticWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.myBlue, Color.myBlue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.myBlue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .accessibilityIdentifier(AccessibilityID.addWorkoutAddExerciseButton)

            if !update {
                Button(action: { showingTemplatePickerSheet = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.plaintext")
                            .font(.title3)
                        Text("Start from Template")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.myBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.myBlue.opacity(0.1))
                    .cornerRadius(14)
                }
                .accessibilityIdentifier(AccessibilityID.templatePickerButton)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var addWorkoutForm: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 16) {
                    // Workout Title Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Workout Title")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(workoutTitle.count)/30")
                                .font(.caption)
                                .foregroundColor(workoutTitle.count >= 30 ? .red : .secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        TextField("Enter Workout Title", text: $workoutTitle)
                            .focused($isTitleFocused)
                            .submitLabel(.done)
                            .font(.body)
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .onChange(of: workoutTitle) {
                                if workoutTitle.count > 30 {
                                    workoutTitle = String(workoutTitle.prefix(30))
                                }
                            }
                            .accessibilityIdentifier(AccessibilityID.addWorkoutTitleField)
                    }
                    .padding(.bottom, 8)

                    // Exercise Cards
                    ForEach(Array(workoutController.workoutDetails.enumerated()), id: \.element.id) { index, detail in
                        ExerciseCard(
                            exerciseName: detail.exerciseName,
                            hasNotes: detail.notes != nil && !detail.notes!.isEmpty,
                            notes: detail.notes,
                            index: index,
                            workoutCount: workoutController.workoutDetails.count,
                            isKeyboardActive: focusManager.isAnyTextFieldFocused,
                            sets: Binding(
                                get: { index < workoutController.workoutDetails.count ? workoutController.workoutDetails[index].sets : detail.sets },
                                set: { if index < workoutController.workoutDetails.count { workoutController.workoutDetails[index].sets = $0 } }
                            ),
                            exerciseQuantifier: detail.exerciseQuantifier,
                            exerciseMeasurement: detail.exerciseMeasurement,
                            restDuration: detail.restDuration,
                            focusManager: focusManager,
                            moveUpAction: {
                                workoutController.moveExercise(from: index, to: index - 1)
                            },
                            moveDownAction: {
                                workoutController.moveExercise(from: index, to: index + 1)
                            },
                            deleteAction: {
                                indexToDelete = index
                                alertMessage = "Are you sure you want to delete this exercise?"
                                activeAlert = .deleteConfirmation
                                showAlert = true
                            },
                            onRename: { newName in
                                workoutController.renameExercise(at: index, to: newName)
                            },
                            onNotesChange: { newNotes in
                                workoutController.workoutDetails[index].notes = newNotes
                            },
                            onRestDurationChange: { newDuration in
                                workoutController.workoutDetails[index].restDuration = newDuration
                            },
                            addSetAction: {
                                workoutController.addSet(for: index)
                            },
                            swipeResetToken: swipeResetToken
                        )
                        .id("exercise_\(index)")
                        .padding(.horizontal, 20)
                        .accessibilityIdentifier("\(AccessibilityID.exerciseCard)_\(index)")
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .keyboardDismissToolbar()
            .onScrollGeometryChange(for: Int.self) { Int($0.contentOffset.y / 10) } action: { _, _ in
                swipeResetToken += 1
            }
            .safeAreaInset(edge: .bottom) {
                if !focusManager.isAnyTextFieldFocused {
                    bottomButtons
                }
            }
            .onChange(of: focusManager.focusedExerciseIndex) {
                guard let idx = focusManager.focusedExerciseIndex else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo("exercise_\(idx)", anchor: .center)
                    }
                }
            }
        }
    }
    
    
    // MARK: - Exercise Card
    struct ExerciseCard: View {
        let exerciseName: String
        let hasNotes: Bool
        let notes: String?
        let index: Int
        let workoutCount: Int
        let isKeyboardActive: Bool
        @Binding var sets: [SetInput]
        let exerciseQuantifier: String
        let exerciseMeasurement: String
        let restDuration: Int32
        let focusManager: FocusManager
        var moveUpAction: (() -> Void)?
        var moveDownAction: (() -> Void)?
        var deleteAction: (() -> Void)?
        var onRename: ((String) -> Void)?
        var onNotesChange: ((String?) -> Void)?
        var onRestDurationChange: ((Int32) -> Void)?
        var addSetAction: (() -> Void)?
        var swipeResetToken: Int = 0

        @State private var isRenaming = false
        @State private var editingName = ""
        @FocusState private var isRenameFocused: Bool
        @State private var isEditingNotes = false
        @State private var editingNotes = ""
        @FocusState private var isNotesFocused: Bool
        @AppStorage("defaultRestDuration") private var defaultRestDuration: Int = 60

        var body: some View {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    // Title and primary actions
                    HStack {
                        if isRenaming {
                            TextField("Exercise Name", text: $editingName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .focused($isRenameFocused)
                                .onSubmit { commitRename() }
                                .onChange(of: editingName) {
                                    if editingName.count > 30 {
                                        editingName = String(editingName.prefix(30))
                                    }
                                }
                                .onChange(of: isRenameFocused) {
                                    if !isRenameFocused { commitRename() }
                                }
                        } else {
                            Text(exerciseName)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        HStack(spacing: 16) {
                            // Notes icon
                            Button(action: {
                                editingNotes = notes ?? ""
                                isEditingNotes = true
                                isNotesFocused = true
                            }) {
                                Image(systemName: hasNotes ? "note.text.badge.plus" : "note.text")
                                    .font(.body)
                                    .foregroundColor(hasNotes ? .orange : .gray)
                            }

                            // More options menu
                            Menu {
                                Button(action: {
                                    editingName = exerciseName
                                    isRenaming = true
                                    isRenameFocused = true
                                }) {
                                    Label("Rename Exercise", systemImage: "pencil")
                                }

                                if index > 0 {
                                    Button(action: { moveUpAction?() }) {
                                        Label("Move Up", systemImage: "arrow.up")
                                    }
                                    .disabled(isKeyboardActive)
                                }

                                if index < workoutCount - 1 {
                                    Button(action: { moveDownAction?() }) {
                                        Label("Move Down", systemImage: "arrow.down")
                                    }
                                    .disabled(isKeyboardActive)
                                }

                                Divider()

                                Button(role: .destructive, action: { deleteAction?() }) {
                                    Label("Delete Exercise", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }

                    // Per-exercise rest timer override
                    HStack {
                        Menu {
                            Button(action: { onRestDurationChange?(0) }) {
                                if restDuration == 0 {
                                    Label("Default (\(RestDuration.format(defaultRestDuration)))", systemImage: "checkmark")
                                } else {
                                    Text("Default (\(RestDuration.format(defaultRestDuration)))")
                                }
                            }
                            Divider()
                            ForEach(RestDuration.options, id: \.self) { option in
                                Button(action: { onRestDurationChange?(Int32(option)) }) {
                                    if restDuration == Int32(option) {
                                        Label(RestDuration.format(option), systemImage: "checkmark")
                                    } else {
                                        Text(RestDuration.format(option))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                Text(restDuration > 0 ? "Rest: \(RestDuration.formatShort(Int(restDuration)))" : "Rest: Default")
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(restDuration > 0 ? .myBlue : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(restDuration > 0 ? Color.myBlue.opacity(0.12) : Color.gray.opacity(0.15))
                            )
                        }
                        Spacer()
                    }

                    // Notes display / inline edit
                    if isEditingNotes {
                        TextField("Add a note…", text: $editingNotes, axis: .vertical)
                            .font(.subheadline)
                            .focused($isNotesFocused)
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(10)
                            .onChange(of: editingNotes) {
                                if editingNotes.hasSuffix("\n") {
                                    if editingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        commitNotes()
                                    }
                                }
                            }
                            .onChange(of: isNotesFocused) {
                                if !isNotesFocused { commitNotes() }
                            }
                    } else if let notes = notes, !notes.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "quote.bubble.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding(16)

                Divider()
                    .padding(.horizontal, 16)

                // Sets section
                VStack(spacing: 8) {
                    if !sets.isEmpty {
                        SetHeaders(exerciseQuantifier: exerciseQuantifier, exerciseMeasurement: exerciseMeasurement, active: false)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    ForEach(Array(sets.enumerated()), id: \.element.id) { setIndex, set in
                        SwipeToDeleteRow(onDelete: {
                            sets.remove(at: setIndex)
                        }, resetToken: swipeResetToken) {
                            VStack(spacing: 0) {
                                ExerciseRow(
                                    setIndex: setIndex + 1,
                                    setInput: Binding(
                                        get: { setIndex < sets.count ? sets[setIndex] : set },
                                        set: { if setIndex < sets.count { sets[setIndex] = $0 } }
                                    ),
                                    exerciseIndex: index,
                                    exerciseQuantifier: exerciseQuantifier,
                                    exerciseMeasurement: exerciseMeasurement
                                )
                                .environmentObject(focusManager)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)

                                if setIndex < sets.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }

                    // Add Set Button
                    Button(action: { addSetAction?() }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                            Text("Add Set")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.myBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.myBlue.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }

        private func commitRename() {
            let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                onRename?(trimmed)
            }
            isRenaming = false
            isRenameFocused = false
        }

        private func commitNotes() {
            let trimmed = editingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            onNotesChange?(trimmed.isEmpty ? nil : trimmed)
            isEditingNotes = false
            isNotesFocused = false
        }
    }

    struct WorkoutSetListView: View {
        @Binding var sets: [SetInput]
        let exerciseQuantifier: String
        let exerciseMeasurement: String
        let addSetAction: () -> Void
        let focusManager: FocusManager
        
        
        var body: some View {
            if !sets.isEmpty {
                SetHeaders(exerciseQuantifier: exerciseQuantifier, exerciseMeasurement: exerciseMeasurement, active: false)
            }
            
            ForEach(sets.indices, id: \.self) { setIndex in
                ExerciseRow(
                    setIndex: setIndex + 1,
                    setInput: $sets[setIndex],
                    exerciseQuantifier: exerciseQuantifier,
                    exerciseMeasurement: exerciseMeasurement
                )
                .environmentObject(focusManager)
            }
            .onDelete { offsets in
                sets.remove(atOffsets: offsets)
            }
            
            Button("Add Set") {
                addSetAction()
            }
        }
    }
    
    private func deleteExercise(at offsets: IndexSet) {
        workoutController.workoutDetails.remove(atOffsets: offsets)
    }
    
    private func addExercise(from template: ExerciseTemplate) {
        let quantifier = template.defaultQuantifier ?? "Reps"
        let measurement = template.defaultMeasurement ?? "Weight"
        let newIndex = workoutController.workoutDetails.last?.orderIndex ?? 0
        workoutController.workoutDetails.append(WorkoutDetailInput(
            id: UUID(),
            exerciseName: template.name ?? "Exercise",
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
        ))
    }

    private func applyTemplate(_ template: WorkoutTemplate) {
        workoutTitle = template.name
        workoutController.workoutDetails = template.toWorkoutDetails()
        formID = UUID()
    }

    private func handleSaveError(_ error: WorkoutSaveError) {
        switch error {
        case .emptyTitle:
            errorMessage = "Please enter a workout title."
        case .noExerciseDetails:
            errorMessage = "Please add at least one exercise detail."
        case .titleExists:
            errorMessage = "Workout title already exists."
        }
        activeAlert = .error
        showAlert = true
    }
}

/// Wraps any row content with a trailing swipe-to-delete action.
/// Left swipe reveals a red Delete button. Resets when `resetToken` changes (e.g. on scroll).
private struct SwipeToDeleteRow<Content: View>: View {
    let onDelete: () -> Void
    let resetToken: Int
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    private let deleteWidth: CGFloat = 70

    var body: some View {
        ZStack(alignment: .trailing) {
            // Revealed delete button
            Button(action: {
                // Slide row fully off-screen, then collapse its height with animation
                withAnimation(.easeIn(duration: 0.2)) {
                    offset = -UIScreen.main.bounds.width
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onDelete()
                    }
                }
            }) {
                Image(systemName: "trash.fill")
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
                    .cornerRadius(8)
            }
            .padding(.trailing, 2)
            .opacity(offset < -10 ? 1 : 0)

            // Row content slides left to reveal the button
            content()
                .background(Color(.secondarySystemGroupedBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .onChanged { value in
                            let h = value.translation.width
                            let v = abs(value.translation.height)
                            // Vertical drag while open → close immediately so scroll takes over
                            if offset < 0 && v > abs(h) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { offset = 0 }
                                return
                            }
                            guard abs(h) > v else { return }
                            offset = h < 0 ? max(h, -deleteWidth) : min(0, offset + h)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                offset = offset < -(deleteWidth / 2) ? -deleteWidth : 0
                            }
                        }
                )
        }
        .clipped()
        .onChange(of: resetToken) {
            guard offset != 0 else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { offset = 0 }
        }
    }
}

/// Intercepts the sheet's interactive swipe-down dismiss and fires a callback
/// instead of allowing the dismiss when `isProtected` is true.
private struct SheetDismissProtector: UIViewControllerRepresentable {
    var isProtected: Bool
    var onAttemptedDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isProtected = isProtected
        context.coordinator.onAttemptedDismiss = onAttemptedDismiss
        // Walk up to the UIHostingController that owns the sheet presentation.
        // Only do this once — re-setting the delegate on every SwiftUI re-render
        // can interfere with UIKit's keyboard presentation and cause a sheet flash.
        guard !context.coordinator.delegateSet else { return }
        DispatchQueue.main.async {
            guard !context.coordinator.delegateSet else { return }
            var current: UIViewController? = uiViewController
            while let parent = current?.parent { current = parent }
            if current?.presentationController != nil {
                current?.presentationController?.delegate = context.coordinator
                context.coordinator.delegateSet = true
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isProtected: isProtected, onAttemptedDismiss: onAttemptedDismiss)
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isProtected: Bool
        var onAttemptedDismiss: () -> Void
        var delegateSet = false

        init(isProtected: Bool, onAttemptedDismiss: @escaping () -> Void) {
            self.isProtected = isProtected
            self.onAttemptedDismiss = onAttemptedDismiss
        }

        // Return .none to keep the current presentation style regardless of
        // size-class changes (e.g. keyboard appearing on iPhone). Without this,
        // UIKit may briefly switch presentation styles and cause a visible flash.
        func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
            .none
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isProtected
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttemptedDismiss()
        }
    }
}

enum ActiveAlert {
    case error, deleteConfirmation, cancelConfirmation, templateOverwriteConfirmation
}
