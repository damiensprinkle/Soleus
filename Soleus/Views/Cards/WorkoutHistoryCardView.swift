import SwiftUI

struct WorkoutHistoryCardView: View {
    let history: WorkoutHistory
    var onDelete: (() -> Void)?
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel
    @State private var workoutTitle: String = ""
    @AppStorage("weightPreference") private var weightPreference: String = "Lbs"
    @AppStorage("distancePreference") private var distancePreference: String = "mile"
    
    @State private var isExpanded: Bool = false
    @State private var showAlert: Bool = false
    @State private var showDeletedTooltip: Bool = false

    private var isDeletedWorkout: Bool { history.workoutR == nil }
    
    private var formattedDate: String {
        guard let date = history.workoutDate else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and delete button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(workoutTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .foregroundColor(isDeletedWorkout ? .secondary : .primary)

                        if isDeletedWorkout {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isDeletedWorkout {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showDeletedTooltip.toggle()
                            }
                        }
                    }
                    .popover(isPresented: $showDeletedTooltip, arrowEdge: .bottom) {
                        Text("This workout has been deleted")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .presentationCompactAdaptation(.popover)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: {
                    showAlert = true
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red.opacity(0.8))
                }
            }

            // Stats boxes
            HStack(spacing: 12) {
                HistoryStatBox(
                    icon: "clock.fill",
                    label: "Duration",
                    value: history.workoutTimeToComplete ?? "0",
                    color: .green
                )

                HistoryStatBox(
                    icon: "dumbbell.fill",
                    label: "Total Weight",
                    value: "\(Int(history.totalWeightLifted)) \(weightPreference)",
                    color: .blue
                )
            }

            // Exercises header
            HStack {
                Text("Exercises")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide" : "Show")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3)
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Exercises list
            if isExpanded {
                VStack(spacing: 8) {
                    if let exercises = history.details?.allObjects as? [WorkoutDetail], !exercises.isEmpty {
                        ForEach(exercises.sorted(by: { ($0.orderIndex) < ($1.orderIndex) }), id: \.self) { detail in
                            exerciseDetailView(detail: detail)
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("No exercises recorded")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .padding(.horizontal, 8)
        .onAppear {
            workoutTitle = history.workoutR?.name ?? "Unknown Workout"
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Confirm Deletion"),
                message: Text("Are you sure you want to delete this workout history?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete?()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    @ViewBuilder
    private func exerciseDetailView(detail: WorkoutDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Exercise name
            Text(detail.exerciseName ?? "Unknown Exercise")
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            // Metrics row
            HStack(spacing: 12) {
                if detail.exerciseQuantifier == "Reps" {
                    let totalReps = (detail.sets?.allObjects as? [WorkoutSet])?.reduce(0) { $0 + Int($1.reps) } ?? 0
                    MetricBadge(
                        icon: "repeat",
                        label: "Reps",
                        value: "\(totalReps)",
                        color: .purple
                    )
                }

                if detail.exerciseQuantifier == "Distance" {
                    let totalDistance = (detail.sets?.allObjects as? [WorkoutSet])?.reduce(0.0) { $0 + ($1.distance) } ?? 0.0
                    MetricBadge(
                        icon: "figure.run",
                        label: "Distance",
                        value: "\(totalDistance, default: "%.1f") \(distancePreference)",
                        color: .orange
                    )
                }

                if detail.exerciseMeasurement == "Weight" {
                    let totalWeight = calculateTotalWeight(for: detail)
                    MetricBadge(
                        icon: "scalemass",
                        label: "Weight",
                        value: "\(Int(totalWeight)) \(weightPreference)",
                        color: .blue
                    )
                }

                if detail.exerciseMeasurement == "Time" {
                    let totalTimeInMinutes = calculateTotalTime(for: detail)
                    let totalTime = totalTimeInMinutes / 60
                    MetricBadge(
                        icon: "timer",
                        label: "Time",
                        value: "\(totalTime) min",
                        color: .green
                    )
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
 
    private func calculateTotalWeight(for detail: WorkoutDetail) -> Float {
        guard let sets = detail.sets?.allObjects as? [WorkoutSet] else {
            return 0
        }
        var totalWeight: Float = 0
        for set in sets {
            let reps = set.reps > 0 ? Float(set.reps) : 1
            let weight = Float(set.weight)
            totalWeight += weight * reps
        }
        
        return totalWeight
    }
    
    private func calculateTotalTime(for detail: WorkoutDetail) -> Int {
        guard let sets = detail.sets?.allObjects as? [WorkoutSet] else {
            AppLogger.ui.warning("No sets found for exercise in history detail")
            return 0
        }
        
        var totalTimeInMinutes: Int = 0
        for set in sets {

            if set.time > 0 {
                totalTimeInMinutes += Int(set.time)
                if set.reps > 0 {
                    totalTimeInMinutes += Int(set.time) * Int(set.reps)
                }
            } else {
                AppLogger.ui.warning("Invalid or missing time for set: \(set)")
            }
        }
        
        AppLogger.ui.debug("Total time calculated: \(totalTimeInMinutes) minutes")
        
        return totalTimeInMinutes
    }
}

// MARK: - Supporting Views

struct HistoryStatBox: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

struct MetricBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

