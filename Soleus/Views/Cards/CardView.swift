import SwiftUI

struct CardView: View {
    var workoutId: UUID
    var onDelete: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onEdit: (() -> Void)?
    var isEditMode: Bool = false
    var isDragging: Bool = false

    @EnvironmentObject var workoutController: WorkoutTrackerViewModel
    @EnvironmentObject var appViewModel: AppViewModel

    @State private var animate = false
    @State private var ripple1 = false
    @State private var ripple2 = false
    @State private var rotation = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var workout: Workouts?
    @State private var shareItems: [Any] = []
    @State private var shakeOffset: CGFloat = 0


    var body: some View {
        let backgroundColor = Color(workout?.color ?? "MyBlue")

        ZStack {
            // Base card
            VStack {
                existingWorkoutCardContent(workout: workout)
            }
            .padding()
            .background(
                ZStack {
                    // Main color background
                    backgroundColor

                    // Subtle gradient overlay for depth
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.1),
                            Color.clear,
                            Color.black.opacity(0.15)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .cornerRadius(18)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .shadow(color: backgroundColor.opacity(0.3), radius: 12, x: 0, y: 6)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18))
        .rotationEffect(.degrees(isEditMode && !isDragging ? shakeOffset : 0))
        .onAppear {
            let manager = workoutController.workoutManager
            workout = manager.fetchWorkoutById(for: workoutId)

            if isEditMode {
                startShakeAnimation()
            }
        }
        .onChange(of: workoutController.workouts) { _, newWorkouts in
            // Only refresh if this workout still exists in the array
            if newWorkouts.contains(where: { $0.id == workoutId }) {
                let manager = workoutController.workoutManager
                workout = manager.fetchWorkoutById(for: workoutId)
            }
        }
        .onChange(of: isEditMode) { _, newValue in
            if newValue {
                startShakeAnimation()
            }
        }
        .if(!isEditMode) { view in
            view.contextMenu { contextMenuContent() }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            if alertTitle.contains("Are you sure you want to delete this workout?") {
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
                Button("Cancel", role: .cancel) { }
            }
            else{
                Button("Dismiss", role: .cancel) { }
            }
            
        }
    }
    
    @ViewBuilder
    private func existingWorkoutCardContent(workout: Workouts?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Workout name + LIVE badge
            HStack(alignment: .top) {
                Text(workout?.name ?? "Workout")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.staticWhite)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)

                if workoutController.hasActiveSession && workoutController.activeWorkoutId == workoutId {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .scaleEffect(animate ? 1.4 : 0.8)
                        Text("Active")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.green.opacity(0.7), lineWidth: 1))
                }
            }

            Spacer()

            // Play button
            HStack {
                Spacer()
                Button(action: {
                    if let activeWorkoutId = workoutController.activeWorkoutId, activeWorkoutId != workoutId {
                        alertTitle = "You must complete your current session before starting a new one"
                        showAlert = true
                    } else {
                        appViewModel.navigateTo(.workoutActiveView(workoutId))
                    }
                }) {
                    playButtonContent()
                }
                .accessibilityLabel(playButtonAccessibilityLabel())
                .accessibilityHint("Double tap to \(playButtonAccessibilityHint())")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func playButtonContent() -> some View {
        if(workoutController.hasActiveSession && workoutController.activeWorkoutId == workoutId) {
                ZStack {
                    // Ripple ring 1
                    Circle()
                        .stroke(Color.green.opacity(ripple1 ? 0.0 : 0.55), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(ripple1 ? 2.2 : 1.0)

                    // Ripple ring 2 (staggered)
                    Circle()
                        .stroke(Color.green.opacity(ripple2 ? 0.0 : 0.55), lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .scaleEffect(ripple2 ? 2.2 : 1.0)

                    // Black outline (slightly larger copy behind)
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 43))
                        .foregroundColor(.black.opacity(0.45))
                        .scaleEffect(animate ? 1.12 : 1.0)

                    // Main icon
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                        .scaleEffect(animate ? 1.12 : 1.0)
                        .shadow(color: .green.opacity(0.7), radius: animate ? 10 : 5)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                    withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                        ripple1 = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                            ripple2 = true
                        }
                    }
                }
        } else {
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 56, height: 56)

                // Play icon
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.staticWhite)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    @ViewBuilder
    private func contextMenuContent() -> some View {
        Button(action: {
            if  workoutController.activeWorkoutId == workoutId {
                alertTitle = "You Cannot Edit a Workout That Is In Progress"
                showAlert = true
            } else {
                onEdit?()
            }
        }) {
            Label("Edit", systemImage: "square.and.pencil")
        }

        Button(action: {
            onDuplicate?()
        }) {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Button(action: {
            shareWorkout()
        }) {
            Label("Share Workout", systemImage: "square.and.arrow.up")
        }

        Button(action: {
            if workoutController.activeWorkoutId == workoutId {
                alertTitle = "You Cannot Customize a Workout That Is In Progress"
                showAlert = true
            } else {
                appViewModel.navigateTo(.customizeCardView(workoutId))
            }
        }) {
            Label("Customize Card", systemImage: "paintpalette")
        }

        Button(role: .destructive, action: {
            if  workoutController.activeWorkoutId == workoutId {
                alertTitle = "You Cannot Delete a Workout That Is In Progress"
                showAlert = true
            }
            else{
                alertTitle =  "Are you sure you want to delete this workout?"
                showAlert = true
            }
        }) {
            Label("Delete", systemImage: "trash")
        }
    }

    private func presentShareSheet(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(activityVC, animated: true)
    }

    private func shareWorkout() {
        guard let data = workoutController.exportWorkout(workoutId) else {
            alertTitle = "Failed to export workout"
            showAlert = true
            return
        }

        let workoutName = workout?.name ?? "Workout"
        let fileName = "\(workoutName.replacingOccurrences(of: " ", with: "_")).soleus"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            let items: [Any] = [WorkoutActivityItemProvider(fileURL: tempURL, workoutData: data, workoutName: workoutName)]
            presentShareSheet(items: items)
        } catch {
            alertTitle = "Failed to create shareable file"
            showAlert = true
        }
    }

    private func playButtonAccessibilityLabel() -> String {
        let workoutName = workout?.name ?? "Workout"
        if workoutController.hasActiveSession && workoutController.activeWorkoutId == workoutId {
            return "Resume \(workoutName)"
        } else {
            return "Start \(workoutName)"
        }
    }

    private func playButtonAccessibilityHint() -> String {
        if workoutController.hasActiveSession && workoutController.activeWorkoutId == workoutId {
            return "resume your active workout session"
        } else {
            return "begin tracking this workout"
        }
    }

    private func startShakeAnimation() {
        withAnimation(
            Animation.easeInOut(duration: 0.15)
                .repeatForever(autoreverses: true)
        ) {
            shakeOffset = 1.5
        }
    }
}

// Extension to conditionally apply modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
