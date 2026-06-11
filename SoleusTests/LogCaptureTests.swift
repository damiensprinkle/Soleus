import XCTest
@testable import Soleus

final class LogCaptureTests: XCTestCase {
    // LogCapture is a singleton — we clear between tests
    var sut: LogCapture { LogCapture.shared }

    override func setUp() {
        super.setUp()
        sut.clear()
        flushMain()
    }

    override func tearDown() {
        sut.clear()
        flushMain()
        super.tearDown()
    }

    private func flushMain() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    // MARK: - log

    func testLog_AddsOneEntry() {
        sut.log("test message")
        flushMain()
        XCTAssertEqual(sut.logs.count, 1)
    }

    func testLog_StoresMessage() {
        sut.log("hello world")
        flushMain()
        XCTAssertEqual(sut.logs.first?.message, "hello world")
    }

    func testLog_StoresCategory() {
        sut.log("msg", category: "Workout")
        flushMain()
        XCTAssertEqual(sut.logs.first?.category, "Workout")
    }

    func testLog_DefaultCategory_IsGeneral() {
        sut.log("msg")
        flushMain()
        XCTAssertEqual(sut.logs.first?.category, "General")
    }

    func testLog_DefaultLevel_IsInfo() {
        sut.log("msg")
        flushMain()
        XCTAssertEqual(sut.logs.first?.level, .info)
    }

    func testLog_StoresTimestamp() {
        let before = Date()
        sut.log("timed")
        flushMain()
        let after = Date()
        let timestamp = sut.logs.first!.timestamp
        XCTAssertTrue(timestamp >= before && timestamp <= after)
    }

    func testLog_MultipleMessages_PreservesOrder() {
        sut.log("first")
        sut.log("second")
        sut.log("third")
        flushMain()
        XCTAssertEqual(sut.logs.count, 3)
        XCTAssertEqual(sut.logs[0].message, "first")
        XCTAssertEqual(sut.logs[1].message, "second")
        XCTAssertEqual(sut.logs[2].message, "third")
    }

    // MARK: - Level helpers

    func testDebug_LogsWithDebugLevel() {
        sut.debug("debug msg")
        flushMain()
        XCTAssertEqual(sut.logs.first?.level, .debug)
        XCTAssertEqual(sut.logs.first?.message, "debug msg")
    }

    func testInfo_LogsWithInfoLevel() {
        sut.info("info msg")
        flushMain()
        XCTAssertEqual(sut.logs.first?.level, .info)
    }

    func testWarning_LogsWithWarningLevel() {
        sut.warning("warn msg")
        flushMain()
        XCTAssertEqual(sut.logs.first?.level, .warning)
    }

    func testError_LogsWithErrorLevel() {
        sut.error("err msg")
        flushMain()
        XCTAssertEqual(sut.logs.first?.level, .error)
    }

    func testCritical_LogsWithCriticalLevel() {
        sut.critical("crit msg")
        flushMain()
        XCTAssertEqual(sut.logs.first?.level, .critical)
    }

    func testLevelHelpers_PassCategoryThrough() {
        sut.warning("w", category: "Network")
        flushMain()
        XCTAssertEqual(sut.logs.first?.category, "Network")
    }

    // MARK: - clear

    func testClear_RemovesAllLogs() {
        sut.log("a")
        sut.log("b")
        flushMain()
        XCTAssertEqual(sut.logs.count, 2)

        sut.clear()
        flushMain()
        XCTAssertEqual(sut.logs.count, 0)
    }

    func testClear_WhenEmpty_DoesNotCrash() {
        sut.clear()
        flushMain()
        XCTAssertEqual(sut.logs.count, 0)
    }

    // MARK: - LogEntry properties

    func testLogEntry_HasUniqueId() {
        sut.log("a")
        sut.log("b")
        flushMain()
        let ids = sut.logs.map { $0.id }
        XCTAssertNotEqual(ids[0], ids[1])
    }

    func testLogEntry_FormattedTime_HasExpectedFormat() {
        sut.log("time test")
        flushMain()
        let formatted = sut.logs.first!.formattedTime
        // Format: "HH:mm:ss.SSS" — should have two colons and one dot
        XCTAssertEqual(formatted.filter { $0 == ":" }.count, 2)
        XCTAssertEqual(formatted.filter { $0 == "." }.count, 1)
    }

    // MARK: - Scrubbing

    func testScrub_RedactsSingleQuotedContent() {
        let scrubbed = LogCapture.scrubUserContent("Adding exercise 'Bench Press' at index 0")
        XCTAssertEqual(scrubbed, "Adding exercise '<redacted>' at index 0")
    }

    func testScrub_RedactsMultipleQuotedSegments() {
        let scrubbed = LogCapture.scrubUserContent("Workout '<redacted>' note '<redacted>' saved")
        // Already-redacted text is idempotent
        XCTAssertEqual(scrubbed, "Workout '<redacted>' note '<redacted>' saved")

        let original = LogCapture.scrubUserContent("Workout 'Push Day' note 'PR attempt' saved")
        XCTAssertEqual(original, "Workout '<redacted>' note '<redacted>' saved")
    }

    func testScrub_PreservesMessagesWithoutQuotes() {
        let scrubbed = LogCapture.scrubUserContent("Failed to save: NSCocoaErrorDomain 134000")
        XCTAssertEqual(scrubbed, "Failed to save: NSCocoaErrorDomain 134000")
    }

    func testScrub_PreservesUUIDsAndNumbers() {
        let scrubbed = LogCapture.scrubUserContent("No workout found with ID: \(UUID().uuidString)")
        XCTAssertFalse(scrubbed.contains("<redacted>"))
    }

    func testScrub_HandlesEmptyQuotedSegment() {
        let scrubbed = LogCapture.scrubUserContent("Empty name '' rejected")
        XCTAssertEqual(scrubbed, "Empty name '<redacted>' rejected")
    }

    // MARK: - LogLevel rawValues

    func testLogLevel_RawValues() {
        XCTAssertEqual(LogCapture.LogLevel.debug.rawValue, "🔍")
        XCTAssertEqual(LogCapture.LogLevel.info.rawValue, "ℹ️")
        XCTAssertEqual(LogCapture.LogLevel.warning.rawValue, "⚠️")
        XCTAssertEqual(LogCapture.LogLevel.error.rawValue, "❌")
        XCTAssertEqual(LogCapture.LogLevel.critical.rawValue, "🔥")
    }
}
