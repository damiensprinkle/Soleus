import SwiftUI

/// Searchable, category-filterable sheet over the exercise library.
/// Selecting an exercise hands its template back to the caller; "Create
/// Custom" falls through to the free-form AddExerciseDialog.
struct ExercisePickerView: View {
    @EnvironmentObject var exerciseLibrary: ExerciseLibraryManager
    @Binding var isPresented: Bool
    let onSelect: (ExerciseTemplate) -> Void
    let onCreateCustom: () -> Void

    @State private var templates: [ExerciseTemplate] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil

    private var filteredTemplates: [ExerciseTemplate] {
        var result = templates
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { ($0.name ?? "").localizedCaseInsensitiveContains(query) }
        }
        return result
    }

    /// Categories that actually have exercises, in canonical order.
    private var availableCategories: [String] {
        let present = Set(templates.compactMap { $0.category })
        return ExerciseLibraryManager.categories.filter { present.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Exercise")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .accessibilityIdentifier(AccessibilityID.exercisePickerCloseButton)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("Search exercises", text: $searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .accessibilityIdentifier(AccessibilityID.exercisePickerSearchField)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(label: "All", isSelected: selectedCategory == nil) {
                        selectedCategory = nil
                    }
                    ForEach(availableCategories, id: \.self) { category in
                        categoryChip(label: category, isSelected: selectedCategory == category) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 10)

            Divider()

            // Exercise list
            if filteredTemplates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(searchText.isEmpty ? "No exercises in your library yet." : "No exercises match \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredTemplates) { template in
                            exerciseRow(template)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            // Create Custom
            VStack(spacing: 0) {
                Divider()
                Button(action: {
                    onCreateCustom()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("Create Custom Exercise")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.myBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.myBlue.opacity(0.1))
                    .cornerRadius(12)
                }
                .accessibilityIdentifier(AccessibilityID.exercisePickerCreateCustomButton)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            templates = exerciseLibrary.fetchAll()
        }
    }

    private func categoryChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? Color.myBlue : Color(.secondarySystemGroupedBackground))
                )
        }
        .buttonStyle(.plain)
    }

    private func exerciseRow(_ template: ExerciseTemplate) -> some View {
        Button(action: {
            onSelect(template)
            isPresented = false
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    if let description = template.descriptionText, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        if let category = template.category {
                            Text(category)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.myBlue.opacity(0.12)))
                                .foregroundColor(.myBlue)
                        }
                        Label(template.defaultQuantifier ?? "Reps", systemImage: template.defaultQuantifier == "Distance" ? "figure.outdoor.cycle" : "repeat")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Label(template.defaultMeasurement ?? "Weight", systemImage: template.defaultMeasurement == "Time" ? "timer" : "scalemass.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if template.usageCount > 0 {
                    Text("\(template.usageCount)×")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.myBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.myBlue.opacity(0.1))
                        .cornerRadius(6)
                }

                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundColor(.myBlue)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
