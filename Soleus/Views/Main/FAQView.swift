import SwiftUI

struct FAQView: View {
    @Environment(\.dismiss) var dismiss
    @State private var expandedQuestion: String?
    @State private var searchText: String = ""

    private var allItems: [(section: String, question: String, answer: String)] = [
        ("Getting Started", "How do I create my first workout?", "Tap the '+' icon in the top right of the Workouts tab. Give your workout a name, then add exercises by tapping 'Add Exercise'.\n\nWant a head start? Tap 'Start from Template' to pre-fill your workout with a ready-made plan (Push, Pull, Legs, and more). You can customise any template after applying it."),
        ("Getting Started", "What's the difference between a workout and workout history?", "A workout is a template or plan that you create. When you start and complete a workout, it creates a workout history entry that tracks what you actually did. This way you can reuse the same workout template multiple times while keeping a record of each session."),
        ("Using Workouts", "How do I start a workout?", "Tap the play button on any workout card. Review the exercises and sets, then tap 'Start Workout'. You can then track your progress by checking off completed sets."),
        ("Using Workouts", "Can I modify a workout while it's in progress?", "Yes! During an active workout, tap the pencil icon to enter edit mode. You can then:\n\n• Add new exercises using the + button\n• Add or remove sets\n• Tap ··· next to any exercise to rename it, add or edit a note, move it up or down, or delete it\n• Adjust weights, reps, or times\n\nAfter completing the workout, you can preview your changes before deciding whether to update the original workout template."),
        ("Using Workouts", "What happens when I finish a workout with changes?", "If you made changes during your workout, you'll see a preview showing exactly what changed (exercises added/removed, sets modified, etc.). You can then choose to:\n\n• Update Workout - Save changes to your template\n• Keep Original - Save the workout history but don't update the template\n\nThis lets you adapt workouts on the fly without permanently changing your template if you don't want to."),
        ("Using Workouts", "How do I rearrange my workouts?", "Tap the rearrange icon (arrows) in the top right to enter reorder mode. Long press a workout card to pick it up, then drag it to its new position. If you have many workouts, drag toward the top or bottom edge of the screen and the list will scroll automatically. Tap the checkmark when done."),
        ("Using Workouts", "How do I duplicate or delete a workout?", "Long press on any workout card to open the context menu. From there you can edit, duplicate, share, or delete the workout."),
        ("Exercises & Sets", "What types of exercises can I track?", "Soleus supports four types of exercises:\n\n• Reps (like push-ups, pull-ups)\n• Weight & Reps (like bench press, squats)\n• Time (like planks, wall sits)\n• Distance (like running, cycling)\n\nEach exercise type has appropriate fields for tracking your performance."),
        ("Exercises & Sets", "How do I add or remove sets?", "When creating or editing a workout, tap 'Add Set' to add more sets to an exercise. During an active workout, you need to enter edit mode first (tap the pencil icon). New sets automatically copy the values from your previous set for convenience.\n\nTo remove a set, swipe left on it and tap delete. In active workouts, sets can only be deleted when in edit mode."),
        ("Exercises & Sets", "Can I add notes to exercises?", "Yes! Enter edit mode (tap the pencil icon) and tap the notebook icon next to any exercise name. An inline text field will appear — type your note and tap Done or tap outside to save. You can use notes to record form cues, personal records, or any reminders. Notes appear below the exercise title and are saved with your workout template."),
        ("Exercises & Sets", "Do sets auto-complete?", "Yes! When you're tracking an active workout, sets will automatically mark as complete when you enter values in both required fields (e.g., reps AND weight). You can also manually check off sets using the slider."),
        ("Rest Timer", "What is the rest timer?", "The rest timer automatically starts counting down after you complete a set, giving you a visual cue for when to start your next set. You can enable or disable it in Settings under Preferences."),
        ("Rest Timer", "Can I adjust the rest timer duration?", "Yes! Go to Settings → Preferences and choose your default rest duration. Options range from 15 seconds up to 5 minutes.\n\nDuring a workout you can also adjust the timer on the fly using the +30s and -30s buttons, or skip it entirely if you're ready to go."),
        ("Achievements & Stats", "How do achievements work?", "Achievements unlock automatically based on your workout activity. Track total weight lifted, reps completed, workout streaks, and more. View all achievements and your progress in the Dashboard tab."),
        ("Achievements & Stats", "What is a workout streak?", "A workout streak counts consecutive days you've completed workouts. Work out every day to build your streak! Your current and longest streaks are shown in the Dashboard."),
        ("Achievements & Stats", "Where can I see my personal records?", "The Dashboard shows your personal records including:\n\n• Heaviest single workout (total weight)\n• Most reps in one workout\n• Longest workout duration\n• Furthest distance in one session"),
        ("Workout History", "How do I view my past workouts?", "Tap the history icon in the top right of the Workouts tab. By default you'll see the current month's workouts. Switch to 'All Time' to see every session you've ever logged."),
        ("Workout History", "Can I see a breakdown of each past workout?", "Yes! Tap 'Show' on any history card to expand it and see a full breakdown of every exercise, including sets, reps, weight, distance, and time."),
        ("Workout History", "What happens to history if I delete a workout?", "Deleting a workout removes the template, but your workout history is preserved. History entries from deleted workouts are shown with a 'deleted' indicator. Your achievements, stats, and personal records all remain intact."),
        ("Data & Privacy", "Is my data synced to the cloud?", "Yes — Soleus uses Apple's CloudKit to automatically sync your workouts, history, and settings across all your devices signed into the same iCloud account.\n\nYour data is stored in your personal iCloud account. Soleus never sees, collects, or has access to your workout data. Everything goes directly between your device and Apple's servers."),
        ("Data & Privacy", "Can Soleus write workouts to Apple Health?", "Yes! Go to Settings → Preferences → Apple Health and enable the toggle. Soleus will ask for permission to write to Apple Health and then record each completed workout — including activity type and distance where applicable — so it shows up in the Fitness app and contributes to your Activity rings.\n\nNo data is read from Apple Health; only completed workouts are written."),
        ("Data & Privacy", "Can I share or import workouts?", "Yes! Long press on any workout card and select 'Share' to export it as a .soleus file. You can send it via AirDrop, Messages, Mail, or save it to Files.\n\nTo import a workout, go to Settings → Utilities and tap 'Import Workout'. You can import:\n\n• A .soleus file shared from another Soleus user\n• A plain .json file from any external source\n\nYou'll see a preview of the workout before it's saved. For iMessage sharing, just tap the link sent to you and Soleus opens automatically.\n\nBuilding your own JSON? See 'How do I format a workout as JSON?' below for the supported structure."),
        ("Importing Workouts", "How do I format a workout as JSON?", "You can import a workout from a plain .json file from any source. Only the fields you need are required — everything else has a sensible default.\n\nA basic example:\n\n{\n  \"name\": \"Push Day\",\n  \"exercises\": [\n    {\n      \"name\": \"Bench Press\",\n      \"quantifier\": \"Reps\",\n      \"measurement\": \"Weight\",\n      \"notes\": \"Keep elbows at 45°\",\n      \"sets\": [\n        { \"reps\": 10, \"weight\": 135.0 },\n        { \"reps\": 8,  \"weight\": 145.0 }\n      ]\n    },\n    {\n      \"name\": \"5K Run\",\n      \"quantifier\": \"Distance\",\n      \"measurement\": \"Time\",\n      \"sets\": [\n        { \"distance\": 5.0, \"time\": 1500 }\n      ]\n    }\n  ]\n}\n\nSave this as a .json file and import it from Settings → Utilities → Import Workout."),
        ("Importing Workouts", "What fields can I use in the JSON?", "Workout fields:\n• name (string, required) — the workout name\n• exercises (array, required) — the list of exercises\n\nExercise fields:\n• name (string, required) — the exercise name\n• quantifier (string) — \"Reps\" or \"Distance\", defaults to \"Reps\"\n• measurement (string) — \"Weight\" or \"Time\", defaults to \"Weight\"\n• notes (string) — an optional text note\n• sets (array) — defaults to 3 empty sets if omitted\n\nSet fields (all optional, default to 0):\n• reps (int) — repetition count\n• weight (float) — weight in your preferred unit\n• time (int) — duration in seconds\n• distance (float) — distance in your preferred unit"),
        ("Customization", "Can I change the app appearance?", "Yes! Go to Settings → Appearance and choose between Dark (default), Light, or System (follows your device setting)."),
        ("Customization", "Can I change my weight and distance units?", "Yes! Go to Settings and choose between lbs/kg for weight and miles/km for distance. Your preference will be used throughout the app."),
        ("Customization", "Can I change workout card colors?", "Absolutely! Long press on the workout card and select 'Customize Card'."),
    ]

    private var filteredItems: [(section: String, question: String, answer: String)] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return allItems }
        let query = searchText.lowercased()
        return allItems.filter {
            $0.question.lowercased().contains(query) || $0.answer.lowercased().contains(query)
        }
    }

    private var filteredSections: [String] {
        var seen = Set<String>()
        return filteredItems.compactMap { seen.insert($0.section).inserted ? $0.section : nil }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Frequently Asked Questions")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Learn how to use Soleus")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    if filteredItems.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("No results for \"\(searchText)\"")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredSections, id: \.self) { section in
                            SectionHeader(title: section)
                            ForEach(filteredItems.filter { $0.section == section }, id: \.question) { item in
                                FAQItem(
                                    question: item.question,
                                    answer: item.answer,
                                    expandedQuestion: $expandedQuestion
                                )
                            }
                        }
                    }

                    Spacer()
                        .frame(height: 20)
                }
                .padding()
            }
            .searchable(text: $searchText, prompt: "Search questions")
            .onChange(of: searchText) {
                expandedQuestion = nil
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Help & FAQ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.myBlue)
            .padding(.top, 8)
    }
}

struct FAQItem: View {
    let question: String
    let answer: String
    @Binding var expandedQuestion: String?

    private var isExpanded: Bool {
        expandedQuestion == question
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedQuestion = isExpanded ? nil : question
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
            }

            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}
