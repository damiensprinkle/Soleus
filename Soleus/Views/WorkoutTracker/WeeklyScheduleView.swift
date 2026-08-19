import SwiftUI

struct WeeklyScheduleView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel

    @State private var schedule: [Int: [WorkoutInfo]] = [:]

    private let calendar = Calendar.current

    private var todayWeekday: Int {
        calendar.component(.weekday, from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Divider()

                if workoutController.workouts.isEmpty {
                    emptyState
                } else {
                    Text("Assign workouts to the days you plan to train. Days without a workout are rest days.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    ForEach(WorkoutSchedule.orderedWeekdays(calendar: calendar), id: \.self) { day in
                        dayCard(for: day)
                    }
                }

                Spacer()
            }
            .padding(.bottom)
        }
        .background(Color.myWhite.ignoresSafeArea())
        .navigationBarItems(leading:
            Button("Back") {
                appViewModel.resetToWorkoutMainView()
            }
            .accessibilityIdentifier(AccessibilityID.scheduleBackButton)
        )
        .onAppear {
            workoutController.loadWorkouts()
            reload()
        }
    }

    // MARK: - Day Card

    private func dayCard(for day: Int) -> some View {
        let assigned = schedule[day] ?? []

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(WorkoutSchedule.weekdayName(day, calendar: calendar))
                    .font(.headline)
                    .foregroundColor(.primary)

                if day == todayWeekday {
                    Text("Today")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.myGreen.opacity(0.15))
                        .foregroundColor(.myGreen)
                        .clipShape(Capsule())
                }

                Spacer()

                addWorkoutMenu(for: day)
            }

            if assigned.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Rest Day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(assigned) { workout in
                        assignedWorkoutRow(workout, day: day)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }

    private func assignedWorkoutRow(_ workout: WorkoutInfo, day: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.caption)
                .foregroundColor(.myBlue)

            Text(workout.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Button(action: {
                remove(workout, from: day)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
                    .foregroundColor(.myRed)
            }
            .accessibilityLabel("Remove \(workout.name) from \(WorkoutSchedule.weekdayName(day, calendar: calendar))")
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private func addWorkoutMenu(for day: Int) -> some View {
        let assignedIds = Set((schedule[day] ?? []).map(\.id))
        let available = workoutController.workouts.filter { !assignedIds.contains($0.id) }

        return Menu {
            ForEach(available) { workout in
                Button(workout.name) {
                    add(workout, to: day)
                }
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(available.isEmpty ? Color.gray.opacity(0.4) : .myBlue)
        }
        .disabled(available.isEmpty)
        .accessibilityIdentifier("schedule_add_day_\(day)")
        .accessibilityLabel("Add workout to \(WorkoutSchedule.weekdayName(day, calendar: calendar))")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 80))
                .foregroundColor(.myBlue.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Workouts to Schedule")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Create a workout first, then come back to plan your week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Schedule Mutations

    private func reload() {
        schedule = workoutController.workoutManager.weeklySchedule()
    }

    private func add(_ workout: WorkoutInfo, to day: Int) {
        var days = workoutController.workoutManager.scheduledDays(for: workout.id)
        days.insert(day)
        workoutController.workoutManager.setScheduledDays(days, for: workout.id)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            reload()
        }
    }

    private func remove(_ workout: WorkoutInfo, from day: Int) {
        var days = workoutController.workoutManager.scheduledDays(for: workout.id)
        days.remove(day)
        workoutController.workoutManager.setScheduledDays(days, for: workout.id)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            reload()
        }
    }
}
