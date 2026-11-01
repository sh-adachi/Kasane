import XCTest

final class ExpansionHistoryUITests: XCTestCase {
    @MainActor
    func testHistoryEditsPastRecordAndRestoresItAfterRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "dev.adachi.kasane")
        app.launchArguments = ["--uitesting", "--reset-data", "--sample-data"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["履歴"].waitForExistence(timeout: 10))
        app.tabBars.buttons["履歴"].tap()
        XCTAssertTrue(app.staticTexts["history.month"].waitForExistence(timeout: 5))
        capture("HistoryCalendar", app: app)

        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: today))
        selectYesterday(yesterday, today: today, calendar: calendar, app: app)
        let record = app.buttons["history.record.本を読む"]
        reveal(record, in: app)
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.isEnabled)
        record.tap()
        XCTAssertTrue(app.textFields["record.minutes"].waitForExistence(timeout: 5))
        app.buttons["30分"].tap()
        app.segmentedControls["record.outcome"].buttons["できなかった"].tap()
        capture("HistoryRecordEditor", app: app)
        app.buttons["record.save"].tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.label.contains("30分"))
        XCTAssertTrue(record.label.contains("できなかった"))

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["履歴"].waitForExistence(timeout: 10))
        app.tabBars.buttons["履歴"].tap()
        selectYesterday(yesterday, today: today, calendar: calendar, app: app)
        reveal(record, in: app)
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.label.contains("30分"))
        record.tap()
        let minutes = app.textFields["record.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        XCTAssertEqual(minutes.value as? String, "30")
        XCTAssertTrue(app.segmentedControls["record.outcome"].buttons["できなかった"].isSelected)
        app.buttons["キャンセル"].tap()

        revealTop(in: app)
        app.buttons["history.today"].tap()
        app.buttons["history.filter"].tap()
        let readingFilter = app.buttons["本を読む"]
        XCTAssertTrue(readingFilter.waitForExistence(timeout: 5))
        readingFilter.tap()
        reveal(record, in: app)
        XCTAssertTrue(record.exists)
        XCTAssertFalse(app.buttons["history.record.朝のストレッチ"].exists)

        revealTop(in: app)
        app.buttons["history.nextMonth"].tap()
        reveal(record, in: app)
        XCTAssertTrue(record.exists)
        XCTAssertFalse(record.isEnabled, "Future records must not be editable")
        capture("HistoryFuture", app: app)
    }

    @MainActor
    private func selectYesterday(_ yesterday: Date, today: Date, calendar: Calendar, app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["history.month"].waitForExistence(timeout: 5))
        if !calendar.isDate(yesterday, equalTo: today, toGranularity: .month) {
            app.buttons["history.previousMonth"].tap()
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: yesterday)
        let day = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
        let dateButton = app.buttons["history.day.\(day)"]
        XCTAssertTrue(dateButton.waitForExistence(timeout: 5))
        dateButton.tap()
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.isHittable { return }
            app.swipeUp()
        }
    }

    @MainActor
    private func revealTop(in app: XCUIApplication) {
        for _ in 0..<5 {
            if app.buttons["history.today"].isHittable { return }
            app.swipeDown()
        }
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
