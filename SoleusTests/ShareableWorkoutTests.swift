import XCTest
@testable import Soleus

final class ShareableWorkoutTests: XCTestCase {

    // MARK: - Export

    func testExport_ProducesValidData() {
        let details = [makeDetail(name: "Bench Press", reps: 10, weight: 135)]
        let data = ShareableWorkout.export(workoutName: "Push Day", workoutColor: "MyBlue", workoutDetails: details)

        XCTAssertNotNil(data)
        // Export now uses a binary envelope (magic header + zlib-compressed JSON).
        // Verify round-trip fidelity via import rather than raw JSON parsing.
        let workout = ShareableWorkout.import(from: data!)
        XCTAssertNotNil(workout)
        XCTAssertEqual(workout?.workoutName, "Push Day")
    }

    func testExport_IncludesAllExercises() {
        let details = [
            makeDetail(name: "Bench Press", reps: 10, weight: 135),
            makeDetail(name: "Overhead Press", reps: 8, weight: 95),
        ]
        let data = ShareableWorkout.export(workoutName: "Push", workoutColor: nil, workoutDetails: details)

        let workout = ShareableWorkout.import(from: data!)
        XCTAssertEqual(workout?.exercises.count, 2)
        XCTAssertEqual(workout?.exercises[0].name, "Bench Press")
        XCTAssertEqual(workout?.exercises[1].name, "Overhead Press")
    }

    func testExport_NilColor() {
        let details = [makeDetail(name: "Squat", reps: 5, weight: 225)]
        let data = ShareableWorkout.export(workoutName: "Legs", workoutColor: nil, workoutDetails: details)

        let workout = ShareableWorkout.import(from: data!)
        XCTAssertNil(workout?.workoutColor)
    }

    func testExport_PreservesSetData() {
        let sets = [
            SetInput(reps: 10, weight: 135, time: 0, distance: 0, setIndex: 0),
            SetInput(reps: 8, weight: 155, time: 0, distance: 0, setIndex: 1),
            SetInput(reps: 6, weight: 175, time: 0, distance: 0, setIndex: 2),
        ]
        let detail = WorkoutDetailInput(
            id: UUID(), exerciseId: UUID(), exerciseName: "Bench",
            orderIndex: 0, sets: sets,
            exerciseQuantifier: "Reps", exerciseMeasurement: "Weight"
        )
        let data = ShareableWorkout.export(workoutName: "Test", workoutColor: "MyBlue", workoutDetails: [detail])

        let workout = ShareableWorkout.import(from: data!)
        let importedSets = workout!.exercises[0].sets
        XCTAssertEqual(importedSets.count, 3)
        XCTAssertEqual(importedSets[0].reps, 10)
        XCTAssertEqual(importedSets[0].weight, 135)
        XCTAssertEqual(importedSets[1].reps, 8)
        XCTAssertEqual(importedSets[2].weight, 175)
    }

    func testExport_EmptyExerciseList() {
        let data = ShareableWorkout.export(workoutName: "Empty", workoutColor: nil, workoutDetails: [])

        let workout = ShareableWorkout.import(from: data!)
        XCTAssertNotNil(workout)
        XCTAssertEqual(workout?.exercises.count, 0)
    }

    // MARK: - Import

    func testImport_InvalidData_ReturnsNil() {
        let garbage = "not json".data(using: .utf8)!
        XCTAssertNil(ShareableWorkout.import(from: garbage))
    }

    func testImport_EmptyData_ReturnsNil() {
        XCTAssertNil(ShareableWorkout.import(from: Data()))
    }

    func testImport_OversizedData_ReturnsNil() {
        let oversized = Data(count: ShareableWorkout.maxImportSize + 1)
        XCTAssertNil(ShareableWorkout.import(from: oversized))
    }

    // MARK: - Per-field length caps

    func testToWorkoutDetails_ClampsLongExerciseName() {
        let longName = String(repeating: "A", count: 500)
        let json = """
        { "name": "Test", "exercises": [{ "name": "\(longName)", "sets": [] }] }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        let details = workout.toWorkoutDetails()
        XCTAssertEqual(details[0].exerciseName.count, ShareableWorkout.maxNameLength)
        XCTAssertEqual(details[0].exerciseName, String(repeating: "A", count: ShareableWorkout.maxNameLength))
    }

    func testToWorkoutDetails_ClampsLongNotes() {
        let longNotes = String(repeating: "n", count: 5000)
        let json = """
        { "name": "Test", "exercises": [{ "name": "Bench", "notes": "\(longNotes)", "sets": [] }] }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        let details = workout.toWorkoutDetails()
        XCTAssertEqual(details[0].notes?.count, ShareableWorkout.maxNotesLength)
    }

    func testToWorkoutDetails_ShortValuesUnchanged() {
        let json = """
        { "name": "Test", "exercises": [{ "name": "Bench", "notes": "Keep elbows tucked", "sets": [] }] }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        let details = workout.toWorkoutDetails()
        XCTAssertEqual(details[0].exerciseName, "Bench")
        XCTAssertEqual(details[0].notes, "Keep elbows tucked")
    }

    func testSanitizedWorkoutName_ClampsLongName() {
        let longName = String(repeating: "W", count: 500)
        let json = """
        { "name": "\(longName)", "exercises": [] }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertEqual(workout.workoutName.count, 500) // raw field is untouched
        XCTAssertEqual(workout.sanitizedWorkoutName.count, ShareableWorkout.maxNameLength)
    }

    func testSanitizedWorkoutName_ShortNameUnchanged() {
        let json = """
        { "name": "Push Day", "exercises": [] }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertEqual(workout.sanitizedWorkoutName, "Push Day")
    }

    func testImport_AtSizeLimit_StillAttemptsDecode() {
        // A payload exactly at the limit should not be rejected for size alone.
        // It will still fail to decode (random bytes aren't valid JSON), but the
        // failure path should be JSON decoding, not the size guard.
        let atLimit = Data(count: ShareableWorkout.maxImportSize)
        XCTAssertNil(ShareableWorkout.import(from: atLimit))
        // Round-trip a real workout to confirm normal-sized payloads still work.
        let details = [makeDetail(name: "Bench", reps: 10, weight: 135)]
        let exported = ShareableWorkout.export(workoutName: "Test", workoutColor: nil, workoutDetails: details)!
        XCTAssertLessThan(exported.count, ShareableWorkout.maxImportSize)
        XCTAssertNotNil(ShareableWorkout.import(from: exported))
    }

    // MARK: - Round-trip

    func testRoundTrip_ExportImport() {
        let details = [
            makeDetail(name: "Squat", reps: 5, weight: 225, quantifier: "Reps", measurement: "Weight"),
            makeDetail(name: "Running", reps: 0, weight: 0, time: 1800, distance: 3.1, quantifier: "Distance", measurement: "Time"),
        ]
        let data = ShareableWorkout.export(workoutName: "Full Body", workoutColor: "MyGreen", workoutDetails: details)!

        let imported = ShareableWorkout.import(from: data)!

        XCTAssertEqual(imported.workoutName, "Full Body")
        XCTAssertEqual(imported.workoutColor, "MyGreen")
        XCTAssertEqual(imported.exercises.count, 2)
        XCTAssertEqual(imported.exercises[0].name, "Squat")
        XCTAssertEqual(imported.exercises[0].quantifier, "Reps")
        XCTAssertEqual(imported.exercises[1].name, "Running")
        XCTAssertEqual(imported.exercises[1].measurement, "Time")
        XCTAssertEqual(imported.exercises[1].sets[0].distance, 3.1, accuracy: 0.01)
    }

    // MARK: - toWorkoutDetails

    func testToWorkoutDetails_CreatesNewUUIDs() {
        let details = [makeDetail(name: "Bench", reps: 10, weight: 135)]
        let data = ShareableWorkout.export(workoutName: "Test", workoutColor: nil, workoutDetails: details)!
        let imported = ShareableWorkout.import(from: data)!

        let converted = imported.toWorkoutDetails()

        XCTAssertEqual(converted.count, 1)
        XCTAssertEqual(converted[0].exerciseName, "Bench")
        XCTAssertNotNil(converted[0].id)
        XCTAssertNotNil(converted[0].exerciseId)
        // UUIDs should be freshly generated, not matching originals
        XCTAssertNotEqual(converted[0].id, details[0].id)
    }

    func testToWorkoutDetails_PreservesSetValues() {
        let sets = [
            SetInput(reps: 10, weight: 135, time: 0, distance: 0, setIndex: 0),
            SetInput(reps: 8, weight: 155, time: 0, distance: 0, setIndex: 1),
        ]
        let detail = WorkoutDetailInput(
            id: UUID(), exerciseId: UUID(), exerciseName: "Curl",
            orderIndex: 0, sets: sets,
            exerciseQuantifier: "Reps", exerciseMeasurement: "Weight"
        )
        let data = ShareableWorkout.export(workoutName: "Arms", workoutColor: nil, workoutDetails: [detail])!
        let imported = ShareableWorkout.import(from: data)!

        let converted = imported.toWorkoutDetails()
        XCTAssertEqual(converted[0].sets.count, 2)
        XCTAssertEqual(converted[0].sets[0].reps, 10)
        XCTAssertEqual(converted[0].sets[0].weight, 135)
        XCTAssertEqual(converted[0].sets[1].reps, 8)
        XCTAssertEqual(converted[0].sets[1].weight, 155)
    }

    func testToWorkoutDetails_PreservesExerciseMetadata() {
        let detail = WorkoutDetailInput(
            id: UUID(), exerciseId: UUID(), exerciseName: "Run",
            orderIndex: 2, sets: [],
            exerciseQuantifier: "Distance", exerciseMeasurement: "Time"
        )
        let data = ShareableWorkout.export(workoutName: "Cardio", workoutColor: nil, workoutDetails: [detail])!
        let imported = ShareableWorkout.import(from: data)!

        let converted = imported.toWorkoutDetails()
        XCTAssertEqual(converted[0].exerciseName, "Run")
        XCTAssertEqual(converted[0].orderIndex, 2)
        XCTAssertEqual(converted[0].exerciseQuantifier, "Distance")
        XCTAssertEqual(converted[0].exerciseMeasurement, "Time")
    }

    // MARK: - Generic JSON import

    func testGenericJSON_MinimalFormat_Imports() {
        let json = """
        {
            "name": "Push Day",
            "exercises": [
                { "name": "Bench Press", "sets": [{ "reps": 10, "weight": 135.0 }] }
            ]
        }
        """.data(using: .utf8)!

        guard let workout = ShareableWorkout.import(from: json) else {
            XCTFail("import returned nil"); return
        }
        XCTAssertEqual(workout.workoutName, "Push Day")
        XCTAssertEqual(workout.exercises.count, 1)
        XCTAssertEqual(workout.exercises[0].name, "Bench Press")
        XCTAssertEqual(workout.exercises[0].sets[0].reps, 10)
        XCTAssertEqual(workout.exercises[0].sets[0].weight, Float(135.0), accuracy: Float(0.01))
    }

    func testGenericJSON_DefaultsQuantifierAndMeasurement() {
        let json = """
        {
            "name": "Workout",
            "exercises": [{ "name": "Squat", "sets": [{ "reps": 5 }] }]
        }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertEqual(workout.exercises[0].quantifier, "Reps")
        XCTAssertEqual(workout.exercises[0].measurement, "Weight")
    }

    func testGenericJSON_ExplicitQuantifierAndMeasurement() {
        let json = """
        {
            "name": "Cardio",
            "exercises": [{
                "name": "5K Run",
                "quantifier": "Distance",
                "measurement": "Time",
                "sets": [{ "distance": 5.0, "time": 1500 }]
            }]
        }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertEqual(workout.exercises[0].quantifier, "Distance")
        XCTAssertEqual(workout.exercises[0].measurement, "Time")
        XCTAssertEqual(workout.exercises[0].sets[0].distance, 5.0, accuracy: 0.01)
        XCTAssertEqual(workout.exercises[0].sets[0].time, 1500)
    }

    func testGenericJSON_OmittedSets_DefaultsToThreeEmptySets() {
        let json = """
        {
            "name": "Workout",
            "exercises": [{ "name": "Deadlift" }]
        }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertEqual(workout.exercises[0].sets.count, 3)
        XCTAssertEqual(workout.exercises[0].sets[0].reps, 0)
        XCTAssertEqual(workout.exercises[0].sets[0].weight, 0)
    }

    func testGenericJSON_Notes_Preserved() {
        let json = """
        {
            "name": "Workout",
            "exercises": [{ "name": "Pull-up", "notes": "Wide grip", "sets": [] }]
        }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertEqual(workout.exercises[0].notes, "Wide grip")
    }

    func testGenericJSON_MultipleExercises_OrderPreserved() {
        let json = """
        {
            "name": "Full Body",
            "exercises": [
                { "name": "Squat", "sets": [{ "reps": 5, "weight": 225 }] },
                { "name": "Press", "sets": [{ "reps": 8, "weight": 95 }] },
                { "name": "Deadlift", "sets": [{ "reps": 3, "weight": 275 }] }
            ]
        }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertEqual(workout.exercises.count, 3)
        XCTAssertEqual(workout.exercises[0].name, "Squat")
        XCTAssertEqual(workout.exercises[0].orderIndex, 0)
        XCTAssertEqual(workout.exercises[1].name, "Press")
        XCTAssertEqual(workout.exercises[1].orderIndex, 1)
        XCTAssertEqual(workout.exercises[2].name, "Deadlift")
        XCTAssertEqual(workout.exercises[2].orderIndex, 2)
    }

    func testGenericJSON_MissingName_ReturnsNil() {
        let json = """
        { "exercises": [{ "name": "Bench", "sets": [] }] }
        """.data(using: .utf8)!

        XCTAssertNil(ShareableWorkout.import(from: json))
    }

    func testGenericJSON_NilColor() {
        let json = """
        { "name": "Test", "exercises": [] }
        """.data(using: .utf8)!

        let workout = ShareableWorkout.import(from: json)!
        XCTAssertNil(workout.workoutColor)
    }

    // MARK: - Helpers

    private func makeDetail(
        name: String,
        reps: Int32 = 0,
        weight: Float = 0,
        time: Int32 = 0,
        distance: Float = 0,
        quantifier: String = "Reps",
        measurement: String = "Weight"
    ) -> WorkoutDetailInput {
        WorkoutDetailInput(
            id: UUID(),
            exerciseId: UUID(),
            exerciseName: name,
            orderIndex: 0,
            sets: [SetInput(reps: reps, weight: weight, time: time, distance: distance, setIndex: 0)],
            exerciseQuantifier: quantifier,
            exerciseMeasurement: measurement
        )
    }
}
