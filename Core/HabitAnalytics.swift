import Foundation

public enum HabitAnalytics {
    /// Counts successful opportunities, not consecutive calendar days.
    /// Non-scheduled days (including pauses) are skipped unless they have a record:
    /// an off-schedule done adds one and an off-schedule missed breaks the streak.
    /// Only an unrecorded `through` day receives a grace period; an explicit missed
    /// record still breaks the streak on that day.
    public static func streak(data: HabitData, routineID: UUID, through: String) -> HabitStreak {
        guard HabitCalendar.isValidDay(through),
              let routine = data.routines.first(where: { $0.id == routineID }) else { return HabitStreak() }
        let records = data.records.filter { $0.routineID == routineID && $0.day <= through }
        let lookup = Dictionary(records.map { ($0.day, $0) }, uniquingKeysWith: { _, latest in latest })
        let firstDay = min(routine.createdDay, records.map(\.day).min() ?? routine.createdDay)
        var result = HabitStreak()
        for day in HabitCalendar.days(from: firstDay, through: through) {
            if let record = lookup[day] {
                if record.outcome == .done {
                    result.current += 1
                    result.best = max(result.best, result.current)
                } else {
                    result.current = 0
                }
            } else if routine.isScheduled(on: day), day != through {
                result.current = 0
            }
        }
        return result
    }

    /// Includes scheduled days and any additional days with an actual record.
    /// The caller controls the end date so future days can be omitted from rates.
    public static func summary(data: HabitData, from: String, through: String, routineID: UUID? = nil) -> HabitSummary {
        let days = HabitCalendar.days(from: from, through: through)
        guard !days.isEmpty else { return HabitSummary() }
        let routines = data.routines.filter { routineID == nil || $0.id == routineID }
        let routineIDs = Set(routines.map(\.id))
        let records = data.records.filter { routineIDs.contains($0.routineID) && $0.day >= from && $0.day <= through }
        // A repository enforces uniqueness. Last value also makes draft data safe to inspect.
        let lookup = Dictionary(records.map { (RecordKey(routineID: $0.routineID, day: $0.day), $0) }, uniquingKeysWith: { _, newest in newest })
        var result = HabitSummary()
        for routine in routines {
            for day in days {
                if let record = lookup[RecordKey(routineID: routine.id, day: day)] {
                    if record.outcome == .done { result.done += 1 } else { result.missed += 1 }
                    result.seconds = addingSeconds(result.seconds, record.seconds)
                } else if routine.isScheduled(on: day) {
                    result.pending += 1
                }
            }
        }
        return result
    }

    public static func dailySeconds(data: HabitData, days: [String], routineID: UUID? = nil) -> [Int] {
        var totals: [String: Int] = [:]
        let requestedDays = Set(days)
        for record in data.records where requestedDays.contains(record.day) && (routineID == nil || record.routineID == routineID) {
            totals[record.day] = addingSeconds(totals[record.day, default: 0], record.seconds)
        }
        return days.map { totals[$0, default: 0] }
    }

    public static func totalSeconds(data: HabitData, routineID: UUID? = nil) -> Int {
        data.records.filter { routineID == nil || $0.routineID == routineID }.reduce(0) { addingSeconds($0, $1.seconds) }
    }

    private static func addingSeconds(_ first: Int, _ second: Int) -> Int {
        let (sum, overflow) = max(0, first).addingReportingOverflow(max(0, second))
        return overflow ? Int.max : sum
    }

    private struct RecordKey: Hashable {
        var routineID: UUID
        var day: String
    }
}
