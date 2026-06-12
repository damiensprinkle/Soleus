import SwiftUI
import Charts

/// Exercise-first progress view: pick an exercise, see a chart of its trend
/// over time plus personal best, latest, and change stats.
struct WorkoutProgressView: View {
    let histories: [WorkoutHistory]
    @State private var selectedExercise: String?
    @State private var searchText: String = ""

    /// Below this many exercises the search field is just clutter.
    private let searchThreshold = 8

    var body: some View {
        if exerciseData.isEmpty {
            HistoryEmptyStateView(
                icon: "chart.line.uptrend.xyaxis",
                title: "No progress data yet",
                subtitle: "Complete workouts to see your progress for each exercise over time."
            )
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    exercisePicker

                    if let data = currentExercise {
                        ExerciseProgressDetailCard(data: data)
                            .id(data.name)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.myWhite)
        }
    }

    // MARK: - Exercise Selection

    private var currentExercise: ExerciseProgressData? {
        exerciseData.first { $0.name == selectedExercise } ?? exerciseData.first
    }

    private var filteredExercises: [ExerciseProgressData] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return exerciseData }
        return exerciseData.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise")
                .font(.headline)
                .foregroundColor(.secondary)

            if exerciseData.count > searchThreshold {
                searchField
            }

            if filteredExercises.isEmpty {
                Text("No exercises match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filteredExercises) { exercise in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedExercise = exercise.name
                                searchText = ""
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(exercise.name)
                                    .font(.subheadline)
                                    .fontWeight(isSelected(exercise) ? .semibold : .regular)
                                Text("\(exercise.sessions.count)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(isSelected(exercise) ? Color.white.opacity(0.25) : Color.gray.opacity(0.2))
                                    )
                            }
                            .foregroundColor(isSelected(exercise) ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected(exercise) ? Color.myBlue : Color(.secondarySystemGroupedBackground))
                            )
                        }
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Search exercises", text: $searchText)
                .font(.subheadline)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityIdentifier(AccessibilityID.historyProgressSearchField)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func isSelected(_ exercise: ExerciseProgressData) -> Bool {
        exercise.name == currentExercise?.name
    }

    // MARK: - Data Extraction

    /// One entry per unique exercise name across all history snapshots,
    /// sorted by how often the exercise was performed.
    private var exerciseData: [ExerciseProgressData] {
        var sessionsByExercise: [String: [ExerciseSessionPoint]] = [:]

        for history in histories {
            guard let date = history.workoutDate,
                  let details = history.details?.allObjects as? [WorkoutDetail] else { continue }

            for detail in details {
                guard let name = detail.exerciseName,
                      let sets = detail.sets?.allObjects as? [WorkoutSet], !sets.isEmpty else { continue }

                let point = ExerciseSessionPoint(
                    date: date,
                    maxWeight: sets.map { $0.weight }.max() ?? 0,
                    totalReps: sets.reduce(0) { $0 + Int($1.reps) },
                    volume: sets.reduce(0) { $0 + Float($1.reps) * $1.weight },
                    totalDistance: sets.reduce(0) { $0 + $1.distance },
                    totalTimeSeconds: sets.reduce(0) { $0 + Int($1.time) }
                )
                sessionsByExercise[name, default: []].append(point)
            }
        }

        return sessionsByExercise
            .map { name, points in
                ExerciseProgressData(name: name, sessions: points.sorted { $0.date < $1.date })
            }
            .sorted {
                $0.sessions.count != $1.sessions.count
                    ? $0.sessions.count > $1.sessions.count
                    : $0.name < $1.name
            }
    }
}

// MARK: - Models

struct ExerciseSessionPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Float
    let totalReps: Int
    let volume: Float
    let totalDistance: Float
    let totalTimeSeconds: Int
}

struct ExerciseProgressData: Identifiable {
    let name: String
    let sessions: [ExerciseSessionPoint]  // ascending by date

    var id: String { name }

    /// Metrics that actually have data for this exercise, in display order.
    var availableMetrics: [ProgressMetric] {
        ProgressMetric.allCases.filter { metric in
            sessions.contains { metric.value(from: $0) > 0 }
        }
    }
}

enum ProgressMetric: String, CaseIterable, Identifiable {
    case topSet = "Top Set"
    case volume = "Volume"
    case reps = "Reps"
    case distance = "Distance"
    case time = "Time"

    var id: String { rawValue }

    func value(from point: ExerciseSessionPoint) -> Double {
        switch self {
        case .topSet: return Double(point.maxWeight)
        case .volume: return Double(point.volume)
        case .reps: return Double(point.totalReps)
        case .distance: return Double(point.totalDistance)
        case .time: return Double(point.totalTimeSeconds) / 60.0  // minutes
        }
    }

    func unitLabel(weightPreference: String, distancePreference: String) -> String {
        switch self {
        case .topSet, .volume: return weightPreference
        case .reps: return "reps"
        case .distance: return distancePreference
        case .time: return "min"
        }
    }
}

// MARK: - Exercise Detail Card

struct ExerciseProgressDetailCard: View {
    let data: ExerciseProgressData
    @State private var selectedMetric: ProgressMetric?
    @AppStorage("weightPreference") private var weightPreference: String = "Lbs"
    @AppStorage("distancePreference") private var distancePreference: String = "mile"

    private var metric: ProgressMetric {
        selectedMetric ?? data.availableMetrics.first ?? .reps
    }

    private var points: [ExerciseSessionPoint] {
        data.sessions
    }

    private var values: [Double] {
        points.map { metric.value(from: $0) }
    }

    private var bestValue: Double { values.max() ?? 0 }

    private var unit: String {
        metric.unitLabel(weightPreference: weightPreference, distancePreference: distancePreference)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(data.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("\(points.count) session\(points.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Metric picker
            if data.availableMetrics.count > 1 {
                Picker("Metric", selection: Binding(
                    get: { metric },
                    set: { selectedMetric = $0 }
                )) {
                    ForEach(data.availableMetrics) { candidate in
                        Text(candidate.rawValue).tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
            }

            chartSection

            statTiles

            recentSessions
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    // MARK: Chart

    @ViewBuilder
    private var chartSection: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value(metric.rawValue, metric.value(from: point))
            )
            .foregroundStyle(
                LinearGradient(
                    gradient: Gradient(colors: [Color.myBlue.opacity(0.25), Color.myBlue.opacity(0.02)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Date", point.date),
                y: .value(metric.rawValue, metric.value(from: point))
            )
            .foregroundStyle(Color.myBlue)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.monotone)

            PointMark(
                x: .value("Date", point.date),
                y: .value(metric.rawValue, metric.value(from: point))
            )
            .foregroundStyle(isBest(point) ? Color.orange : Color.myBlue)
            .symbolSize(isBest(point) ? 110 : 50)
        }
        .frame(height: 200)

        if points.count < 2 {
            Text("Complete more sessions of this exercise to see a trend.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            HStack(spacing: 4) {
                Circle().fill(Color.orange).frame(width: 8, height: 8)
                Text("Personal best")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func isBest(_ point: ExerciseSessionPoint) -> Bool {
        bestValue > 0 && metric.value(from: point) == bestValue
    }

    // MARK: Stats

    private var statTiles: some View {
        let latest = values.last ?? 0
        let first = values.first ?? 0
        let change = latest - first

        return HStack(spacing: 12) {
            HistoryStatBox(
                icon: "trophy.fill",
                label: "Best",
                value: formatValue(bestValue),
                color: .orange
            )
            HistoryStatBox(
                icon: "clock.arrow.circlepath",
                label: "Latest",
                value: formatValue(latest),
                color: .blue
            )
            HistoryStatBox(
                icon: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                label: "Change",
                value: (change >= 0 ? "+" : "") + formatValue(change),
                color: change >= 0 ? .green : .red
            )
        }
    }

    private func formatValue(_ value: Double) -> String {
        let number = value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
        return "\(number) \(unit)"
    }

    // MARK: Recent Sessions

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Sessions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            let recent = Array(points.suffix(5).reversed())
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, point in
                HStack {
                    Text(formatDate(point.date))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatValue(metric.value(from: point)))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isBest(point) ? .orange : .myBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((isBest(point) ? Color.orange : Color.myBlue).opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.vertical, 4)

                if index < recent.count - 1 {
                    Divider()
                }
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    WorkoutProgressView(histories: [])
}
