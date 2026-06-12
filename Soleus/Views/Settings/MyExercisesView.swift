import SwiftUI

/// Settings screen for managing the persistent exercise library:
/// create, rename/edit, and delete exercises.
struct MyExercisesView: View {
    @EnvironmentObject var exerciseLibrary: ExerciseLibraryManager
    @State private var templates: [ExerciseTemplate] = []
    @State private var searchText: String = ""
    @State private var editingTemplate: ExerciseTemplate?
    @State private var showingCreateSheet = false
    @AppStorage("myExercisesSortOrder") private var sortOrder: String = SortOrder.category.rawValue

    enum SortOrder: String, CaseIterable {
        case category = "By Category"
        case alphabetical = "A to Z"

        var icon: String {
            switch self {
            case .category: return "square.grid.2x2"
            case .alphabetical: return "textformat.abc"
            }
        }
    }

    private var currentSort: SortOrder {
        SortOrder(rawValue: sortOrder) ?? .category
    }

    private var filteredTemplates: [ExerciseTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return templates }
        return templates.filter { ($0.name ?? "").localizedCaseInsensitiveContains(query) }
    }

    private var alphabeticalTemplates: [ExerciseTemplate] {
        filteredTemplates.sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }

    /// Categories that have at least one (filtered) exercise, canonical order.
    private var sections: [(category: String, templates: [ExerciseTemplate])] {
        ExerciseLibraryManager.categories.compactMap { category in
            let matches = filteredTemplates
                .filter { ($0.category ?? "Other") == category }
                .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
            return matches.isEmpty ? nil : (category, matches)
        }
    }

    var body: some View {
        List {
            if templates.isEmpty {
                Section {
                    Text("Your exercise library is empty. Exercises you add to workout plans appear here automatically, or create one with the + button.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if currentSort == .alphabetical {
                Section {
                    ForEach(alphabeticalTemplates) { template in
                        Button(action: { editingTemplate = template }) {
                            templateRow(template, showCategory: true)
                        }
                        .foregroundColor(.primary)
                    }
                    .onDelete { offsets in
                        deleteTemplates(at: offsets, in: alphabeticalTemplates)
                    }
                }
            } else {
                ForEach(sections, id: \.category) { section in
                    Section(header: Text(section.category)) {
                        ForEach(section.templates) { template in
                            Button(action: { editingTemplate = template }) {
                                templateRow(template)
                            }
                            .foregroundColor(.primary)
                        }
                        .onDelete { offsets in
                            deleteTemplates(at: offsets, in: section.templates)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("My Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(SortOrder.allCases, id: \.rawValue) { order in
                        Button(action: { sortOrder = order.rawValue }) {
                            if currentSort == order {
                                Label(order.rawValue, systemImage: "checkmark")
                            } else {
                                Label(order.rawValue, systemImage: order.icon)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityIdentifier(AccessibilityID.myExercisesSortButton)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier(AccessibilityID.myExercisesAddButton)
            }
        }
        .sheet(item: $editingTemplate) { template in
            ExerciseEditSheet(template: template) {
                reload()
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            ExerciseEditSheet(template: nil) {
                reload()
            }
        }
        .onAppear { reload() }
    }

    private func templateRow(_ template: ExerciseTemplate, showCategory: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(template.name ?? "Unknown")
                    .font(.body)
                if showCategory, let category = template.category {
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.myBlue)
                }
                if let description = template.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if template.usageCount > 0 {
                Text("Used \(template.usageCount)×")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func deleteTemplates(at offsets: IndexSet, in sectionTemplates: [ExerciseTemplate]) {
        for index in offsets {
            exerciseLibrary.deleteExercise(sectionTemplates[index])
        }
        reload()
    }

    private func reload() {
        templates = exerciseLibrary.fetchAll()
    }
}

// MARK: - Create / Edit Sheet

struct ExerciseEditSheet: View {
    /// nil = creating a new exercise
    let template: ExerciseTemplate?
    let onSave: () -> Void

    @EnvironmentObject var exerciseLibrary: ExerciseLibraryManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var descriptionText: String = ""
    @State private var category: String = "Other"
    @State private var quantifier: String = "Reps"
    @State private var measurement: String = "Weight"
    @State private var showDuplicateAlert = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("e.g., Bench Press", text: $name)
                        .accessibilityIdentifier(AccessibilityID.myExercisesNameField)
                        .onChange(of: name) {
                            if name.count > 30 {
                                name = String(name.prefix(30))
                            }
                        }
                }

                Section(header: Text("Description")) {
                    TextField("Optional short description", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(ExerciseLibraryManager.categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section(
                    header: Text("Defaults"),
                    footer: Text("Pre-filled when you add this exercise to a workout plan.")
                ) {
                    Picker("Track By", selection: $quantifier) {
                        Text("Reps").tag("Reps")
                        Text("Distance").tag("Distance")
                    }
                    .pickerStyle(.segmented)

                    Picker("Measure With", selection: $measurement) {
                        Text("Weight").tag("Weight")
                        Text("Time").tag("Time")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(template == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .accessibilityIdentifier(AccessibilityID.myExercisesSaveButton)
                }
            }
            .alert("Name Already Exists", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Another exercise in your library already has this name.")
            }
            .onAppear {
                if let template = template {
                    name = template.name ?? ""
                    descriptionText = template.descriptionText ?? ""
                    category = template.category ?? "Other"
                    quantifier = template.defaultQuantifier ?? "Reps"
                    measurement = template.defaultMeasurement ?? "Weight"
                }
            }
        }
    }

    private func save() {
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = trimmedDescription.isEmpty ? nil : trimmedDescription

        let success: Bool
        if let template = template {
            success = exerciseLibrary.updateExercise(
                template,
                name: name,
                description: description,
                category: category,
                quantifier: quantifier,
                measurement: measurement
            )
        } else {
            success = exerciseLibrary.createExercise(
                name: name,
                description: description,
                category: category,
                quantifier: quantifier,
                measurement: measurement
            )
        }

        if success {
            onSave()
            dismiss()
        } else {
            showDuplicateAlert = true
        }
    }
}
