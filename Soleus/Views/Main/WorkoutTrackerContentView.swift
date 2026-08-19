import SwiftUI

struct WorkoutContentMainView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.managedObjectContext) var managedObjectContext
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel


    var body: some View {
        contentView
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(navigationBarTitleDisplayMode)
            .id(appViewModel.currentView)
    }

    @ViewBuilder
    private var contentView: some View {
        Group {
            // Decide which view to present based on the currentView state
            switch appViewModel.currentView {
            case .main:
                WorkoutTrackerMainView()
                    .environment(\.managedObjectContext, managedObjectContext)
                    .environmentObject(workoutController)
                    .transition(.slide)

            case .workoutOverview(let workoutId, let elapsedTime):
                WorkoutOverviewView(workoutId: workoutId, elapsedTime: elapsedTime)
                    .environmentObject(workoutController)
                    .environmentObject(appViewModel)
                    .transition(.slide)

            case .workoutActiveView(let workoutId):
                ActiveWorkoutView(workoutId: workoutId)
                    .id(workoutId)
                    .environmentObject(appViewModel)
                    .environmentObject(workoutController)
                    .transition(.slide)

            case .workoutHistoryView:
                WorkoutHistoryView()
                    .environmentObject(appViewModel)
                    .environmentObject(workoutController)
                    .transition(.opacity)

            case .customizeCardView(let workoutId):
                CustomizeCardView(workoutId: workoutId)
                    .environmentObject(appViewModel)
                    .environmentObject(workoutController)
                    .transition(.slide)

            case .weeklyScheduleView:
                WeeklyScheduleView()
                    .environmentObject(appViewModel)
                    .environmentObject(workoutController)
                    .transition(.slide)

            case .achievementsView:
                // Achievements view is handled in CustomTabView's homeContent
                EmptyView()
            }
        }
        .animation(.default, value: appViewModel.currentView)
    }

    private var navigationTitle: String {
        switch appViewModel.currentView {
        case .main:
            return "My Workouts"
        case .workoutHistoryView:
            return "My History"
        case .workoutOverview(_, let elapsedTime):
            return "Time: \(elapsedTime)"
        case .workoutActiveView:
            return ""
        case .customizeCardView:
            return "Customize Card"
        case .weeklyScheduleView: 
            return "Weekly Schedule"
        case .achievementsView:
            return "Achievements"
        }
    }

    private var navigationBarTitleDisplayMode: NavigationBarItem.TitleDisplayMode {
        return .inline
    }
}
