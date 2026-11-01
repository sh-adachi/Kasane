import XCTest

final class ExpansionRoutineUITests: XCTestCase {
    @MainActor
    func testWeeklyGoalAndReminderSettingsPersist() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.adachi.kasane")
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        createReadingRoutine(app, configure: {
            let weeklyGoal = app.switches["routine.weeklyGoalEnabled"]
            reveal(weeklyGoal, in: app)
            XCTAssertEqual(weeklyGoal.value as? String, "0")
            weeklyGoal.tap()
            let twoHours = app.buttons["120分"]
            reveal(twoHours, in: app)
            twoHours.tap()
            XCTAssertEqual(app.textFields["routine.weeklyGoalMinutes"].value as? String, "120")
            capture("RoutineGoals", app: app)

            let hasTime = app.switches["routine.hasPreferredTime"]
            reveal(hasTime, in: app)
            hasTime.tap()
            let reminder = app.switches["routine.reminderEnabled"]
            reveal(reminder, in: app)
            XCTAssertEqual(reminder.value as? String, "0")
            reminder.tap()
            XCTAssertEqual(reminder.value as? String, "1")
        })

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["today.record.読書"].waitForExistence(timeout: 10))
        openReadingEditor(app)
        let weeklyGoal = app.switches["routine.weeklyGoalEnabled"]
        reveal(weeklyGoal, in: app)
        XCTAssertEqual(weeklyGoal.value as? String, "1")
        XCTAssertEqual(app.textFields["routine.weeklyGoalMinutes"].value as? String, "120")
        let hasTime = app.switches["routine.hasPreferredTime"]
        reveal(hasTime, in: app)
        XCTAssertEqual(hasTime.value as? String, "1")
        let reminder = app.switches["routine.reminderEnabled"]
        reveal(reminder, in: app)
        XCTAssertEqual(reminder.value as? String, "1")
        capture("RestoredReminder", app: app)

        reveal(hasTime, in: app)
        hasTime.tap()
        app.buttons["routine.save"].tap()
        XCTAssertTrue(app.buttons["routine.add"].waitForExistence(timeout: 5))
        openReadingEditor(app)
        reveal(hasTime, in: app)
        XCTAssertEqual(hasTime.value as? String, "0")
        XCTAssertFalse(reminder.exists)
        // Re-enabling the time reveals the persisted reminder value without saving.
        hasTime.tap()
        reveal(reminder, in: app)
        XCTAssertEqual(reminder.value as? String, "0")
        app.buttons["キャンセル"].tap()

        app.tabBars.buttons["今日"].tap()
        let record = app.buttons["today.record.読書"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let minutes = app.textFields["record.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        replaceText(in: minutes, with: "30")
        app.buttons["record.save"].tap()
        XCTAssertTrue(app.staticTexts["today.totalTime"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["today.totalTime"].label, "30分")

        app.tabBars.buttons["積み重ね"].tap()
        let goal = app.descendants(matching: .any).matching(identifier: "progress.weeklyGoal.読書").firstMatch
        reveal(goal, in: app)
        XCTAssertTrue(goal.label.contains("30分"), "Weekly goal should include the recorded 30 minutes: \(goal.label)")
        XCTAssertTrue(goal.label.contains("2時間"), "Weekly goal should preserve the 120-minute target: \(goal.label)")
        capture("WeeklyGoalProgress", app: app)
    }

    @MainActor
    func testPausedTimerPersistsAndOnlyResumesWhenRequested() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.adachi.kasane")
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        createReadingRoutine(app)
        let start = app.buttons["today.start.読書"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let elapsed = app.staticTexts["timer.elapsed"]
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        let initialTick = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", "00:00:00"), object: elapsed)
        XCTAssertEqual(XCTWaiter.wait(for: [initialTick], timeout: 5), .completed)
        let pause = app.buttons["timer.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        pause.tap()
        let continueTimer = app.buttons["timer.continue"]
        XCTAssertTrue(continueTimer.waitForExistence(timeout: 5))
        let pausedTime = elapsed.label
        XCTAssertGreaterThan(try clockSeconds(pausedTime), 0)
        capture("PausedTimer", app: app)

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let reopenTimer = app.buttons["timer.resume"]
        XCTAssertTrue(reopenTimer.waitForExistence(timeout: 10))
        reopenTimer.tap()
        XCTAssertTrue(continueTimer.waitForExistence(timeout: 5))
        XCTAssertTrue(elapsed.waitForExistence(timeout: 5))
        XCTAssertEqual(elapsed.label, pausedTime)
        let mustStayPaused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", pausedTime), object: elapsed)
        mustStayPaused.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [mustStayPaused], timeout: 2.2), .completed)

        continueTimer.tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        let resumedTick = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", pausedTime), object: elapsed)
        XCTAssertEqual(XCTWaiter.wait(for: [resumedTick], timeout: 5), .completed)
        let secondsBeforeFinish = try clockSeconds(elapsed.label)
        XCTAssertGreaterThan(secondsBeforeFinish, try clockSeconds(pausedTime))
        app.buttons["timer.finish"].tap()
        let record = app.buttons["today.record.読書"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertFalse(reopenTimer.exists)
        record.tap()
        let minutes = app.textFields["record.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        let storedMinutes = try XCTUnwrap(Int(minutes.value as? String ?? ""))
        let storedSeconds = try XCTUnwrap(Int(app.textFields["record.seconds"].value as? String ?? ""))
        let totalSeconds = storedMinutes * 60 + storedSeconds
        XCTAssertGreaterThanOrEqual(totalSeconds, secondsBeforeFinish)
        XCTAssertLessThan(totalSeconds, secondsBeforeFinish + 30)
        XCTAssertTrue(app.segmentedControls["record.outcome"].buttons["できた"].isSelected)
    }

    @MainActor
    private func createReadingRoutine(_ app: XCUIApplication, configure: () -> Void = {}) {
        let firstRoutine = app.buttons["today.firstRoutine"]
        XCTAssertTrue(firstRoutine.waitForExistence(timeout: 10))
        firstRoutine.tap()
        let template = app.buttons["routine.template.読書"]
        XCTAssertTrue(template.waitForExistence(timeout: 5))
        template.tap()
        configure()
        XCTAssertTrue(app.buttons["routine.save"].isEnabled)
        app.buttons["routine.save"].tap()
        XCTAssertTrue(app.buttons["today.record.読書"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func openReadingEditor(_ app: XCUIApplication) {
        app.tabBars.buttons["ルーティン"].tap()
        let edit = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "routine.edit.")).firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.textFields["routine.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews.firstMatch
            XCTAssertTrue(scroll.exists, "Expected a scrollable screen", file: file, line: line)
            if element.exists && element.frame.maxY < scroll.frame.minY + 50 {
                scroll.swipeDown(velocity: .slow)
            } else {
                scroll.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Could not reveal \(element.identifier)", file: file, line: line)
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
            throw TimerValueError.invalidClock
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

    private enum TimerValueError: Error { case invalidClock }
}
