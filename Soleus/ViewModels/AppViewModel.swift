import SwiftUI

class AppViewModel: ObservableObject {
    @Published var currentView: ContentViewType = .main
    @Published var currentTab: Tab = .home
    @Published var pendingImport: ShareableWorkout? = nil

    func navigateTo(_ view: ContentViewType) {
         DispatchQueue.main.async {
             self.currentView = view
         }
    }
    
    func resetToWorkoutMainView() {
        DispatchQueue.main.async {
            self.currentTab = .workout 
            self.currentView = .main
        }
    }

    // Update the navigation logic as needed to work with both views and tabs

    enum ContentViewType : Equatable, Hashable {
        case main
        case workoutOverview(UUID, String) // workoutId, elapsedTime
        case workoutActiveView(UUID)
        case workoutHistoryView
        case customizeCardView(UUID)
        case achievementsView
        case weeklyScheduleView
    }
    
    enum Tab : Equatable {
         case home
         case workout
         case nutrition
    }
    
}
