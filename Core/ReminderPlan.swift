import Foundation

public struct ReminderSpec: Identifiable, Equatable, Sendable {
    public var id: String
    public var routineID: UUID
    public var title: String
    /// Foundation weekday convention: Sunday 1, Monday 2, ... Saturday 7.
    public var weekday: Int
    public var hour: Int
    public var minute: Int
    public var targetMinutes: Int

    public init(id: String, routineID: UUID, title: String, weekday: Int, hour: Int, minute: Int, targetMinutes: Int) {
        self.id = id
        self.routineID = routineID
        self.title = title
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.targetMinutes = targetMinutes
    }
}

public enum ReminderPlan {
    /// Pure weekly notification planning. Limits and permission are handled by the app.
    public static func requests(data: HabitData, on day: String) -> [ReminderSpec] {
        guard HabitCalendar.isValidDay(day) else { return [] }
        var requests: [ReminderSpec] = []
        for routine in data.routines where routine.archivedDay == nil && routine.reminderEnabled == true && !routine.preferredTime.isEmpty {
            let parts = routine.preferredTime.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0...23).contains(hour), (0...59).contains(minute) else { continue }
            for weekday in Set(routine.weekdays(on: day)) where (1...7).contains(weekday) {
                requests.append(ReminderSpec(
                    id: "kasane.reminder.\(routine.id.uuidString).\(weekday)",
                    routineID: routine.id, title: routine.title, weekday: weekday % 7 + 1,
                    hour: hour, minute: minute, targetMinutes: routine.targetMinutes
                ))
            }
        }
        return requests.sorted {
            if $0.title != $1.title { return $0.title < $1.title }
            if $0.routineID != $1.routineID { return $0.routineID.uuidString < $1.routineID.uuidString }
            return $0.weekday < $1.weekday
        }
    }
}
