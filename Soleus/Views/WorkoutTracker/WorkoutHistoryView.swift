import SwiftUI

struct WorkoutHistoryView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel
    @State private var histories: [WorkoutHistory] = []
    @State private var mode: HistoryMode = .list

    enum HistoryMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"
        case progress = "Progress"

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .calendar: return "calendar"
            case .progress: return "chart.line.uptrend.xyaxis"
            }
        }

        var accessibilityID: String {
            switch self {
            case .list: return AccessibilityID.historyModeList
            case .calendar: return AccessibilityID.historyModeCalendar
            case .progress: return AccessibilityID.historyModeProgress
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modePicker

            Divider()

            Group {
                switch mode {
                case .list:
                    listContent
                        .transition(.opacity)
                case .calendar:
                    HistoryCalendarView(histories: histories)
                        .transition(.opacity)
                case .progress:
                    WorkoutProgressView(histories: histories)
                        .transition(.opacity)
                }
            }
        }
        .background(Color.myWhite)
        .onAppear {
            loadHistories()
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(HistoryMode.allCases, id: \.self) { candidate in
                modeButton(for: candidate)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func modeButton(for candidate: HistoryMode) -> some View {
        let isSelected = mode == candidate
        return Button(action: {
            withAnimation(.spring(response: 0.3)) {
                mode = candidate
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: candidate.icon)
                    .font(.system(size: 14))
                Text(candidate.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.myBlue : Color.gray.opacity(0.2))
            )
        }
        .accessibilityIdentifier(candidate.accessibilityID)
    }

    // MARK: - List Mode

    private var listContent: some View {
        Group {
            if histories.isEmpty {
                HistoryEmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No workout history yet",
                    subtitle: "Your past workouts will appear here once you complete them.",
                    titleAccessibilityID: AccessibilityID.historyEmptyStateText
                )
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                        ForEach(monthGroups, id: \.label) { group in
                            Section(header: monthHeader(group.label, count: group.histories.count)) {
                                ForEach(group.histories, id: \.self) { history in
                                    if let historyId = history.id {
                                        WorkoutHistoryCardView(history: history, onDelete: {
                                            deleteWorkoutHistory(historyId)
                                        })
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private struct MonthGroup {
        let label: String
        let histories: [WorkoutHistory]
    }

    /// Histories arrive sorted newest-first, so consecutive runs of the same
    /// month label form the section groups.
    private var monthGroups: [MonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var groups: [(label: String, histories: [WorkoutHistory])] = []
        for history in histories {
            let label = history.workoutDate.map { formatter.string(from: $0) } ?? "Unknown Date"
            if groups.last?.label == label {
                groups[groups.count - 1].histories.append(history)
            } else {
                groups.append((label, [history]))
            }
        }
        return groups.map { MonthGroup(label: $0.label, histories: $0.histories) }
    }

    private func monthHeader(_ label: String, count: Int) -> some View {
        HStack {
            Text(label)
                .font(.headline)
            Spacer()
            Text("\(count) workout\(count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.myWhite)
    }

    // MARK: - Data

    private func loadHistories() {
        histories = workoutController.workoutManager.fetchAllWorkoutHistoryAllTime() ?? []
    }

    private func deleteWorkoutHistory(_ historyId: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            histories.removeAll { $0.id == historyId }
        }
        workoutController.workoutManager.deleteWorkoutHistory(for: historyId)
    }
}

// MARK: - Shared Empty State

struct HistoryEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var titleAccessibilityID: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
                .accessibilityIdentifier(titleAccessibilityID ?? "")
            Text(subtitle)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray.opacity(0.8))
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Calendar Mode

struct HistoryCalendarView: View {
    let histories: [WorkoutHistory]

    @State private var displayedMonth: Date = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDay: Date?

    private var calendar: Calendar { Calendar.current }

    /// Start-of-day dates that have at least one completed workout.
    private var workoutsByDay: [Date: [WorkoutHistory]] {
        Dictionary(grouping: histories.filter { $0.workoutDate != nil }) { history in
            calendar.startOfDay(for: history.workoutDate!)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                monthNavigationHeader
                weekdayHeader
                dayGrid
                statsStrip
                daySummarySection
            }
            .padding()
        }
    }

    // MARK: Month Navigation

    private var canGoForward: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth),
              let currentMonthStart = calendar.dateInterval(of: .month, for: Date())?.start else { return false }
        return next <= currentMonthStart
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button(action: { shiftMonth(by: -1) }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundColor(.myBlue)
            }
            .accessibilityIdentifier(AccessibilityID.historyCalendarPreviousMonth)

            Spacer()

            Text(monthTitle)
                .font(.headline)
                .accessibilityIdentifier(AccessibilityID.historyCalendarMonthLabel)

            Spacer()

            Button(action: { shiftMonth(by: 1) }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(canGoForward ? .myBlue : Color.gray.opacity(0.4))
            }
            .disabled(!canGoForward)
            .accessibilityIdentifier(AccessibilityID.historyCalendarNextMonth)
        }
        .padding(.horizontal, 4)
    }

    private func shiftMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.spring(response: 0.3)) {
            displayedMonth = newMonth
            selectedDay = nil
        }
    }

    // MARK: Grid

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Day cells for the displayed month, padded with nils so day 1 lands on
    /// the correct weekday column.
    private var dayCells: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in dayRange {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start))
        }
        return cells
    }

    private var dayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Array(dayCells.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear.frame(height: 38)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }

    private func dayCell(for date: Date) -> some View {
        let day = calendar.startOfDay(for: date)
        let hasWorkout = workoutsByDay[day] != nil
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDay == day
        let isFuture = day > calendar.startOfDay(for: Date())

        return Button(action: {
            guard hasWorkout else { return }
            withAnimation(.spring(response: 0.3)) {
                selectedDay = isSelected ? nil : day
            }
        }) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(hasWorkout ? .bold : .regular)
                .foregroundColor(hasWorkout ? .white : (isFuture ? Color.gray.opacity(0.4) : .primary))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    Circle()
                        .fill(hasWorkout ? Color.myGreen : Color.clear)
                        .frame(width: 36, height: 36)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.myBlue : (isToday ? Color.myBlue.opacity(0.5) : Color.clear),
                                lineWidth: isSelected ? 3 : 2)
                        .frame(width: 36, height: 36)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats

    private var monthHistories: [WorkoutHistory] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        return histories.filter {
            guard let date = $0.workoutDate else { return false }
            return monthInterval.contains(date)
        }
    }

    private var activeDaysThisMonth: Int {
        Set(monthHistories.compactMap { $0.workoutDate.map { calendar.startOfDay(for: $0) } }).count
    }

    /// Consecutive days with at least one workout, ending today or yesterday.
    private var currentStreak: Int {
        let workoutDays = Set(workoutsByDay.keys)
        var day = calendar.startOfDay(for: Date())
        if !workoutDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while workoutDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private var statsStrip: some View {
        HStack(spacing: 12) {
            HistoryStatBox(
                icon: "checkmark.circle.fill",
                label: "Workouts",
                value: "\(monthHistories.count)",
                color: .green
            )
            HistoryStatBox(
                icon: "calendar",
                label: "Active Days",
                value: "\(activeDaysThisMonth)",
                color: .blue
            )
            HistoryStatBox(
                icon: "flame.fill",
                label: "Day Streak",
                value: "\(currentStreak)",
                color: .orange
            )
        }
    }

    // MARK: Day Summary

    @ViewBuilder
    private var daySummarySection: some View {
        if let selectedDay = selectedDay, let dayWorkouts = workoutsByDay[selectedDay] {
            VStack(alignment: .leading, spacing: 8) {
                Text(summaryTitle(for: selectedDay))
                    .font(.headline)

                ForEach(dayWorkouts, id: \.self) { history in
                    CalendarDaySummaryRow(history: history)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else if monthHistories.isEmpty {
            Text("No workouts completed this month.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        } else {
            Text("Tap a highlighted day to see what you did.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }

    private func summaryTitle(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day)
    }
}

// MARK: - Calendar Day Summary Row

struct CalendarDaySummaryRow: View {
    let history: WorkoutHistory
    @State private var isExpanded: Bool = false
    @AppStorage("weightPreference") private var weightPreference: String = "Lbs"
    @AppStorage("distancePreference") private var distancePreference: String = "mile"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(history.workoutR?.name ?? "Unknown Workout")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                if let duration = history.workoutTimeToComplete {
                    Label(duration, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(.myBlue)
            }

            HStack(spacing: 8) {
                if history.totalWeightLifted > 0 {
                    MetricBadge(
                        icon: "scalemass",
                        label: "Weight",
                        value: "\(Int(history.totalWeightLifted)) \(weightPreference)",
                        color: .blue
                    )
                }
                if history.repsCompleted > 0 {
                    MetricBadge(
                        icon: "repeat",
                        label: "Reps",
                        value: "\(history.repsCompleted)",
                        color: .purple
                    )
                }
                if history.totalDistance > 0 {
                    MetricBadge(
                        icon: "figure.run",
                        label: "Distance",
                        value: String(format: "%.1f %@", history.totalDistance, distancePreference),
                        color: .orange
                    )
                }
            }

            if isExpanded {
                HistoryExerciseList(history: history)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }
    }
}
