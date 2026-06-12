import XCTest

final class WorkoutValidationTests: SoleusUITestBase {

    func testSaveWithEmptyTitleShowsError() {
        tapNavBarButton(TestID.navAddWorkoutButton)

        // Try to save without a title
        let saveButton = app.buttons[TestID.addWorkoutSaveButton]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Error alert should appear
        let alert = app.alerts["Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Error alert should appear for empty title")
    }

    func testSaveWithNoExercisesShowsError() {
        tapNavBarButton(TestID.navAddWorkoutButton)

        // Enter a title but don't add exercises
        let titleField = app.textFields[TestID.addWorkoutTitleField]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("My Workout")

        // Try to save
        let saveButton = app.buttons[TestID.addWorkoutSaveButton]
        saveButton.tap()

        // Error alert should appear
        let alert = app.alerts["Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Error alert should appear for no exercises")
    }

    func testAddExerciseButtonDisabledWhenNameEmpty() {
        tapNavBarButton(TestID.navAddWorkoutButton)

        let addExerciseButton = app.buttons[TestID.addWorkoutAddExerciseButton]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 5))
        addExerciseButton.tap()

        // Exercise library picker opens first; use Create Custom to reach the dialog
        let createCustomButton = app.buttons[TestID.exercisePickerCreateCustomButton]
        XCTAssertTrue(createCustomButton.waitForExistence(timeout: 5))
        createCustomButton.tap()

        // The Add Exercise dialog button should be disabled when name is empty
        let dialogAddButton = app.buttons[TestID.exerciseDialogAddButton]
        XCTAssertTrue(dialogAddButton.waitForExistence(timeout: 5))
        XCTAssertFalse(dialogAddButton.isEnabled, "Add Exercise button should be disabled when name is empty")
    }

    func testCancelDismissesCreateSheet() {
        tapNavBarButton(TestID.navAddWorkoutButton)

        let cancelButton = app.buttons[TestID.addWorkoutCancelButton]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // The create sheet should be dismissed - nav add button should be visible again
        let navAddButton = app.buttons[TestID.navAddWorkoutButton]
        XCTAssertTrue(navAddButton.waitForExistence(timeout: 5), "Should return to main view after cancel")
    }
}
