import XCTest
import CoreData
@testable import Soleus

final class ExerciseLibraryManagerTests: XCTestCase {
    var sut: ExerciseLibraryManager!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController.forUITesting
        context = persistence.container.viewContext
        sut = ExerciseLibraryManager()
        sut.context = context
    }

    override func tearDown() {
        let fetchRequest: NSFetchRequest<ExerciseTemplate> = ExerciseTemplate.fetchRequest()
        if let templates = try? context.fetch(fetchRequest) {
            templates.forEach { context.delete($0) }
            try? context.save()
        }
        UserDefaults.standard.removeObject(forKey: "hasSeededExerciseLibrary")
        sut = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Seeding

    func testSeedDefaultLibrary_PopulatesTemplates() {
        sut.seedDefaultLibraryIfNeeded()

        let templates = sut.fetchAll()
        XCTAssertEqual(templates.count, ExerciseLibraryManager.defaultLibrary.count)
        XCTAssertTrue(templates.allSatisfy { !$0.isCustom })
    }

    func testSeedDefaultLibrary_SecondCallDoesNotDuplicate() {
        sut.seedDefaultLibraryIfNeeded()
        sut.seedDefaultLibraryIfNeeded()

        XCTAssertEqual(sut.fetchAll().count, ExerciseLibraryManager.defaultLibrary.count)
    }

    func testSeedDefaultLibrary_DoesNotReseedAfterDeleteAll() {
        sut.seedDefaultLibraryIfNeeded()
        sut.fetchAll().forEach { sut.deleteExercise($0) }

        sut.seedDefaultLibraryIfNeeded()

        XCTAssertTrue(sut.fetchAll().isEmpty, "Deleting the library should not trigger a re-seed")
    }

    // MARK: - CRUD

    func testCreateExercise_AddsTemplate() {
        let created = sut.createExercise(name: "Cable Pullover", description: "desc", category: "Back", quantifier: "Reps", measurement: "Weight")

        XCTAssertTrue(created)
        let template = sut.fetchTemplate(named: "Cable Pullover")
        XCTAssertNotNil(template)
        XCTAssertEqual(template?.category, "Back")
        XCTAssertTrue(template?.isCustom ?? false)
    }

    func testCreateExercise_DuplicateNameCaseInsensitive_Fails() {
        sut.createExercise(name: "Bench Press", description: nil, category: "Chest", quantifier: "Reps", measurement: "Weight")

        let created = sut.createExercise(name: "bench press", description: nil, category: "Chest", quantifier: "Reps", measurement: "Weight")

        XCTAssertFalse(created)
        XCTAssertEqual(sut.fetchAll().count, 1)
    }

    func testCreateExercise_EmptyName_Fails() {
        XCTAssertFalse(sut.createExercise(name: "   ", description: nil, category: "Other", quantifier: "Reps", measurement: "Weight"))
    }

    func testUpdateExercise_ChangesFields() {
        sut.createExercise(name: "Old Name", description: nil, category: "Other", quantifier: "Reps", measurement: "Weight")
        let template = sut.fetchTemplate(named: "Old Name")!

        let updated = sut.updateExercise(template, name: "New Name", description: "new desc", category: "Legs", quantifier: "Reps", measurement: "Time")

        XCTAssertTrue(updated)
        XCTAssertNil(sut.fetchTemplate(named: "Old Name"))
        let renamed = sut.fetchTemplate(named: "New Name")
        XCTAssertEqual(renamed?.category, "Legs")
        XCTAssertEqual(renamed?.defaultMeasurement, "Time")
        XCTAssertEqual(renamed?.descriptionText, "new desc")
    }

    func testUpdateExercise_RenameCollision_Fails() {
        sut.createExercise(name: "Squat", description: nil, category: "Legs", quantifier: "Reps", measurement: "Weight")
        sut.createExercise(name: "Lunge", description: nil, category: "Legs", quantifier: "Reps", measurement: "Weight")
        let lunge = sut.fetchTemplate(named: "Lunge")!

        XCTAssertFalse(sut.updateExercise(lunge, name: "Squat", description: nil, category: "Legs", quantifier: "Reps", measurement: "Weight"))
    }

    func testUpdateExercise_SameTemplateKeepsName_Succeeds() {
        sut.createExercise(name: "Squat", description: nil, category: "Legs", quantifier: "Reps", measurement: "Weight")
        let squat = sut.fetchTemplate(named: "Squat")!

        XCTAssertTrue(sut.updateExercise(squat, name: "Squat", description: "updated", category: "Legs", quantifier: "Reps", measurement: "Weight"))
        XCTAssertEqual(sut.fetchTemplate(named: "Squat")?.descriptionText, "updated")
    }

    func testDeleteExercise_RemovesTemplate() {
        sut.createExercise(name: "Squat", description: nil, category: "Legs", quantifier: "Reps", measurement: "Weight")
        let squat = sut.fetchTemplate(named: "Squat")!

        sut.deleteExercise(squat)

        XCTAssertNil(sut.fetchTemplate(named: "Squat"))
    }

    // MARK: - Usage Tracking

    func testRecordUsage_ExistingTemplate_IncrementsCount() {
        sut.createExercise(name: "Squat", description: nil, category: "Legs", quantifier: "Reps", measurement: "Weight")

        sut.recordUsage(name: "Squat", quantifier: "Reps", measurement: "Weight")
        sut.recordUsage(name: "squat", quantifier: "Reps", measurement: "Weight")

        XCTAssertEqual(sut.fetchTemplate(named: "Squat")?.usageCount, 2)
    }

    func testRecordUsage_UnknownName_AutoCreatesCustomTemplate() {
        sut.recordUsage(name: "Sled Push", quantifier: "Distance", measurement: "Time")

        let template = sut.fetchTemplate(named: "Sled Push")
        XCTAssertNotNil(template)
        XCTAssertTrue(template?.isCustom ?? false)
        XCTAssertEqual(template?.usageCount, 1)
        XCTAssertEqual(template?.defaultQuantifier, "Distance")
        XCTAssertEqual(template?.defaultMeasurement, "Time")
    }

    func testFetchAll_SortsByUsageThenName() {
        sut.createExercise(name: "Bravo", description: nil, category: "Other", quantifier: "Reps", measurement: "Weight")
        sut.createExercise(name: "Alpha", description: nil, category: "Other", quantifier: "Reps", measurement: "Weight")
        sut.createExercise(name: "Charlie", description: nil, category: "Other", quantifier: "Reps", measurement: "Weight")
        sut.recordUsage(name: "Charlie", quantifier: "Reps", measurement: "Weight")

        let names = sut.fetchAll().map { $0.name }

        XCTAssertEqual(names, ["Charlie", "Alpha", "Bravo"])
    }
}
