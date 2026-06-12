import Foundation
import CoreData

/// Manages the persistent exercise library (ExerciseTemplate entities):
/// seeding the built-in catalog, CRUD from the My Exercises screen, and
/// automatic capture of exercise names used in workout plans.
class ExerciseLibraryManager: ObservableObject {
    var context: NSManagedObjectContext? {
        didSet {
            if context != nil {
                AppLogger.coreData.info("Context set in ExerciseLibraryManager")
            }
        }
    }

    static let categories = ["Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio", "Other"]

    private static let hasSeededKey = "hasSeededExerciseLibrary"

    // MARK: - Fetching

    /// All templates, most-used first, then alphabetical.
    func fetchAll() -> [ExerciseTemplate] {
        guard let context = self.context else { return [] }
        let request: NSFetchRequest<ExerciseTemplate> = ExerciseTemplate.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "usageCount", ascending: false),
            NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        do {
            return try context.fetch(request)
        } catch {
            AppLogger.coreData.error("Failed to fetch exercise templates: \(error.localizedDescription)")
            return []
        }
    }

    func fetchTemplate(named name: String) -> ExerciseTemplate? {
        guard let context = self.context else { return nil }
        let request: NSFetchRequest<ExerciseTemplate> = ExerciseTemplate.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first
        } catch {
            AppLogger.coreData.error("Failed to fetch exercise template by name: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - CRUD

    /// Creates a new template. Returns false if a template with the same name
    /// (case-insensitive) already exists.
    @discardableResult
    func createExercise(name: String, description: String?, category: String, quantifier: String, measurement: String, isCustom: Bool = true) -> Bool {
        guard let context = self.context else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard fetchTemplate(named: trimmed) == nil else {
            AppLogger.coreData.debug("Exercise template already exists, skipping create")
            return false
        }

        let template = ExerciseTemplate(context: context)
        template.id = UUID()
        template.name = trimmed
        template.descriptionText = description
        template.category = category
        template.defaultQuantifier = quantifier
        template.defaultMeasurement = measurement
        template.usageCount = 0
        template.isCustom = isCustom

        saveContext()
        return true
    }

    /// Updates an existing template. Returns false if renaming would collide
    /// with another template's name.
    @discardableResult
    func updateExercise(_ template: ExerciseTemplate, name: String, description: String?, category: String, quantifier: String, measurement: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if let existing = fetchTemplate(named: trimmed), existing != template {
            return false
        }

        template.name = trimmed
        template.descriptionText = description
        template.category = category
        template.defaultQuantifier = quantifier
        template.defaultMeasurement = measurement

        saveContext()
        return true
    }

    func deleteExercise(_ template: ExerciseTemplate) {
        guard let context = self.context else { return }
        context.delete(template)
        saveContext()
    }

    // MARK: - Usage Tracking

    /// Called when an exercise is added to a workout plan. Bumps the usage
    /// count, auto-creating a custom template the first time a new name is
    /// used so the library remembers it.
    func recordUsage(name: String, quantifier: String, measurement: String) {
        guard context != nil else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let template = fetchTemplate(named: trimmed) {
            template.usageCount += 1
            saveContext()
        } else {
            createExercise(
                name: trimmed,
                description: nil,
                category: "Other",
                quantifier: quantifier,
                measurement: measurement
            )
            fetchTemplate(named: trimmed)?.usageCount = 1
            saveContext()
        }
    }

    // MARK: - Seeding

    /// Populates the built-in catalog exactly once. Guarded by a UserDefaults
    /// flag (not an emptiness check) so a user who deletes everything from
    /// My Exercises is not re-seeded on next launch.
    func seedDefaultLibraryIfNeeded() {
        guard let context = self.context else { return }
        guard !UserDefaults.standard.bool(forKey: Self.hasSeededKey) else { return }

        for seed in Self.defaultLibrary {
            // Skip names that already exist (e.g. captured from a workout plan
            // created before the library feature shipped).
            if fetchTemplate(named: seed.name) != nil { continue }
            let template = ExerciseTemplate(context: context)
            template.id = UUID()
            template.name = seed.name
            template.descriptionText = seed.description
            template.category = seed.category
            template.defaultQuantifier = seed.quantifier
            template.defaultMeasurement = seed.measurement
            template.usageCount = 0
            template.isCustom = false
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: Self.hasSeededKey)
            AppLogger.coreData.info("Seeded exercise library with \(Self.defaultLibrary.count) exercises")
        } catch {
            AppLogger.coreData.error("Failed to seed exercise library: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func saveContext() {
        guard let context = self.context, context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            AppLogger.coreData.error("Failed to save exercise library change: \(error.localizedDescription)")
        }
    }
}

// MARK: - Default Library

extension ExerciseLibraryManager {

    struct SeedExercise {
        let name: String
        let category: String
        let description: String
        let quantifier: String   // "Reps" or "Distance"
        let measurement: String  // "Weight" or "Time"
    }

    static let defaultLibrary: [SeedExercise] = [
        // Chest
        SeedExercise(name: "Bench Press", category: "Chest", description: "Barbell press from the chest while lying on a flat bench.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Incline Bench Press", category: "Chest", description: "Barbell press on an inclined bench, emphasizing the upper chest.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Dumbbell Bench Press", category: "Chest", description: "Flat bench press with dumbbells for a greater range of motion.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Incline Dumbbell Press", category: "Chest", description: "Dumbbell press on an inclined bench for the upper chest.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Chest Fly", category: "Chest", description: "Arms sweep together in an arc with dumbbells or a machine.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Cable Crossover", category: "Chest", description: "Cables pulled together across the chest from high pulleys.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Push-Up", category: "Chest", description: "Bodyweight press from the floor in a plank position.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Dips", category: "Chest", description: "Bodyweight press on parallel bars, leaning forward for chest.", quantifier: "Reps", measurement: "Weight"),

        // Back
        SeedExercise(name: "Deadlift", category: "Back", description: "Barbell lifted from the floor to a standing lockout.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Pull-Up", category: "Back", description: "Bodyweight pull to the bar with an overhand grip.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Chin-Up", category: "Back", description: "Bodyweight pull to the bar with an underhand grip.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Lat Pulldown", category: "Back", description: "Cable bar pulled down to the chest from overhead.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Barbell Row", category: "Back", description: "Barbell rowed to the torso from a hinged position.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Dumbbell Row", category: "Back", description: "One-arm dumbbell row, usually supported on a bench.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Seated Cable Row", category: "Back", description: "Cable handle rowed to the torso while seated.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Back Extension", category: "Back", description: "Torso raised against gravity on a hyperextension bench.", quantifier: "Reps", measurement: "Weight"),

        // Shoulders
        SeedExercise(name: "Overhead Press", category: "Shoulders", description: "Barbell pressed overhead from the shoulders while standing.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Dumbbell Shoulder Press", category: "Shoulders", description: "Dumbbells pressed overhead, seated or standing.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Lateral Raise", category: "Shoulders", description: "Dumbbells raised out to the sides to shoulder height.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Front Raise", category: "Shoulders", description: "Dumbbells raised forward to shoulder height.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Rear Delt Fly", category: "Shoulders", description: "Bent-over reverse fly targeting the rear shoulders.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Face Pull", category: "Shoulders", description: "Rope pulled toward the face from a high cable.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Shrug", category: "Shoulders", description: "Shoulders raised straight up holding heavy weight.", quantifier: "Reps", measurement: "Weight"),

        // Arms
        SeedExercise(name: "Barbell Curl", category: "Arms", description: "Barbell curled from the thighs to the shoulders.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Dumbbell Curl", category: "Arms", description: "Alternating or simultaneous dumbbell curls.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Hammer Curl", category: "Arms", description: "Dumbbell curl with a neutral (thumbs-up) grip.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Preacher Curl", category: "Arms", description: "Curl with upper arms braced on a preacher bench.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Tricep Pushdown", category: "Arms", description: "Cable pressed down by extending the elbows.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Overhead Tricep Extension", category: "Arms", description: "Weight lowered behind the head and extended overhead.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Skull Crusher", category: "Arms", description: "Lying tricep extension lowering the bar to the forehead.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Close-Grip Bench Press", category: "Arms", description: "Bench press with a narrow grip to emphasize triceps.", quantifier: "Reps", measurement: "Weight"),

        // Legs
        SeedExercise(name: "Squat", category: "Legs", description: "Barbell back squat to at least parallel depth.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Front Squat", category: "Legs", description: "Squat with the barbell racked across the front shoulders.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Leg Press", category: "Legs", description: "Weight sled pressed away on a leg press machine.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Lunge", category: "Legs", description: "Step forward and lower until both knees reach 90 degrees.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Bulgarian Split Squat", category: "Legs", description: "Single-leg squat with the rear foot elevated on a bench.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Romanian Deadlift", category: "Legs", description: "Hip hinge with a slight knee bend targeting the hamstrings.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Leg Extension", category: "Legs", description: "Knees extended against a machine pad to work the quads.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Leg Curl", category: "Legs", description: "Heels curled toward the glutes on a machine.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Hip Thrust", category: "Legs", description: "Hips driven up with the upper back on a bench, bar across the hips.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Calf Raise", category: "Legs", description: "Heels raised onto the toes, standing or seated.", quantifier: "Reps", measurement: "Weight"),

        // Core
        SeedExercise(name: "Plank", category: "Core", description: "Hold a straight line from head to heels on the forearms.", quantifier: "Reps", measurement: "Time"),
        SeedExercise(name: "Side Plank", category: "Core", description: "Hold a straight line balanced on one forearm.", quantifier: "Reps", measurement: "Time"),
        SeedExercise(name: "Crunch", category: "Core", description: "Shoulders curled toward the hips from the floor.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Sit-Up", category: "Core", description: "Full torso raise from the floor to upright.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Russian Twist", category: "Core", description: "Seated torso rotation side to side, feet elevated.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Hanging Leg Raise", category: "Core", description: "Legs raised to horizontal while hanging from a bar.", quantifier: "Reps", measurement: "Weight"),
        SeedExercise(name: "Ab Wheel Rollout", category: "Core", description: "Roll the wheel forward and back while keeping the core braced.", quantifier: "Reps", measurement: "Weight"),

        // Cardio
        SeedExercise(name: "Running", category: "Cardio", description: "Outdoor or treadmill run.", quantifier: "Distance", measurement: "Time"),
        SeedExercise(name: "Walking", category: "Cardio", description: "Brisk walk, outdoors or on a treadmill.", quantifier: "Distance", measurement: "Time"),
        SeedExercise(name: "Cycling", category: "Cardio", description: "Road, trail, or stationary bike ride.", quantifier: "Distance", measurement: "Time"),
        SeedExercise(name: "Rowing", category: "Cardio", description: "Rowing machine intervals or steady state.", quantifier: "Distance", measurement: "Time"),
        SeedExercise(name: "Swimming", category: "Cardio", description: "Lap swimming, any stroke.", quantifier: "Distance", measurement: "Time"),
        SeedExercise(name: "Stair Climber", category: "Cardio", description: "Steady climbing on a stair machine.", quantifier: "Reps", measurement: "Time"),
        SeedExercise(name: "Jump Rope", category: "Cardio", description: "Continuous rope skipping.", quantifier: "Reps", measurement: "Time")
    ]
}
