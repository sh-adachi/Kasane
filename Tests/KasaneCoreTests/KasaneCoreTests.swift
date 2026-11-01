import Foundation
import XCTest
@testable import KasaneCore

final class KasaneCoreTests: XCTestCase {
    private func routine(weekdays: [Int] = [1, 3, 5], createdDay: String = "2026-10-01") -> Routine {
        Routine(title: "読書", createdDay: createdDay, schedules: [ScheduleRevision(effectiveDay: createdDay, weekdays: weekdays)])
    }

    private func calendar(_ zone: String = "Asia/Tokyo") -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: zone)!
        return result
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("KasaneCoreTests-\(UUID().uuidString)", isDirectory: true).appendingPathComponent("habits.json")
    }

    func testMondayFirstWeekCrossesYearBoundary() {
        let tokyo = calendar()
        let days = HabitCalendar.weekDays(containing: HabitCalendar.date("2027-01-01", calendar: tokyo), calendar: tokyo)
        XCTAssertEqual(days.map { HabitCalendar.dayKey($0, calendar: tokyo) }, ["2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03"])
        XCTAssertEqual(HabitCalendar.weekday("2026-10-05"), 1)
        XCTAssertEqual(HabitCalendar.weekday("2026-10-11"), 7)
    }

    func testWeekDatesRemainLocalAcrossDaylightSavingTransition() {
        let losAngeles = calendar("America/Los_Angeles")
        let days = HabitCalendar.weekDays(containing: HabitCalendar.date("2026-11-01", calendar: losAngeles), calendar: losAngeles)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map { HabitCalendar.dayKey($0, calendar: losAngeles) }, ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"])
        XCTAssertTrue(days.allSatisfy { losAngeles.component(.hour, from: $0) == 0 })
        XCTAssertEqual(HabitCalendar.days(from: "2026-10-31", through: "2026-11-02"), ["2026-10-31", "2026-11-01", "2026-11-02"])
    }

    func testDayKeysRemainGregorianWithAlternativeDeviceCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = HabitCalendar.date("2026-10-11", calendar: buddhist)
        XCTAssertEqual(HabitCalendar.dayKey(date, calendar: buddhist), "2026-10-11")
    }

    func testStrictDatesRejectNormalizedAndMalformedInput() {
        XCTAssertTrue(HabitCalendar.isValidDay("2024-02-29"))
        for invalid in ["2026-02-29", "2026-04-31", "2026-2-01", "26-10-01", "2026-00-01", "2026-13-01", "2026-10-00", "2026-10-32", "0000-01-01", "2026-10-01Z", "abcd-ef-gh", ""] {
            XCTAssertFalse(HabitCalendar.isValidDay(invalid), invalid)
            XCTAssertEqual(HabitCalendar.weekday(invalid), 0)
        }
    }

    func testScheduleRevisionsPreserveEarlierWeekdaysAndAllowPause() throws {
        var item = routine(weekdays: [1, 3, 5], createdDay: "2026-10-05")
        item.schedules.append(ScheduleRevision(effectiveDay: "2026-10-08", weekdays: [2, 4]))
        item.schedules.append(ScheduleRevision(effectiveDay: "2026-10-12", weekdays: []))
        item.schedules.append(ScheduleRevision(effectiveDay: "2026-10-19", weekdays: [1]))
        item.schedules.reverse() // Evaluation does not depend on storage order.
        XCTAssertFalse(item.isScheduled(on: "2026-10-02"))
        XCTAssertTrue(item.isScheduled(on: "2026-10-05"))
        XCTAssertTrue(item.isScheduled(on: "2026-10-07"))
        XCTAssertTrue(item.isScheduled(on: "2026-10-08"))
        XCTAssertFalse(item.isScheduled(on: "2026-10-09"))
        XCTAssertFalse(item.isScheduled(on: "2026-10-13"))
        XCTAssertTrue(item.isScheduled(on: "2026-10-19"))
        try HabitData(routines: [item]).validate()
    }

    func testSummaryIncludesPendingAndUnscheduledActualRecords() {
        let item = routine()
        let records = [
            DailyRecord(routineID: item.id, day: "2026-10-05", outcome: .done, seconds: 1_200),
            DailyRecord(routineID: item.id, day: "2026-10-07", outcome: .missed, seconds: 300),
            DailyRecord(routineID: item.id, day: "2026-10-10", outcome: .done, seconds: 600)
        ]
        let data = HabitData(routines: [item], records: records)
        let summary = HabitAnalytics.summary(data: data, from: "2026-10-05", through: "2026-10-11")
        XCTAssertEqual(summary.done, 2)
        XCTAssertEqual(summary.missed, 1)
        XCTAssertEqual(summary.pending, 1)
        XCTAssertEqual(summary.seconds, 2_100)
        XCTAssertEqual(summary.completionRate, 0.5)
        let untilWednesday = HabitAnalytics.summary(data: data, from: "2026-10-05", through: "2026-10-07")
        XCTAssertEqual(untilWednesday.pending, 0)
        XCTAssertEqual(untilWednesday.completionRate, 0.5)
    }

    func testArchiveExcludesScheduleOnArchiveDateButRetainsActualRecords() {
        var item = routine(weekdays: Array(1...7))
        item.archivedDay = "2026-10-07"
        let record = DailyRecord(routineID: item.id, day: "2026-10-08", outcome: .done, seconds: 900)
        let data = HabitData(routines: [item], records: [record])
        XCTAssertFalse(item.isScheduled(on: "2026-10-07"))
        let summary = HabitAnalytics.summary(data: data, from: "2026-10-05", through: "2026-10-11")
        XCTAssertEqual(summary, HabitSummary(done: 1, missed: 0, pending: 2, seconds: 900))
        XCTAssertEqual(summary.completionRate, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testAggregationFiltersRoutinesAndKeepsRequestedDayOrder() {
        let first = routine()
        let second = routine(weekdays: [2])
        let data = HabitData(routines: [first, second], records: [
            DailyRecord(routineID: first.id, day: "2026-10-05", seconds: 60),
            DailyRecord(routineID: first.id, day: "2026-10-06", outcome: .missed, seconds: 30),
            DailyRecord(routineID: second.id, day: "2026-10-06", seconds: 120)
        ])
        let days = ["2026-10-06", "2026-10-05", "2026-10-07"]
        XCTAssertEqual(HabitAnalytics.dailySeconds(data: data, days: days), [150, 60, 0])
        XCTAssertEqual(HabitAnalytics.dailySeconds(data: data, days: days, routineID: first.id), [30, 60, 0])
        XCTAssertEqual(HabitAnalytics.totalSeconds(data: data), 210)
        XCTAssertEqual(HabitAnalytics.totalSeconds(data: data, routineID: first.id), 90)
        XCTAssertEqual(HabitAnalytics.summary(data: data, from: "2026-10-05", through: "2026-10-06", routineID: second.id), HabitSummary(done: 1, seconds: 120))
    }

    func testEmptyAndReversedRangesHaveZeroRates() {
        XCTAssertEqual(HabitAnalytics.summary(data: HabitData(), from: "2026-10-05", through: "2026-10-11").completionRate, 0)
        XCTAssertEqual(HabitAnalytics.summary(data: HabitData(routines: [routine()]), from: "2026-10-11", through: "2026-10-05"), HabitSummary())
        XCTAssertEqual(HabitAnalytics.summary(data: HabitData(routines: [routine()]), from: "invalid", through: "2026-10-05"), HabitSummary())
    }

    func testTimerRestoresElapsedTimeAndKeepsStartDayAfterMidnight() {
        let tokyo = calendar()
        let start = HabitCalendar.date("2026-10-11", calendar: tokyo).addingTimeInterval(-30)
        let timer = ActiveTimer(routineID: UUID(), day: "2026-10-10", startedAt: start, accumulatedSeconds: 15)
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(90.9)), 105)
        XCTAssertEqual(timer.day, "2026-10-10")
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(-20)), 15)
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(3_600)), 3_615)
    }

    func testTimerAndAggregationDoNotOverflow() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let timer = ActiveTimer(routineID: UUID(), startedAt: start, accumulatedSeconds: Int.max - 2)
        XCTAssertEqual(timer.elapsed(at: start.addingTimeInterval(10)), Int.max)
        let item = routine()
        let data = HabitData(routines: [item], records: [
            DailyRecord(routineID: item.id, day: "2026-10-05", seconds: Int.max),
            DailyRecord(routineID: item.id, day: "2026-10-06", seconds: 1)
        ])
        XCTAssertEqual(HabitAnalytics.totalSeconds(data: data), Int.max)
    }

    func testRepositoryRoundTripRestoresRecordsAndActiveTimer() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = HabitRepository(url: url)
        XCTAssertEqual(try repository.load(), HabitData())
        let item = routine()
        let data = HabitData(routines: [item], records: [DailyRecord(routineID: item.id, day: "2026-10-05", outcome: .missed, seconds: 150, note: "少しだけ進めた")], timer: ActiveTimer(routineID: item.id, day: "2026-10-11", startedAt: Date(timeIntervalSinceReferenceDate: 813_123_456.123456), accumulatedSeconds: 100))
        try repository.save(data)
        XCTAssertEqual(try repository.load(), data)
    }

    func testValidationRejectsDuplicateDaysNegativeTimeAndDanglingReferences() {
        let item = routine()
        let record = DailyRecord(routineID: item.id, day: "2026-10-05", seconds: 10)
        var duplicate = record
        duplicate.id = UUID()
        XCTAssertThrowsError(try HabitData(routines: [item], records: [record, duplicate]).validate())
        XCTAssertThrowsError(try HabitData(routines: [item, item]).validate())
        XCTAssertThrowsError(try HabitData(records: [record]).validate())
        var negative = record
        negative.seconds = -1
        XCTAssertThrowsError(try HabitData(routines: [item], records: [negative]).validate())
        var badDay = record
        badDay.day = "2026-02-30"
        XCTAssertThrowsError(try HabitData(routines: [item], records: [badDay]).validate())
        XCTAssertThrowsError(try HabitData(routines: [item], timer: ActiveTimer(routineID: UUID())).validate())
        XCTAssertThrowsError(try HabitData(routines: [item], timer: ActiveTimer(routineID: item.id, accumulatedSeconds: -1)).validate())
        XCTAssertThrowsError(try HabitData(schemaVersion: 2).validate())
    }

    func testValidationRejectsMalformedSchedulesAndTime() {
        var item = routine()
        item.schedules[0].weekdays = [0, 1, 7]
        XCTAssertThrowsError(try HabitData(routines: [item]).validate())
        item.schedules[0].weekdays = [1, 1]
        XCTAssertThrowsError(try HabitData(routines: [item]).validate())
        item.schedules[0].weekdays = [1]
        item.schedules.append(item.schedules[0])
        XCTAssertThrowsError(try HabitData(routines: [item]).validate())
        item.schedules.removeLast()
        for time in ["25:00", "12:60", "7:00", "01-00"] {
            item.preferredTime = time
            XCTAssertThrowsError(try HabitData(routines: [item]).validate(), time)
        }
    }

    func testInvalidSaveDoesNotReplaceExistingData() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = HabitRepository(url: url)
        let original = HabitData(routines: [routine()])
        try repository.save(original)
        let bytesBefore = try Data(contentsOf: url)
        var invalid = original
        invalid.routines[0].targetMinutes = -10
        XCTAssertThrowsError(try repository.save(invalid))
        XCTAssertEqual(try Data(contentsOf: url), bytesBefore)
        XCTAssertEqual(try repository.load(), original)
    }

    func testCorruptedFileIsReportedAndRemainsUntouched() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupted = Data("{broken".utf8)
        try corrupted.write(to: url)
        XCTAssertThrowsError(try HabitRepository(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), corrupted)
    }

    func testSemanticallyInvalidJSONIsRejectedDuringLoad() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let invalid = HabitData(records: [DailyRecord(routineID: UUID(), day: "2026-10-05")])
        try JSONEncoder().encode(invalid).write(to: url)
        XCTAssertThrowsError(try HabitRepository(url: url).load())
    }

    func testPausedWeekdaysPreserveSameDayScheduleAndDecodeOlderJSON() throws {
        var item = routine(weekdays: [2, 4], createdDay: "2026-10-05")
        item.pausedWeekdays = item.weekdays(on: "2026-10-05")
        item.archivedDay = "2026-10-05"
        item.schedules = [ScheduleRevision(effectiveDay: "2026-10-05", weekdays: [])]
        let paused = HabitData(routines: [item])
        try paused.validate()
        let restored = try JSONDecoder().decode(HabitData.self, from: JSONEncoder().encode(paused))
        XCTAssertEqual(restored.routines[0].pausedWeekdays, [2, 4])
        XCTAssertFalse(restored.routines[0].isScheduled(on: "2026-10-06"))

        let oldItem = routine()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(oldItem)) as? [String: Any])
        json.removeValue(forKey: "pausedWeekdays")
        let legacy = try JSONDecoder().decode(Routine.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.pausedWeekdays)
        XCTAssertEqual(legacy, oldItem)
    }

    func testPausedWeekdaysValidationRejectsInvalidValuesAndDuplicates() throws {
        var item = routine()
        for weekdays in [[0], [8], [1, 1], [-1, 5]] {
            item.pausedWeekdays = weekdays
            XCTAssertThrowsError(try HabitData(routines: [item]).validate())
        }
        item.pausedWeekdays = [2, 4, 6]
        try HabitData(routines: [item]).validate()
        item.pausedWeekdays = []
        try HabitData(routines: [item]).validate()
    }

    func testRoutineWithoutPreferredTimeCanBeSavedAndLoaded() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repository = HabitRepository(url: url)
        var item = routine()
        item.preferredTime = ""
        let data = HabitData(routines: [item])
        try repository.save(data)
        XCTAssertEqual(try repository.load(), data)
    }
}
