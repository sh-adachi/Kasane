import XCTest

final class SmokeUITests: XCTestCase {
    @MainActor
    func testCreateRecordAndRestore() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-data"]
        app.launch()
        XCTAssertTrue(app.buttons["today.firstRoutine"].waitForExistence(timeout: 10))
        capture("Welcome", app: app)
        app.buttons["today.firstRoutine"].tap()
        app.buttons["routine.template.読書"].tap()
        XCTAssertTrue(app.buttons["routine.save"].isEnabled)
        app.buttons["routine.save"].tap()
        let record = app.buttons["today.record.読書"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        let minutes = app.textFields["record.minutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        minutes.tap()
        minutes.typeText("25")
        app.buttons["record.save"].tap()
        XCTAssertTrue(app.staticTexts["today.totalTime"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["today.totalTime"].label, "25分")
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["today.record.読書"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["today.totalTime"].label, "25分")
        app.tabBars.buttons["積み重ね"].tap()
        XCTAssertEqual(app.staticTexts["progress.totalTime"].label, "25分")
        app.tabBars.buttons["今日"].tap()
        app.buttons["today.record.読書"].tap()
        app.segmentedControls["record.outcome"].buttons["できなかった"].tap()
        app.buttons["record.save"].tap()
        XCTAssertTrue(app.staticTexts["できなかった"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["today.totalTime"].label, "25分")
        app.tabBars.buttons["積み重ね"].tap()
        XCTAssertEqual(app.staticTexts["progress.totalTime"].label, "25分")
        XCTAssertEqual(app.staticTexts["progress.completionRate"].label, "0%")
    }

    @MainActor
    func testSampleScreens() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["today.totalTime"].waitForExistence(timeout: 10))
        capture("Today", app: app)
        app.tabBars.buttons["ルーティン"].tap()
        XCTAssertTrue(app.buttons["routine.add"].waitForExistence(timeout: 5))
        capture("Routines", app: app)
        app.buttons["routine.add"].tap()
        XCTAssertTrue(app.buttons["routine.template.読書"].waitForExistence(timeout: 5))
        app.buttons["routine.template.読書"].tap()
        capture("RoutineEditor", app: app)
        app.buttons["キャンセル"].tap()
        app.tabBars.buttons["積み重ね"].tap()
        XCTAssertTrue(app.staticTexts["progress.totalTime"].waitForExistence(timeout: 5))
        capture("Progress", app: app)
        app.segmentedControls["progress.period"].buttons["全期間"].tap()
        capture("AllTime", app: app)
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
