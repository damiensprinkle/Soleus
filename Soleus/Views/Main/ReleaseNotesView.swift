import SwiftUI

struct ReleaseNotesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    releaseSection(
                        version: "v1.0.5",
                        items: [
                            ("dumbbell.fill", "My Exercises", "A built-in exercise library with 55+ pre-seeded exercises across 9 categories. Browse, search, and pick exercises when building a workout — no more typing names from scratch."),
                            ("plus.circle.fill", "Custom Exercises", "Create your own exercises with a name, description, category, and default tracking settings. Custom exercises live in My Exercises (Settings → Utilities)."),
                            ("timer", "Per-Exercise Rest Timer", "Set a different rest duration for each exercise in a workout plan. When a set is completed, the rest timer uses that exercise's own duration instead of the global default."),
                            ("calendar", "History Calendar View", "A new calendar mode in Workout History shows a green dot on every day you trained. Tap a day to expand a workout summary — exercises and sets, right in the calendar."),
                            ("chart.line.uptrend.xyaxis", "Improved Progress View", "The Progress tab is fully redesigned with area charts, a best-performance highlight, and a search field so you can quickly find any exercise across hundreds of entries."),
                        ]
                    )

                    releaseSection(
                        version: "v1.0.3",
                        items: [
                            ("icloud.fill", "iCloud Sync", "Your workouts, history, and settings now sync automatically across all your devices via iCloud. Your data is stored in your personal iCloud account — we never see it."),
                            ("ellipsis.circle", "Exercise Menu", "Edit mode now uses a ··· menu per exercise. Rename, add a note, move up or down, or delete — all in one place."),
                            ("arrow.up.arrow.down", "Scroll While Reordering", "Drag a workout card near the top or bottom edge and the list scrolls automatically — no more being stuck if you have more than a screenful of workouts."),
                            ("figure.run.circle.fill", "Active Workout Indicator", "The active workout card now shows a pulsing ripple effect and a LIVE badge so it's always easy to spot at a glance."),
                            ("note.text", "Note Changes Preview", "If you add or edit a note during a workout, the changes preview now shows it before you decide whether to save."),
                        ]
                    )

                    releaseSection(
                        version: "v1.0.2",
                        items: [
                            ("bell.fill", "Push Notifications", "Stay on top of your fitness with customizable reminders — active workout alerts, inactivity nudges, and streak-at-risk warnings."),
                            ("square.and.arrow.down", "Import Workout", "Import .soleus workout files directly from Settings for a cleaner main view."),
                            ("heart.fill", "Apple Health", "Completed workouts are now written to Apple Health. Enable it in Settings → Preferences → Apple Health."),
                            ("note.text", "Inline Exercise Notes", "Tap the notes icon while in edit mode to add or edit notes directly on the exercise — no more dialog pop-ups."),
                            ("calendar", "Smarter History Picker", "The year picker in Workout History now only shows years that actually have data, and never shows future years."),
                            ("hand.tap.fill", "New User Tip", "First-time users now see a helpful hint to long-press a workout card to access editing, sharing, and more."),
                            ("gearshape.fill", "Settings Cleanup", "Rest Timer settings are now grouped under Preferences for a tidier Settings screen."),
                        ]
                    )

                    releaseSection(
                        version: "v1.0.1",
                        items: [
                            ("hand.point.up.left.fill", "Drag to Reorder", "Long-press any workout card and drag to reorder — just like your iPhone home screen."),
                            ("rectangle.and.pencil.and.ellipsis", "Swipe-Down Warning", "Adding or editing a workout now warns you before discarding unsaved changes."),
                            ("textformat.123", "Character Limits", "Workout and exercise name fields now show a live character counter with a 30-character cap."),
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("What's New")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func releaseSection(version: String, items: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(version)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.myBlue)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(items, id: \.1) { icon, title, description in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundColor(.myBlue)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
