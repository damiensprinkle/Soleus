import Foundation

/// Codable model for exporting/importing workouts as JSON
/// File format: 4-byte magic header "SLSE" followed by UTF-8 JSON.
/// The binary header prevents QuickLook from rendering the file as plain text,
/// so iMessage shows it as a tappable file bubble rather than an inline text preview.
struct ShareableWorkout: Codable, Equatable {
    // Magic bytes that prefix every exported .soleus file
    private static let magic: [UInt8] = [0x53, 0x4C, 0x53, 0x45] // "SLSE"
    // Hard cap on raw import payload size. Legitimate workouts are well under 100 KB
    // even before compression; 5 MB leaves plenty of headroom while bounding the
    // attack surface for zip-bomb-style inputs.
    static let maxImportSize = 5 * 1024 * 1024
    var version: String = "1.0"
    let workoutName: String
    let workoutColor: String?
    let exercises: [ShareableExercise]
    let exportDate: Date

    struct ShareableExercise: Codable, Equatable {
        let name: String
        let orderIndex: Int32
        let quantifier: String // "Reps" or "Distance"
        let measurement: String // "Weight" or "Time"
        let sets: [ShareableSet]
        let notes: String?
    }

    struct ShareableSet: Codable, Equatable {
        let setIndex: Int32
        let reps: Int32
        let weight: Float
        let time: Int32
        let distance: Float
    }

    /// Export workout details to JSON data
    static func export(workoutName: String, workoutColor: String?, workoutDetails: [WorkoutDetailInput]) -> Data? {
        let exercises = workoutDetails.map { detail in
            let sets = detail.sets.map { set in
                ShareableSet(
                    setIndex: set.setIndex,
                    reps: set.reps,
                    weight: set.weight,
                    time: set.time,
                    distance: set.distance
                )
            }

            return ShareableExercise(
                name: detail.exerciseName,
                orderIndex: detail.orderIndex,
                quantifier: detail.exerciseQuantifier,
                measurement: detail.exerciseMeasurement,
                sets: sets,
                notes: detail.notes
            )
        }

        let shareableWorkout = ShareableWorkout(
            workoutName: workoutName,
            workoutColor: workoutColor,
            exercises: exercises,
            exportDate: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // Compact JSON — file has a binary header so human-readability isn't needed,
        // and smaller JSON means shorter base64 URLs when sharing via Messages.

        guard let jsonData = try? encoder.encode(shareableWorkout) else { return nil }

        // Compress the JSON payload. zlib typically halves JSON size, which cuts
        // the base64-encoded iMessage link from ~1500 chars down to ~500-600.
        let payload: Data
        if let compressed = try? (jsonData as NSData).compressed(using: .zlib) {
            payload = compressed as Data
        } else {
            payload = jsonData
        }

        var result = Data(magic)
        result.append(payload)
        return result
    }

    /// Import workout from .soleus or generic .json file data.
    /// Handles compressed (current), uncompressed, legacy raw-JSON, and generic JSON formats.
    static func `import`(from data: Data) -> ShareableWorkout? {
        guard data.count <= maxImportSize else {
            AppLogger.lifecycle.warning("Rejected import: \(data.count) bytes exceeds \(maxImportSize) limit")
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let jsonData: Data
        if data.prefix(magic.count) == Data(magic) {
            let payload = data.dropFirst(magic.count)
            // Try zlib decompression first (current format), fall back to plain JSON.
            if let decompressed = try? (payload as NSData).decompressed(using: .zlib) {
                jsonData = decompressed as Data
            } else {
                jsonData = Data(payload)
            }
        } else {
            // Legacy or generic: raw JSON without magic header
            jsonData = data
        }

        if let native = try? decoder.decode(ShareableWorkout.self, from: jsonData) {
            return native
        }

        // Fall back to the generic JSON format for imports from external sources.
        return (try? decoder.decode(GenericWorkoutJSON.self, from: jsonData))?.toShareableWorkout()
    }

    // MARK: - Generic JSON import

    /// Flexible JSON format for importing workouts from external sources.
    ///
    /// Minimal required structure:
    /// ```json
    /// {
    ///   "name": "Push Day",
    ///   "exercises": [
    ///     {
    ///       "name": "Bench Press",
    ///       "sets": [{ "reps": 10, "weight": 135.0 }]
    ///     }
    ///   ]
    /// }
    /// ```
    /// `quantifier` ("Reps"/"Distance") and `measurement` ("Weight"/"Time") default to
    /// "Reps" and "Weight" when omitted. `sets` defaults to three empty sets.
    /// Set fields (`reps`, `weight`, `time`, `distance`) each default to 0.
    private struct GenericWorkoutJSON: Decodable {
        let name: String
        let exercises: [GenericExercise]

        struct GenericExercise: Decodable {
            let name: String
            let quantifier: String?
            let measurement: String?
            let notes: String?
            let sets: [GenericSet]?

            struct GenericSet: Decodable {
                let reps: Int32?
                let weight: Float?
                let time: Int32?
                let distance: Float?
            }
        }

        func toShareableWorkout() -> ShareableWorkout {
            let shareableExercises = exercises.enumerated().map { index, ex in
                let sets: [ShareableSet]
                if let genericSets = ex.sets, !genericSets.isEmpty {
                    sets = genericSets.enumerated().map { setIndex, s in
                        ShareableSet(
                            setIndex: Int32(setIndex),
                            reps: s.reps ?? 0,
                            weight: s.weight ?? 0,
                            time: s.time ?? 0,
                            distance: s.distance ?? 0
                        )
                    }
                } else {
                    sets = (0..<3).map { ShareableSet(setIndex: Int32($0), reps: 0, weight: 0, time: 0, distance: 0) }
                }
                return ShareableExercise(
                    name: ex.name,
                    orderIndex: Int32(index),
                    quantifier: ex.quantifier ?? "Reps",
                    measurement: ex.measurement ?? "Weight",
                    sets: sets,
                    notes: ex.notes
                )
            }
            return ShareableWorkout(
                workoutName: name,
                workoutColor: nil,
                exercises: shareableExercises,
                exportDate: Date()
            )
        }
    }

    /// Convert to WorkoutDetailInput array for saving.
    /// Per-field caps are enforced here so imports from external sources can't
    /// produce strings longer than the in-app UI is designed to handle.
    func toWorkoutDetails() -> [WorkoutDetailInput] {
        return exercises.map { exercise in
            let setInputs = exercise.sets.map { set in
                SetInput(
                    reps: set.reps,
                    weight: set.weight,
                    time: set.time,
                    distance: set.distance,
                    setIndex: set.setIndex
                )
            }

            return WorkoutDetailInput(
                id: UUID(), // Generate new ID for imported workout
                exerciseId: UUID(), // Generate new exercise ID
                exerciseName: Self.clamp(exercise.name, to: Self.maxNameLength),
                notes: exercise.notes.map { Self.clamp($0, to: Self.maxNotesLength) },
                orderIndex: exercise.orderIndex,
                sets: setInputs,
                exerciseQuantifier: exercise.quantifier,
                exerciseMeasurement: exercise.measurement
            )
        }
    }

    /// Workout name clamped to the same length the in-app editor enforces.
    /// `ImportWorkoutPreviewView` lets the user edit before saving, but the
    /// preview UI also benefits from being handed a sane upper bound.
    var sanitizedWorkoutName: String {
        Self.clamp(workoutName, to: Self.maxNameLength)
    }

    // Matches the 30-char limit enforced by AddWorkoutView/AddExerciseDialog.
    static let maxNameLength = 30
    // Generous cap for exercise notes — enough for form cues, not enough to
    // wedge a list view rendering a multi-MB string.
    static let maxNotesLength = 500

    private static func clamp(_ value: String, to maxLength: Int) -> String {
        value.count <= maxLength ? value : String(value.prefix(maxLength))
    }
}
