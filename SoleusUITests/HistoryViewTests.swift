import XCTest

final class HistoryViewTests: SoleusUITestBase {

    func testNavigateToHistoryView() {
        tapNavBarButton(TestID.navHistoryButton)

        // History view should show empty state on fresh install
        let emptyText = app.staticTexts[TestID.historyEmptyStateText]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5), "History empty state should be visible")
    }

    func testHistoryEmptyStateContent() {
        tapNavBarButton(TestID.navHistoryButton)

        let emptyText = app.staticTexts[TestID.historyEmptyStateText]
        XCTAssertTrue(emptyText.waitForExistence(timeout: 5))
        XCTAssertEqual(emptyText.label, "No workout history yet")
    }

    func testViewModeButtonsExist() {
        tapNavBarButton(TestID.navHistoryButton)

        let listButton = app.buttons[TestID.historyModeList]
        let calendarButton = app.buttons[TestID.historyModeCalendar]
        let progressButton = app.buttons[TestID.historyModeProgress]

        XCTAssertTrue(listButton.waitForExistence(timeout: 5), "List mode button should exist")
        XCTAssertTrue(calendarButton.waitForExistence(timeout: 5), "Calendar mode button should exist")
        XCTAssertTrue(progressButton.waitForExistence(timeout: 5), "Progress mode button should exist")
    }

    func testCalendarModeShowsCurrentMonth() {
        tapNavBarButton(TestID.navHistoryButton)

        let calendarButton = app.buttons[TestID.historyModeCalendar]
        XCTAssertTrue(calendarButton.waitForExistence(timeout: 5))
        calendarButton.tap()

        let monthLabel = app.staticTexts[TestID.historyCalendarMonthLabel]
        XCTAssertTrue(monthLabel.waitForExistence(timeout: 5), "Calendar month label should be visible")

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        XCTAssertEqual(monthLabel.label, formatter.string(from: Date()), "Calendar should open on the current month")
    }

    func testCalendarMonthNavigation() {
        tapNavBarButton(TestID.navHistoryButton)

        let calendarButton = app.buttons[TestID.historyModeCalendar]
        XCTAssertTrue(calendarButton.waitForExistence(timeout: 5))
        calendarButton.tap()

        let previousButton = app.buttons[TestID.historyCalendarPreviousMonth]
        XCTAssertTrue(previousButton.waitForExistence(timeout: 5))
        previousButton.tap()

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        let monthLabel = app.staticTexts[TestID.historyCalendarMonthLabel]
        XCTAssertEqual(monthLabel.label, formatter.string(from: previousMonth), "Previous month should be displayed")

        let nextButton = app.buttons[TestID.historyCalendarNextMonth]
        nextButton.tap()
        XCTAssertEqual(monthLabel.label, formatter.string(from: Date()), "Next button should return to the current month")
    }
}
