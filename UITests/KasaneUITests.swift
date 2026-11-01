import XCTest

final class KasaneUITests: XCTestCase {
    @MainActor
    func testTimerRestoresAfterRelaunchAndAddsToExistingRecord() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.adachi.kasane")
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()

        let firstRoutine = app.buttons["today.firstRoutine"]
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10))
        firstRoutine.tap()
        let template = app.buttons["routine.template.読書"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
        XCTAssertTrue(app.buttons["routine.save"].isEnabled)
        app.buttons["routine.save"].tap()

        let record = app.buttons["today.record.読書"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let minutes = app.textFields["record.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        replaceText(in: minutes, with: "25")
        app.buttons["record.save"].tap()
        XCTAssertTrue(app.staticTexts["today.totalTime"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["today.totalTime"].label, "25分")

        let start = app.buttons["today.start.読書"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let elapsed = app.staticTexts["timer.elapsed"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        let tick = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "00:00:00"), object: elapsed)
        XCTAssertEqual(XCTWaiter.wait(for: [tick], timeout: 5), .completed)
        let secondsBeforeRelaunch = try clockSeconds(elapsed.label)
        XCTAssertGreaterThan(secondsBeforeRelaunch, 0)

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let resume = app.buttons["timer.resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10))
        resume.tap()
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        let secondsAfterRelaunch = try clockSeconds(elapsed.label)
        XCTAssertGreaterThanOrEqual(secondsAfterRelaunch, secondsBeforeRelaunch)
        capture("RestoredTimer", app: app)
        let secondsBeforeFinish = try clockSeconds(elapsed.label)
        app.buttons["timer.finish"].tap()

        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["timer.resume"].exists)
        record.tap()
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        let storedMinutes = try XCTUnwrap(Int(minutes.value as? String ?? ""))
        let storedSeconds = try XCTUnwrap(Int(app.textFields["record.seconds"].value as? String ?? ""))
        let totalSeconds = storedMinutes * 60 + storedSeconds
        XCTAssertGreaterThanOrEqual(totalSeconds, 25 * 60 + secondsBeforeFinish)
        XCTAssertLessThan(totalSeconds, 25 * 60 + secondsBeforeFinish + 30)
        XCTAssertTrue(app.segmentedControls["record.outcome"].buttons["できた"].isSelected)
        capture("TimerAddedToRecord", app: app)

        app.buttons["キャンセル"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(record.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["timer.resume"].exists)
        record.tap()
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        XCTAssertEqual(Int(minutes.value as? String ?? ""), storedMinutes)
        XCTAssertEqual(Int(app.textFields["record.seconds"].value as? String ?? ""), storedSeconds)
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with text: String) {
        field.tap()
        let current = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + text)
    }

    private func clockSeconds(_ value: String) throws -> Int {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else {
            XCTFail("Unexpected timer value: \(value)")
            throw TimerTestError.invalidClock
        }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private enum TimerTestError: Error { case invalidClock }
}
