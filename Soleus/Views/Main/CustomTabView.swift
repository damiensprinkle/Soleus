import SwiftUI

struct CustomTabView: View {
    @State private var selectedTab: Tab = .workout
    @EnvironmentObject var appViewModel: AppViewModel
    @EnvironmentObject var workoutController: WorkoutTrackerViewModel


    enum Tab: String {
        case dashboard, workout, settings
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabContent
                    .navigationTitle(navigationTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .id(selectedTab)

                Divider()

                HStack {
                    tabButton(for: .workout, systemImage: "dumbbell.fill")
                        .accessibilityIdentifier(AccessibilityID.tabWorkout)

                    Spacer()
                    tabButton(for: .dashboard, systemImage: "chart.bar.fill")
                        .accessibilityIdentifier(AccessibilityID.tabDashboard)

                    Spacer()
                    tabButton(for: .settings, systemImage :"gearshape")
                        .accessibilityIdentifier(AccessibilityID.tabSettings)
                }
                .padding()
                .background(
                    Color("MyGrey").opacity(0.1)
                        .ignoresSafeArea(.all, edges: .bottom)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(.stack)
        .ignoresSafeArea(.keyboard)
        .onChange(of: appViewModel.currentView) { _, newView in
            // Dashboard widgets can navigate into workout-flow views (resume
            // banner, last-workout card). Those render inside the workout tab,
            // so follow the navigation there.
            switch newView {
            case .workoutActiveView, .workoutHistoryView, .workoutOverview, .customizeCardView:
                if selectedTab != .workout {
                    selectedTab = .workout
                }
            case .main, .achievementsView:
                break
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .workout:
                WorkoutContentMainView()
                    .environmentObject(workoutController)
                    .transition(.opacity)
            case .dashboard:
                dashboardContent
                    .environmentObject(workoutController)
                    .transition(.opacity)
            case .settings:
                SettingsView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: selectedTab)
    }

    @ViewBuilder
    private var dashboardContent: some View {
        Group {
            switch appViewModel.currentView {
            case .achievementsView:
                AchievementsView()
                    .environmentObject(appViewModel)
                    .transition(.opacity)
            default:
                DashboardView()
                    .environmentObject(appViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: appViewModel.currentView)
    }

    private var navigationTitle: String {
        switch selectedTab {
        case .workout:
            return ""
        case .dashboard:
            if appViewModel.currentView == .achievementsView {
                return "Achievements"
            }
            return "Dashboard"
        case .settings:
            return "Settings"
        }
    }
    
    @ViewBuilder
    private func tabButton(for tab: Tab, systemImage: String) -> some View {
        Button(action: {
            if selectedTab == tab && tab == .workout {
                appViewModel.resetToWorkoutMainView()
            } else {
                selectedTab = tab
                appViewModel.resetToWorkoutMainView() //
            }
        }) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundColor(selectedTab == tab ? Color("MyBlue") : Color("MyGrey"))
        }
    }
}
