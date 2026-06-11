import SwiftUI
import CoreData
import FirebaseCrashlytics

struct SettingsView: View {
    @AppStorage("weightPreference") private var weightPreference: String = "lbs"
    @AppStorage("distancePreference") private var distancePreference: String = "mile"
    @AppStorage("defaultRestDuration") private var defaultRestDuration: Int = 60
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer: Bool = true
    @AppStorage("appearancePreference") private var appearancePreference: String = "system"
    @AppStorage("crashReportingEnabled") private var crashReportingEnabled: Bool = true

    @State private var showingPrivacyPolicy = false
    @State private var showingFAQ = false
    @State private var showingContactUs = false
    @State private var showingDevMenu = false

    @State private var showDocumentPicker = false
    @State private var importedWorkout: ShareableWorkout?
    @State private var showImportPreview = false

    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "name == %@", "Soleus Developer"),
        animation: .none
    )
    private var developerWorkouts: FetchedResults<Workouts>

    private var isDeveloperModeEnabled: Bool { !developerWorkouts.isEmpty }

    private let restDurationOptions = [15, 30, 45, 60, 90, 120, 180, 240, 300]

    var body: some View {
        NavigationStack {
        Form {
            Section(
                header: Text("Utilities"),
                footer: Text("Import a .soleus file shared from another device, or a plain .json file from any source. For iMessage sharing, tap the link sent to you. Need more help? See Help & FAQ below.")
            ) {
                Button(action: {
                    importedWorkout = nil
                    showImportPreview = false
                    showDocumentPicker = true
                }) {
                    HStack {
                        Label("Import Workout", systemImage: "square.and.arrow.down")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.settingsImportButton)
            }

            Section(
                header: Text("Preferences"),
                footer: Text("Rest timer automatically starts when you complete a set. Adjust time with +/-30s buttons or skip entirely.")
            ) {
                NavigationLink(destination: NotificationsSettingsView()) {
                    Text("Notifications")
                }

                NavigationLink(destination: HealthKitSettingsView()) {
                    Text("Apple Health")
                }
                .accessibilityIdentifier(AccessibilityID.settingsHealthKitButton)

                Picker("Appearance", selection: $appearancePreference) {
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                    Text("System").tag("system")
                }

                Picker("Weight Preference", selection: $weightPreference) {
                    Text("lbs").tag("lbs")
                    Text("kg").tag("kg")
                }
                .accessibilityIdentifier(AccessibilityID.settingsWeightPicker)

                Picker("Distance Preference", selection: $distancePreference) {
                    Text("mile").tag("mile")
                    Text("km").tag("km")
                }
                .accessibilityIdentifier(AccessibilityID.settingsDistancePicker)

                Toggle("Auto-Start Rest Timer", isOn: $autoStartRestTimer)
                    .tint(.green)
                    .accessibilityIdentifier(AccessibilityID.settingsRestTimerToggle)

                if autoStartRestTimer {
                    Picker("Default Rest Duration", selection: $defaultRestDuration) {
                        ForEach(restDurationOptions, id: \.self) { seconds in
                            Text(formatRestDuration(seconds)).tag(seconds)
                        }
                    }
                }
            }

            Section(
                header: Text("Privacy"),
                footer: Text("Anonymous crash reports help fix bugs. Your workout names and notes are stripped from any data before it leaves your device.")
            ) {
                Toggle("Crash Reports", isOn: $crashReportingEnabled)
                    .tint(.green)
                    .onChange(of: crashReportingEnabled) { _, newValue in
                        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(newValue)
                    }
            }

            Section(header: Text("About")) {
                Button(action: {
                    showingFAQ = true
                }) {
                    HStack {
                        Label("Help & FAQ", systemImage: "questionmark.circle.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.settingsHelpButton)

                Button(action: {
                    showingPrivacyPolicy = true
                }) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.settingsPrivacyButton)

                Button(action: {
                    showingContactUs = true
                }) {
                    HStack {
                        Label("Contact Us", systemImage: "envelope.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.settingsContactUsButton)

                if isDeveloperModeEnabled {
                    Button(action: {
                        showingDevMenu = true
                    }) {
                        HStack {
                            Label("Developer Menu", systemImage: "hammer.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .background(Color.myWhite)
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(importedWorkout: $importedWorkout, showImportPreview: .constant(false))
        }
        .onChange(of: importedWorkout) { _, newValue in
            if newValue != nil, !showDocumentPicker {
                showImportPreview = true
            }
        }
        .sheet(isPresented: $showImportPreview, onDismiss: {
            importedWorkout = nil
        }) {
            ImportWorkoutPreviewContent(
                importedWorkout: $importedWorkout,
                showImportPreview: $showImportPreview
            )
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showingFAQ) {
            FAQView()
        }
        .sheet(isPresented: $showingContactUs) {
            ContactUsView()
        }
        .sheet(isPresented: $showingDevMenu) {
            DevMenuView()
        }
        } // NavigationStack
    }

    private func formatRestDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes)m \(remainingSeconds)s"
            } else {
                return "\(minutes) minute\(minutes == 1 ? "" : "s")"
            }
        } else {
            return "\(seconds) seconds"
        }
    }

    private func formatRestDurationShort(_ seconds: Int) -> String {
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds > 0 {
                return "\(minutes):\(String(format: "%02d", remainingSeconds))"
            } else {
                return "\(minutes)min"
            }
        } else {
            return "\(seconds)s"
        }
    }
}
