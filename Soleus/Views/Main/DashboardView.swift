import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel
    @EnvironmentObject var achievementManager: AchievementManager

    @AppStorage("weightPreference") private var weightPreference: String = "Lbs"
    @AppStorage("distancePreference") private var distancePreference: String = "mile"

    @State private var lifeStats: WorkoutStats?
    @State private var personalRecords: PersonalRecords?
    @State private var workoutDaysThisWeek: Set<Date> = []
    @State private var lastWorkout: WorkoutHistory?
    @State private var widgetSettings: [DashboardWidgetSetting] = DashboardConfigStore.load()
    @State private var showCustomizeSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Divider()

                if workoutController.hasActiveSession, let workoutId = workoutController.activeWorkoutId {
                    resumeWorkoutBanner(workoutId: workoutId)
                }

                ForEach(widgetSettings.filter(\.isVisible)) { setting in
                    widgetView(for: setting.widget)
                }

                Spacer()
            }
        }
        .background(Color.myWhite.ignoresSafeArea())
        .navigationBarItems(trailing:
            Button(action: {
                showCustomizeSheet = true
            }) {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityIdentifier(AccessibilityID.dashboardCustomizeButton)
        )
        .sheet(isPresented: $showCustomizeSheet) {
            DashboardCustomizeView(settings: $widgetSettings)
        }
        .onChange(of: widgetSettings) { _, newSettings in
            DashboardConfigStore.save(newSettings)
        }
        .onAppear {
            refreshData()
        }
    }

    private func refreshData() {
        lifeStats = achievementManager.getWorkoutStats()
        personalRecords = achievementManager.getPersonalRecords()
        workoutDaysThisWeek = achievementManager.getWorkoutDaysThisWeek()
        lastWorkout = achievementManager.getMostRecentWorkout()
        widgetSettings = DashboardConfigStore.load()
    }

    @ViewBuilder
    private func widgetView(for widget: DashboardWidget) -> some View {
        switch widget {
        case .thisWeek:
            thisWeekCard
        case .lastWorkout:
            lastWorkoutCard
        case .achievements:
            achievementsCard
        case .streaks:
            streaksCard
        case .lifetimeStats:
            lifetimeStatsCard
        case .personalRecords:
            personalRecordsCard
        }
    }

    // MARK: - Resume Banner (always pinned above widgets)

    private func resumeWorkoutBanner(workoutId: UUID) -> some View {
        Button(action: {
            appViewModel.navigateTo(.workoutActiveView(workoutId))
        }) {
            HStack(spacing: 12) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.title2)
                    .foregroundColor(.staticWhite)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workoutController.activeWorkoutName ?? "Workout")
                        .font(.headline)
                        .foregroundColor(.staticWhite)
                    Text("Tap to Resume")
                        .font(.subheadline)
                        .foregroundColor(.staticWhite.opacity(0.9))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.staticWhite.opacity(0.7))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.myBlue, Color.myBlue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.myBlue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityIdentifier(AccessibilityID.dashboardResumeBanner)
    }

    // MARK: - This Week Card

    /// The seven days of the current week, per the user's calendar.
    private var currentWeekDays: [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }
    }

    private var thisWeekCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 32))
                    .foregroundColor(.myGreen)

                Text("This Week")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(workoutDaysThisWeek.count) workout\(workoutDaysThisWeek.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(currentWeekDays, id: \.self) { day in
                    weekDayDot(for: day)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }

    private func weekDayDot(for day: Date) -> some View {
        let calendar = Calendar.current
        let didWorkOut = workoutDaysThisWeek.contains(calendar.startOfDay(for: day))
        let isToday = calendar.isDateInToday(day)
        let weekdayLetter = calendar.veryShortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]

        return VStack(spacing: 6) {
            Text(weekdayLetter)
                .font(.caption2)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(didWorkOut ? Color.myGreen : Color(.tertiarySystemGroupedBackground))
                    .frame(width: 32, height: 32)

                if didWorkOut {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.staticWhite)
                }

                if isToday {
                    Circle()
                        .stroke(Color.myGreen, lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Last Workout Card

    private var lastWorkoutDateText: String {
        guard let date = lastWorkout?.workoutDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    private var lastWorkoutCard: some View {
        Button(action: {
            appViewModel.navigateTo(.workoutHistoryView)
        }) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(.myPurple)

                    Text("Last Workout")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                if let history = lastWorkout {
                    VStack(spacing: 12) {
                        HStack {
                            Text(history.workoutR?.name ?? "Unknown Workout")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            Text(lastWorkoutDateText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        StatRow(
                            icon: "timer",
                            label: "Duration",
                            value: history.workoutTimeToComplete ?? "—",
                            color: .myPurple
                        )

                        if history.totalWeightLifted > 0 {
                            Divider()

                            StatRow(
                                icon: "scalemass",
                                label: "Weight Lifted",
                                value: "\(Int(history.totalWeightLifted)) \(weightPreference)",
                                color: .myPurple
                            )
                        }

                        if history.repsCompleted > 0 {
                            Divider()

                            StatRow(
                                icon: "figure.walk",
                                label: "Reps",
                                value: "\(history.repsCompleted)",
                                color: .myPurple
                            )
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 40))
                            .foregroundColor(.myPurple.opacity(0.5))

                        Text("Complete a workout to see it here!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
        .accessibilityIdentifier(AccessibilityID.dashboardLastWorkoutCard)
    }

    // MARK: - Achievements Card

    private var achievementsCard: some View {
        Button(action: {
            appViewModel.navigateTo(.achievementsView)
        }) {
            HStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.staticWhite)
                    .padding(.leading, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Achievements")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.staticWhite)

                    Text("View your progress")
                        .font(.subheadline)
                        .foregroundColor(.staticWhite.opacity(0.9))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.staticWhite.opacity(0.7))
                    .padding(.trailing, 8)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.myTan, Color.myLightBrown]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(15)
            .shadow(color: Color.myTan.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }

    // MARK: - Streaks Card

    @ViewBuilder
    private var streaksCard: some View {
        if let stats = lifeStats {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)

                    Text("Workout Streaks")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()
                }

                HStack(spacing: 16) {
                    // Current Streak
                    VStack(spacing: 8) {
                        Text("\(stats.currentStreak)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(stats.currentStreak > 0 ? .orange : .secondary)

                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(stats.currentStreak > 0 ? .orange : .secondary)
                            Text("Current Streak")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(12)

                    // Longest Streak
                    VStack(spacing: 8) {
                        Text("\(stats.longestStreak)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.myBlue)

                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.myBlue)
                            Text("Longest Streak")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                if stats.currentStreak > 0 {
                    Text("Keep it up! You're on fire! 🔥")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                } else if stats.longestStreak > 0 {
                    Text("Start a new streak today!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Work out 2 days in a row to start your first streak!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal)
        }
    }

    // MARK: - Lifetime Stats Card

    private var lifetimeStatsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.myBlue)

                Text("Lifetime Stats")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()
            }

            if let stats = lifeStats {
                VStack(spacing: 12) {
                    StatRow(
                        icon: "figure.walk",
                        label: "Total Reps",
                        value: "\(stats.totalReps)",
                        color: .myBlue
                    )

                    Divider()

                    StatRow(
                        icon: "scalemass",
                        label: "Total Weight Lifted",
                        value: formatWeight(stats.totalWeightLifted),
                        color: .myBlue
                    )

                    Divider()

                    StatRow(
                        icon: "timer",
                        label: "Total Workout Time",
                        value: String(format: "%.1f hrs", stats.totalTimeInHours),
                        color: .myBlue
                    )

                    Divider()

                    StatRow(
                        icon: "figure.run",
                        label: "Total Distance",
                        value: String(format: "%.1f \(distancePreference)", stats.totalDistance),
                        color: .myBlue
                    )
                }
            } else {
                ProgressView()
                    .padding()
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }

    // MARK: - Personal Records Card

    private var personalRecordsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.myTan)

                Text("Personal Records")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()
            }

            if let records = personalRecords {
                VStack(spacing: 12) {
                    if records.heaviestWeight > 0 {
                        StatRow(
                            icon: "scalemass.fill",
                            label: "Heaviest Workout",
                            value: formatWeight(records.heaviestWeight),
                            color: .myTan
                        )

                        Divider()
                    }

                    if records.mostReps > 0 {
                        StatRow(
                            icon: "figure.walk",
                            label: "Most Reps",
                            value: "\(records.mostReps) reps",
                            color: .myTan
                        )

                        Divider()
                    }

                    if records.longestWorkoutMinutes > 0 {
                        StatRow(
                            icon: "timer",
                            label: "Longest Workout",
                            value: String(format: "%.0f min", records.longestWorkoutMinutes),
                            color: .myTan
                        )

                        if records.furthestDistance > 0 {
                            Divider()
                        }
                    }

                    if records.furthestDistance > 0 {
                        StatRow(
                            icon: "figure.run",
                            label: "Furthest Distance",
                            value: String(format: "%.1f \(distancePreference)", records.furthestDistance),
                            color: .myTan
                        )
                    }

                    // Show message if no records yet
                    if records.heaviestWeight == 0 && records.mostReps == 0 && records.longestWorkoutMinutes == 0 && records.furthestDistance == 0 {
                        VStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.myTan.opacity(0.5))

                            Text("Complete workouts to set your first records!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                    }
                }
            } else {
                ProgressView()
                    .padding()
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }

    private func formatWeight(_ weight: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true

        if let formattedNumber = formatter.string(from: NSNumber(value: weight)) {
            return "\(formattedNumber) \(weightPreference)"
        }
        return "\(Int(weight)) \(weightPreference)"
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}
