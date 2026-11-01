import Foundation
import XCTest
@testable import KasaneCore

final class ExpansionCoreTests: XCTestCase {
    private func routine(title: String = "読書", weekdays: [Int] = Array(1...7), createdDay: String = "2026-10-05") -> Routine {
        Routine(title: title, createdDay: createdDay, schedules: [ScheduleRevision(effectiveDay: createdDay, weekdays: weekdays)])
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("KasaneExpansionTests-\(UUID().uuidString)", isDirectory: true).appendingPathComponent("habits.json")
    }

    func testNewOptionalFieldsDecodeOldSchemaOneJSON() throws {
        let item = routine()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let timer = ActiveTimer(routineID: item.id, day: "2026-10-05", startedAt: start)
        let oldData = HabitData(routines: [item], timer: timer)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(oldData)) as? [String: Any])
        var routines = try XCTUnwrap(json["routines"] as? [[String: Any]])
        routines[0].removeValue(forKey: "weeklyGoalMinutes")
        routines[0].removeValue(forKey: "reminderEnabled")
        json["routines"] = routines
        var oldTimer = try XCTUnwrap(json["timer"] as? [String: Any])
        oldTimer.removeValue(forKey: "pausedAt")
        json["timer"] = oldTimer
        let decoded = try JSONDecoder().decode(HabitData.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.routines[0].weeklyGoalMinutes)
        XCTAssertNil(decoded.routines[0].reminderEnabled)
        XCTAssertNil(decoded.timer?.pausedAt)
        try decoded.validate()
    }

    func testWeeklyGoalValidationAndRoundTrip() throws {
        var item = routine()
        item.reminderEnabled = true
        for validGoal in [1, 180, 10_080] {
            item.weeklyGoalMinutes = validGoal
            let data = HabitData(routines: [item])
            try data.validate()
            XCTAssertEqual(try JSONDecoder().decode(HabitData.self, from: JSONEncoder().encode(data)), data)
        }
        for invalidGoal in [-1, 0, 10_081] {
            item.weeklyGoalMinutes = invalidGoal
            XCTAssertThrowsError(try HabitData(routines: [item]).validate())
        }
    }

    func testTimerMultiplePausesSurviveRelaunchWithoutCountingPausedTime() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var timer = ActiveTimer(routineID: UUID(), day: "2026-10-05", startedAt: start, accumulatedSeconds: 12)
        timer.pause(at: start.addingTimeInterval(30))
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(3_000)), 42)
        timer.pause(at: start.addingTimeInterval(45))
        XCTAssertEqual(timer.pausedAt, start.addingTimeInterval(30))
        timer = try JSONDecoder().decode(ActiveTimer.self, from: JSONEncoder().encode(timer))
        timer.resume(at: start.addingTimeInterval(100))
        timer.resume(at: start.addingTimeInterval(105)) // Repeated resume must not reset progress.
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(110)), 52)
        timer.pause(at: start.addingTimeInterval(115))
        timer = try JSONDecoder().decode(ActiveTimer.self, from: JSONEncoder().encode(timer))
        timer.resume(at: start.addingTimeInterval(200))
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(205)), 62)
        XCTAssertEqual(timer.day, "2026-10-05")
    }

    func testTimerPreservesFractionalSecondsAndHandlesClockMovingBack() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var timer = ActiveTimer(routineID: UUID(), startedAt: start)
        timer.pause(at: start.addingTimeInterval(0.75))
        timer.resume(at: start.addingTimeInterval(10))
        timer.pause(at: start.addingTimeInterval(10.75))
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(100)), 1)
        timer.resume(at: start.addingTimeInterval(5))
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(6)), 2)
    }

    func testPausedTimerValidation() {
        let item = routine()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let invalid = ActiveTimer(routineID: item.id, startedAt: start, pausedAt: start.addingTimeInterval(-1))
        XCTAssertThrowsError(try HabitData(routines: [item], timer: invalid).validate())
    }

    func testStreakSkipsOffDaysAndOnlyGivesLastDayGrace() {
        let item = routine(weekdays: [1, 3, 5])
        let data = HabitData(routines: [item], records: [
            DailyRecord(routineID: item.id, day: "2026-10-05"),
            DailyRecord(routineID: item.id, day: "2026-10-07")
        ])
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-09"), HabitStreak(current: 2, best: 2))
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-10"), HabitStreak(current: 0, best: 2))
    }

    func testStreakCountsUnscheduledActualRecordsAndMissesBreakIt() {
        let item = routine(weekdays: [1, 5])
        var data = HabitData(routines: [item], records: [
            DailyRecord(routineID: item.id, day: "2026-10-05"),
            DailyRecord(routineID: item.id, day: "2026-10-06")
        ])
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-07"), HabitStreak(current: 2, best: 2))
        data.records.append(DailyRecord(routineID: item.id, day: "2026-10-07", outcome: .missed))
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-07"), HabitStreak(current: 0, best: 2))
        data.records.append(DailyRecord(routineID: item.id, day: "2026-10-09"))
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-09"), HabitStreak(current: 1, best: 2))
    }

    func testStreakKeepsHistoryAcrossPauseAndScheduleChanges() {
        var item = routine()
        item.schedules.append(ScheduleRevision(effectiveDay: "2026-10-07", weekdays: []))
        item.schedules.append(ScheduleRevision(effectiveDay: "2026-10-10", weekdays: [6]))
        let data = HabitData(routines: [item], records: ["2026-10-05", "2026-10-06", "2026-10-10"].map { DailyRecord(routineID: item.id, day: $0) })
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-12"), HabitStreak(current: 3, best: 3))
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-04"), HabitStreak())
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: UUID(), through: "2026-10-12"), HabitStreak())
    }

    func testStreakBestIsRetainedWhenPastPendingBreaksCurrentRun() {
        let item = routine()
        let data = HabitData(routines: [item], records: ["2026-10-05", "2026-10-06", "2026-10-07", "2026-10-09"].map { DailyRecord(routineID: item.id, day: $0) })
        XCTAssertEqual(HabitAnalytics.streak(data: data, routineID: item.id, through: "2026-10-10"), HabitStreak(current: 1, best: 3))
    }

    func testBackupRoundTripPreservesHistoryAndOmitsTimer() throws {
        var item = routine()
        item.weeklyGoalMinutes = 90
        item.reminderEnabled = true
        let timer = ActiveTimer(routineID: item.id, day: "2026-10-05", startedAt: Date(timeIntervalSinceReferenceDate: 1_000), pausedAt: Date(timeIntervalSinceReferenceDate: 1_010))
        var data = HabitData(routines: [item], records: [DailyRecord(routineID: item.id, day: "2026-10-05", seconds: 250, note: "読了")], timer: timer)
        let decoded = try HabitTransfer.decodeBackup(HabitTransfer.encodeBackup(data))
        data.timer = nil
        XCTAssertEqual(decoded, data)
        let legacyWithTimer = HabitData(routines: [item], timer: timer)
        XCTAssertNil(try HabitTransfer.decodeBackup(JSONEncoder().encode(legacyWithTimer)).timer)
    }

    func testBackupRejectsOversizeMalformedFutureAndInvalidData() throws {
        XCTAssertThrowsError(try HabitTransfer.decodeBackup(Data(repeating: 32, count: HabitTransfer.maximumBackupBytes + 1)))
        XCTAssertThrowsError(try HabitTransfer.decodeBackup(Data("{broken".utf8)))
        let item = routine()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let future = HabitData(routines: [item], records: [DailyRecord(routineID: item.id, day: HabitCalendar.dayKey(tomorrow))])
        XCTAssertThrowsError(try HabitTransfer.decodeBackup(JSONEncoder().encode(future)))
        let negative = HabitData(routines: [item], records: [DailyRecord(routineID: item.id, day: "2026-10-05", seconds: -1)])
        XCTAssertThrowsError(try HabitTransfer.decodeBackup(JSONEncoder().encode(negative)))
        XCTAssertThrowsError(try HabitTransfer.decodeBackup(JSONEncoder().encode(HabitData(schemaVersion: 2))))
    }

    func testCSVIncludesBOMQuotesMultilineAndEscapesFormulas() {
        let item = routine(title: " \t=1+1,\"読書\"")
        let record = DailyRecord(routineID: item.id, day: "2026-10-05", outcome: .missed, seconds: 90, note: "1行目\n\"2行目\",続き")
        let csv = HabitTransfer.csv(HabitData(routines: [item], records: [record]))
        XCTAssertEqual(Array(csv.utf8.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}日付,ルーティン,結果,実施秒,実施分,メモ\r\n"))
        XCTAssertTrue(csv.contains("\"' \t=1+1,\"\"読書\"\"\""))
        XCTAssertTrue(csv.contains("\"できなかった\",\"90\",\"1.50\""))
        XCTAssertTrue(csv.contains("\"1行目\n\"\"2行目\"\",続き\""))
        for formula in ["=SUM(A1)", "  +1", "\t-2", "\r@command", "\u{FEFF} =1"] {
            let record = DailyRecord(routineID: item.id, day: "2026-10-05", note: formula)
            XCTAssertTrue(HabitTransfer.csv(HabitData(routines: [item], records: [record])).contains("\"'" + formula + "\""), formula)
        }
    }

    func testCSVOrderIsStableByDateThenTitle() {
        let a = routine(title: "A")
        let b = routine(title: "B")
        let records = [DailyRecord(routineID: b.id, day: "2026-10-06"), DailyRecord(routineID: b.id, day: "2026-10-05"), DailyRecord(routineID: a.id, day: "2026-10-05")]
        let first = HabitTransfer.csv(HabitData(routines: [a, b], records: records))
        let second = HabitTransfer.csv(HabitData(routines: [b, a], records: Array(records.reversed())))
        XCTAssertEqual(first, second)
        let rows = first.components(separatedBy: "\r\n")
        XCTAssertTrue(rows[1].hasPrefix("\"2026-10-05\",\"A\""))
        XCTAssertTrue(rows[2].hasPrefix("\"2026-10-05\",\"B\""))
        XCTAssertTrue(rows[3].hasPrefix("\"2026-10-06\",\"B\""))
    }

    func testRestoreKeepsExactPriorFileAndRecoveryCanBeLoaded() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = HabitRepository(url: url)
        let original = HabitData(routines: [routine(title: "元の習慣")])
        try repository.save(original)
        let originalBytes = try Data(contentsOf: url)
        let replacement = HabitData(routines: [routine(title: "取り込んだ習慣")])
        try repository.restore(replacement)
        XCTAssertEqual(try repository.load(), replacement)
        XCTAssertEqual(try repository.loadRecovery(), original)
        XCTAssertEqual(try Data(contentsOf: repository.recoveryURL), originalBytes)
    }

    func testRestoreProtectsMainFileWhenValidationOrRecoveryCopyFails() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = HabitRepository(url: url)
        let original = HabitData(routines: [routine()])
        try repository.save(original)
        let bytes = try Data(contentsOf: url)
        XCTAssertThrowsError(try repository.restore(HabitData(schemaVersion: 2)))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.recoveryURL.path))
        try FileManager.default.createDirectory(at: repository.recoveryURL, withIntermediateDirectories: false)
        XCTAssertThrowsError(try repository.restore(HabitData()))
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testRestorePreservesCorruptOriginalBytesAndMissingRecoveryThrows() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = HabitRepository(url: url)
        XCTAssertThrowsError(try repository.loadRecovery())
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let broken = Data("{damaged".utf8)
        try broken.write(to: url)
        try repository.restore(HabitData())
        XCTAssertEqual(try repository.load(), HabitData())
        XCTAssertEqual(try Data(contentsOf: repository.recoveryURL), broken)
        XCTAssertThrowsError(try repository.loadRecovery())
    }

    func testReminderWeekdayMappingIdentifiersAndStableOrdering() {
        var item = routine(weekdays: [1, 7])
        item.preferredTime = "08:35"
        item.reminderEnabled = true
        let requests = ReminderPlan.requests(data: HabitData(routines: [item]), on: "2026-10-05")
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.map(\.weekday), [1, 2])
        XCTAssertEqual(requests[0].id, "kasane.reminder.\(item.id.uuidString).7")
        XCTAssertEqual(requests[1].id, "kasane.reminder.\(item.id.uuidString).1")
        XCTAssertTrue(requests.allSatisfy { $0.hour == 8 && $0.minute == 35 && $0.targetMinutes == item.targetMinutes })
        var another = routine(title: "A", weekdays: [3])
        another.reminderEnabled = true
        let data = HabitData(routines: [item, another])
        let reverse = HabitData(routines: [another, item])
        XCTAssertEqual(ReminderPlan.requests(data: data, on: "2026-10-05"), ReminderPlan.requests(data: reverse, on: "2026-10-05"))
        XCTAssertEqual(ReminderPlan.requests(data: data, on: "2026-10-05").first?.title, "A")
    }

    func testReminderExcludesPausedUntimedDisabledAndUsesCurrentSchedule() {
        var archived = routine()
        archived.reminderEnabled = true
        archived.archivedDay = "2026-10-05"
        var noTime = routine()
        noTime.reminderEnabled = true
        noTime.preferredTime = ""
        var off = routine()
        off.reminderEnabled = false
        var paused = routine()
        paused.reminderEnabled = true
        paused.schedules.append(ScheduleRevision(effectiveDay: "2026-10-06", weekdays: []))
        let data = HabitData(routines: [archived, noTime, off, routine(), paused])
        XCTAssertTrue(ReminderPlan.requests(data: data, on: "2026-10-06").isEmpty)
        XCTAssertEqual(ReminderPlan.requests(data: data, on: "2026-10-05").count, 7)
    }
}
