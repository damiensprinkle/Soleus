import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Privacy")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Last updated: June 2026")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // What Stays on Your Device
                    PrivacySection(
                        icon: "lock.shield.fill",
                        iconColor: .green,
                        title: "Your Workouts Stay With You",
                        description: "Workouts, exercises, sets, notes, history, and preferences live on your device. The developer never sees them."
                    )

                    // iCloud Sync
                    PrivacySection(
                        icon: "icloud.fill",
                        iconColor: .blue,
                        title: "iCloud Sync",
                        description: "If you're signed into iCloud, Soleus uses Apple's CloudKit to sync your workouts across your own devices. The data lives in your private iCloud account — we don't have access to it. You can disable sync any time in iOS Settings → Apple ID → iCloud → Soleus."
                    )

                    // Apple Health
                    PrivacySection(
                        icon: "heart.fill",
                        iconColor: .red,
                        title: "Apple Health",
                        description: "With your permission, Soleus writes completed workouts to Apple Health so they appear in the Fitness app. You can revoke this any time in Settings. Nothing is read or written without your consent."
                    )

                    // Crash Reports
                    PrivacySection(
                        icon: "ladybug.fill",
                        iconColor: .orange,
                        title: "Crash Reports",
                        description: "When the app crashes, an anonymous report is sent to Google Firebase Crashlytics so the developer can fix the bug. Reports include the crash itself plus diagnostic logs. Your workout names, exercise names, and notes are stripped from these logs before they leave your device. No location data, no identifiers beyond an anonymous install ID."
                    )

                    // No Analytics, No Ads, No Tracking
                    PrivacySection(
                        icon: "eye.slash.fill",
                        iconColor: .purple,
                        title: "No Analytics, No Ads, No Tracking",
                        description: "Soleus does not include analytics SDKs, advertising networks, or behavioral tracking. The developer doesn't know what you do with the app — only that it crashed, if it ever does."
                    )

                    // Bug Reports
                    PrivacySection(
                        icon: "envelope.fill",
                        iconColor: .secondary,
                        title: "Bug Reports You Send",
                        description: "When you tap Contact Us and file a bug report, you can attach a log file. User-entered content (workout names, exercise names, notes) is scrubbed from the attachment before it's added to the email. You can also review and edit the email before sending."
                    )

                    // Your Control
                    PrivacySection(
                        icon: "hand.raised.fill",
                        iconColor: .myBlue,
                        title: "Your Data, Your Control",
                        description: "Delete the app to remove local data. Disable iCloud sync in iOS Settings to keep everything on a single device. Revoke Apple Health access in Settings any time. Your workouts are yours."
                    )

                    Divider()

                    // Footer
                    VStack(spacing: 12) {
                        Text("Simple, Honest, Transparent")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("No app account. No analytics. No ads. Crash reports only when something breaks — with your workout content stripped out first.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)

                    Spacer()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Privacy Policy")
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

struct PrivacySection: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
