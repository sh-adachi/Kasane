import Foundation

public struct ScheduleRevision: Codable, Equatable, Sendable {
    public var effectiveDay: String
    public var weekdays: [Int]

    public init(effectiveDay: String = HabitCalendar.dayKey(Date()), weekdays: [Int] = Array(1...7)) {
        self.effectiveDay = effectiveDay
        self.weekdays = weekdays
    }
}

public struct Routine: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var symbol: String
    public var colorKey: String
    public var targetMinutes: Int
    public var preferredTime: String
    public var createdDay: String
    public var archivedDay: String?
    public var schedules: [ScheduleRevision]
    /// Preserves the active weekdays when a same-day revision is replaced by a pause.
    public var pausedWeekdays: [Int]?
    public var weeklyGoalMinutes: Int?
    public var reminderEnabled: Bool?

    public init(
        id: UUID = UUID(), title: String = "新しい習慣", symbol: String = "sparkles",
        colorKey: String = "sage", targetMinutes: Int = 15, preferredTime: String = "07:00",
        createdDay: String = HabitCalendar.dayKey(Date()), archivedDay: String? = nil,
        schedules: [ScheduleRevision]? = nil, pausedWeekdays: [Int]? = nil,
        weeklyGoalMinutes: Int? = nil, reminderEnabled: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.colorKey = colorKey
        self.targetMinutes = targetMinutes
        self.preferredTime = preferredTime
        self.createdDay = createdDay
        self.archivedDay = archivedDay
        self.schedules = schedules ?? [ScheduleRevision(effectiveDay: createdDay)]
        self.pausedWeekdays = pausedWeekdays
        self.weeklyGoalMinutes = weeklyGoalMinutes
        self.reminderEnabled = reminderEnabled
    }

    public func weekdays(on day: String) -> [Int] {
        schedules.filter { $0.effectiveDay <= day }.max { $0.effectiveDay < $1.effectiveDay }?.weekdays ?? []
    }

    public func isScheduled(on day: String) -> Bool {
        guard HabitCalendar.isValidDay(day), day >= createdDay,
              archivedDay.map({ day < $0 }) ?? true else { return false }
        return weekdays(on: day).contains(HabitCalendar.weekday(day))
    }
}

public enum Outcome: String, Codable, CaseIterable, Sendable {
    case done
    case missed
}

public struct DailyRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var routineID: UUID
    public var day: String
    public var outcome: Outcome
    public var seconds: Int
    public var note: String

    public init(id: UUID = UUID(), routineID: UUID, day: String = HabitCalendar.dayKey(Date()), outcome: Outcome = .done, seconds: Int = 0, note: String = "") {
        self.id = id
        self.routineID = routineID
        self.day = day
        self.outcome = outcome
        self.seconds = seconds
        self.note = note
    }
}

public struct ActiveTimer: Codable, Equatable, Sendable {
    public var routineID: UUID
    /// A session is attributed to the local civil date on which it began.
    public var day: String
    public var startedAt: Date
    public var accumulatedSeconds: Int
    public var pausedAt: Date?

    public init(routineID: UUID, day: String = HabitCalendar.dayKey(Date()), startedAt: Date = Date(), accumulatedSeconds: Int = 0, pausedAt: Date? = nil) {
        self.routineID = routineID
        self.day = day
        self.startedAt = startedAt
        self.accumulatedSeconds = accumulatedSeconds
        self.pausedAt = pausedAt
    }

    public func elapsed(at date: Date) -> Int {
        let interval = (pausedAt ?? date).timeIntervalSince(startedAt)
        let base = max(0, accumulatedSeconds)
        guard interval.isFinite, interval > 0 else { return base }
        if interval >= Double(Int.max - base) { return Int.max }
        return base + Int(interval.rounded(.down))
    }

    public mutating func pause(at date: Date) {
        guard pausedAt == nil, date.timeIntervalSinceReferenceDate.isFinite else { return }
        pausedAt = max(date, startedAt)
    }

    public mutating func resume(at date: Date) {
        guard let pausedAt, date.timeIntervalSinceReferenceDate.isFinite else { return }
        // Shift the virtual start rather than rounding into accumulatedSeconds,
        // so repeated short pauses do not discard fractional active seconds.
        let activeInterval = max(0, pausedAt.timeIntervalSince(startedAt))
        startedAt = date.addingTimeInterval(-activeInterval)
        self.pausedAt = nil
    }
}

public struct HabitData: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var routines: [Routine]
    public var records: [DailyRecord]
    public var timer: ActiveTimer?

    public init(schemaVersion: Int = 1, routines: [Routine] = [], records: [DailyRecord] = [], timer: ActiveTimer? = nil) {
        self.schemaVersion = schemaVersion
        self.routines = routines
        self.records = records
        self.timer = timer
    }
}

public struct HabitSummary: Equatable, Sendable {
    public var done: Int
    public var missed: Int
    public var pending: Int
    public var seconds: Int

    public init(done: Int = 0, missed: Int = 0, pending: Int = 0, seconds: Int = 0) {
        self.done = done
        self.missed = missed
        self.pending = pending
        self.seconds = seconds
    }

    public var completionRate: Double {
        let count = done + missed + pending
        return count > 0 ? Double(done) / Double(count) : 0
    }
}

public struct HabitStreak: Equatable, Sendable {
    public var current: Int
    public var best: Int

    public init(current: Int = 0, best: Int = 0) {
        self.current = current
        self.best = best
    }
}
