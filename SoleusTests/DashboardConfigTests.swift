import XCTest
@testable import Soleus

final class DashboardConfigTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private let suiteName = "DashboardConfigTests"

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        super.tearDown()
    }

    func testLoadReturnsDefaultsWhenNothingStored() {
        let settings = DashboardConfigStore.load(from: userDefaults)

        XCTAssertEqual(settings.map(\.widget), DashboardWidget.allCases)
        XCTAssertTrue(settings.allSatisfy(\.isVisible))
    }

    func testSaveAndLoadRoundTripPreservesOrderAndVisibility() {
        var settings = DashboardConfigStore.defaults
        // Hide the first widget and move it to the end
        settings[0].isVisible = false
        let first = settings.removeFirst()
        settings.append(first)

        DashboardConfigStore.save(settings, to: userDefaults)
        let loaded = DashboardConfigStore.load(from: userDefaults)

        XCTAssertEqual(loaded, settings)
    }

    func testLoadAppendsWidgetsMissingFromStoredConfig() {
        // Simulate a config saved by an older app version that only knew
        // about two widgets
        let partial = [
            DashboardWidgetSetting(widget: .streaks, isVisible: false),
            DashboardWidgetSetting(widget: .achievements, isVisible: true)
        ]
        DashboardConfigStore.save(partial, to: userDefaults)

        let loaded = DashboardConfigStore.load(from: userDefaults)

        XCTAssertEqual(loaded.count, DashboardWidget.allCases.count)
        // Stored order and visibility kept
        XCTAssertEqual(loaded[0], DashboardWidgetSetting(widget: .streaks, isVisible: false))
        XCTAssertEqual(loaded[1], DashboardWidgetSetting(widget: .achievements, isVisible: true))
        // New widgets appended visible
        let appended = loaded.dropFirst(2)
        XCTAssertTrue(appended.allSatisfy(\.isVisible))
        XCTAssertEqual(Set(loaded.map(\.widget)), Set(DashboardWidget.allCases))
    }

    func testReconcileDropsDuplicateEntries() {
        let duplicated = [
            DashboardWidgetSetting(widget: .streaks, isVisible: false),
            DashboardWidgetSetting(widget: .streaks, isVisible: true)
        ]

        let reconciled = DashboardConfigStore.reconcile(duplicated)

        XCTAssertEqual(reconciled.filter { $0.widget == .streaks }.count, 1)
        // First occurrence wins
        XCTAssertEqual(reconciled.first?.isVisible, false)
        XCTAssertEqual(Set(reconciled.map(\.widget)), Set(DashboardWidget.allCases))
    }

    func testLoadFallsBackToDefaultsOnCorruptData() {
        userDefaults.set(Data("not json".utf8), forKey: DashboardConfigStore.storageKey)

        let settings = DashboardConfigStore.load(from: userDefaults)

        XCTAssertEqual(settings, DashboardConfigStore.defaults)
    }

    func testLoadFallsBackToDefaultsOnUnknownWidget() {
        // A config saved by a future app version with a widget this version
        // doesn't know about fails the decode and falls back to defaults
        let futureConfig = """
        [{"widget":"someFutureWidget","isVisible":true}]
        """
        userDefaults.set(Data(futureConfig.utf8), forKey: DashboardConfigStore.storageKey)

        let settings = DashboardConfigStore.load(from: userDefaults)

        XCTAssertEqual(settings, DashboardConfigStore.defaults)
    }
}
