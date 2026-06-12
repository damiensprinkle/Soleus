import SwiftUI

/// Sheet for toggling dashboard widgets on/off and dragging them into a
/// custom order. Edits write straight back to the binding; the dashboard
/// owner persists changes.
struct DashboardCustomizeView: View {
    @Binding var settings: [DashboardWidgetSetting]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(footer: Text("Toggle widgets to show or hide them, and drag to reorder. Changes are saved automatically.")) {
                    ForEach($settings) { $setting in
                        HStack(spacing: 12) {
                            Image(systemName: setting.widget.icon)
                                .font(.body)
                                .foregroundColor(.myBlue)
                                .frame(width: 28)

                            Toggle(setting.widget.displayName, isOn: $setting.isVisible)
                                .accessibilityIdentifier("widget_toggle_\(setting.widget.rawValue)")
                        }
                    }
                    .onMove { source, destination in
                        settings.move(fromOffsets: source, toOffset: destination)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            }
            .accessibilityIdentifier(AccessibilityID.dashboardCustomizeDoneButton))
        }
    }
}
