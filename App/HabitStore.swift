import Foundation
import Observation

@Observable @MainActor
final class HabitStore {
    private(set) var data = HabitData()
    var errorMessage: String?
    var showTimer = false
    private(set) var readOnly = false
    let isDemo: Bool
    private let repository: HabitRepository
    private let reminders: ReminderScheduler
    var reminderStatusMessage: String { reminders.statusMessage }
    var hasRecoveryBackup: Bool { FileManager.default.fileExists(atPath: repository.recoveryURL.path) }

    init() {
        let args = ProcessInfo.processInfo.arguments
        isDemo = args.contains("--demo")
        let testing = args.contains("--uitesting")
        reminders = ReminderScheduler(enabled: !isDemo && !testing)
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent(testing ? "KasaneUITests" : "Kasane", isDirectory: true)
        let url = folder.appendingPathComponent("habits.json")
        repository = HabitRepository(url: url)
        do {
            if testing && args.contains("--reset-data") && FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            if isDemo { data = DemoData.make() }
            else {
                data = try repository.load()
                if testing && args.contains("--sample-data") && data.routines.isEmpty {
                    data = DemoData.make()
                    try repository.save(data)
                }
            }
        } catch {
            readOnly = true
            errorMessage = "記録を読み込めませんでした。元のファイルを保護するため保存を停止しています。\n\(error.localizedDescription)"
        }
    }

    @discardableResult
    private func commit(_ next: HabitData) -> Bool {
        guard !readOnly else {
            errorMessage = "データを読み込めないため保存できません。アプリを再起動して確認してください。"
            return false
        }
        do {
            if !isDemo { try repository.save(next) }
            data = next
            errorMessage = nil
            reminders.synchronize(next)
            return true
        } catch {
            errorMessage = "変更を保存できませんでした。入力内容を確認して、もう一度お試しください。\n\(error.localizedDescription)"
            return false
        }
    }

    func routines(on day: String) -> [Routine] {
        data.routines.filter { routine in
            routine.isScheduled(on: day) || data.records.contains { $0.routineID == routine.id && $0.day == day }
        }.sorted {
            let a = $0.preferredTime.isEmpty ? "99:99" : $0.preferredTime
            let b = $1.preferredTime.isEmpty ? "99:99" : $1.preferredTime
            return a == b ? $0.title < $1.title : a < b
        }
    }

    func record(for routine: Routine, day: String) -> DailyRecord? {
        data.records.first { $0.routineID == routine.id && $0.day == day }
    }

    @discardableResult
    func saveRoutine(_ routine: Routine) -> Bool {
        var next = data
        if let index = next.routines.firstIndex(where: { $0.id == routine.id }) { next.routines[index] = routine }
        else { next.routines.append(routine) }
        let notificationCount = ReminderPlan.requests(data: next, on: HabitCalendar.dayKey(Date())).count
        if notificationCount > 60 && notificationCount > ReminderPlan.requests(data: data, on: HabitCalendar.dayKey(Date())).count {
            errorMessage = "通知は曜日ごとに合計60件まで設定できます。ほかの通知をオフにするか、通知する曜日を減らしてください。"
            return false
        }
        return commit(next)
    }

    @discardableResult
    func archiveRoutine(_ routine: Routine) -> Bool {
        guard routine.archivedDay == nil else { return true }
        guard data.timer?.routineID != routine.id else {
            errorMessage = "このルーティンは計測中です。タイマーを終了してから休止してください。"
            return false
        }
        let today = HabitCalendar.dayKey(Date())
        var edited = routine
        edited.archivedDay = today
        edited.pausedWeekdays = routine.weekdays(on: today)
        edited.schedules.removeAll { $0.effectiveDay == today }
        edited.schedules.append(ScheduleRevision(effectiveDay: today, weekdays: []))
        return saveRoutine(edited)
    }

    @discardableResult
    func restoreRoutine(_ routine: Routine) -> Bool {
        guard routine.archivedDay != nil else { return true }
        let today = HabitCalendar.dayKey(Date())
        var edited = routine
        let weekdays = routine.pausedWeekdays ?? routine.schedules.sorted { $0.effectiveDay < $1.effectiveDay }.last(where: { !$0.weekdays.isEmpty })?.weekdays ?? [1, 2, 3, 4, 5, 6, 7]
        edited.archivedDay = nil
        edited.pausedWeekdays = nil
        edited.schedules.removeAll { $0.effectiveDay == today }
        edited.schedules.append(ScheduleRevision(effectiveDay: today, weekdays: weekdays))
        return saveRoutine(edited)
    }

    @discardableResult
    func saveRecord(routine: Routine, day: String, outcome: Outcome, seconds: Int, note: String) -> Bool {
        guard day <= HabitCalendar.dayKey(Date()) else { errorMessage = "未来の日付には記録できません。"; return false }
        var next = data
        let previous = record(for: routine, day: day)
        next.records.removeAll { $0.routineID == routine.id && $0.day == day }
        next.records.append(DailyRecord(id: previous?.id ?? UUID(), routineID: routine.id, day: day, outcome: outcome, seconds: seconds, note: note))
        return commit(next)
    }

    @discardableResult
    func clearRecord(routine: Routine, day: String) -> Bool {
        var next = data
        next.records.removeAll { $0.routineID == routine.id && $0.day == day }
        return commit(next)
    }

    func startTimer(for routine: Routine) {
        if data.timer != nil { showTimer = true; return }
        var next = data
        next.timer = ActiveTimer(routineID: routine.id, day: HabitCalendar.dayKey(Date()), startedAt: Date(), accumulatedSeconds: 0)
        if commit(next) { showTimer = true }
    }

    @discardableResult
    func finishTimer(outcome: Outcome) -> Bool {
        guard let timer = data.timer, let routine = data.routines.first(where: { $0.id == timer.routineID }) else { return false }
        var next = data
        let previous = record(for: routine, day: timer.day)
        next.records.removeAll { $0.routineID == timer.routineID && $0.day == timer.day }
        let (sum, overflow) = (previous?.seconds ?? 0).addingReportingOverflow(timer.elapsed(at: Date()))
        next.records.append(DailyRecord(id: previous?.id ?? UUID(), routineID: timer.routineID, day: timer.day,
                                       outcome: outcome, seconds: overflow ? Int.max : sum, note: previous?.note ?? ""))
        next.timer = nil
        if commit(next) { showTimer = false; return true }
        return false
    }

    func cancelTimer() {
        var next = data
        next.timer = nil
        if commit(next) { showTimer = false }
    }

    func pauseTimer() {
        guard data.timer != nil else { return }
        var next = data
        next.timer?.pause(at: Date())
        _ = commit(next)
    }

    func resumeTimer() {
        guard data.timer != nil else { return }
        var next = data
        next.timer?.resume(at: Date())
        _ = commit(next)
    }

    func refreshReminders() async {
        await reminders.refreshStatus()
        if !readOnly { reminders.synchronize(data) }
    }

    func requestReminderPermission() async {
        await reminders.requestPermission()
        if !readOnly { reminders.synchronize(data) }
    }

    func recoveryData() throws -> HabitData {
        try repository.loadRecovery()
    }

    @discardableResult
    func restoreBackup(_ incoming: HabitData) -> Bool {
        guard data.timer == nil else {
            errorMessage = "計測中のタイマーを終了してから復元してください。"
            return false
        }
        do {
            var restored = incoming
            restored.timer = nil
            try restored.validate()
            if !isDemo { try repository.restore(restored) }
            data = restored
            readOnly = false
            errorMessage = nil
            reminders.synchronize(restored)
            return true
        } catch {
            errorMessage = "バックアップを復元できませんでした。現在の記録は変更していません。\n\(error.localizedDescription)"
            return false
        }
    }
}

enum DemoData {
    static func make() -> HabitData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let first = calendar.date(byAdding: .day, value: -35, to: today)!
        let start = HabitCalendar.dayKey(first)
        let everyDay = [1, 2, 3, 4, 5, 6, 7]
        let routines = [
            Routine(title: "朝のストレッチ", symbol: "figure.flexibility", colorKey: "green", targetMinutes: 10, preferredTime: "07:00", createdDay: start, schedules: [ScheduleRevision(effectiveDay: start, weekdays: everyDay)]),
            Routine(title: "本を読む", symbol: "book.closed", colorKey: "orange", targetMinutes: 20, preferredTime: "21:00", createdDay: start, schedules: [ScheduleRevision(effectiveDay: start, weekdays: everyDay)]),
            Routine(title: "英語にふれる", symbol: "text.bubble", colorKey: "blue", targetMinutes: 15, preferredTime: "21:30", createdDay: start, schedules: [ScheduleRevision(effectiveDay: start, weekdays: everyDay)])
        ]
        var data = HabitData()
        data.routines = routines
        for offset in 0..<36 {
            let date = calendar.date(byAdding: .day, value: offset, to: first)!
            let day = HabitCalendar.dayKey(date)
            for (index, routine) in routines.enumerated() {
                if offset == 35 && index != 0 { continue }
                if (offset + index) % 9 == 0 { continue }
                let done = offset == 35 || (offset + index) % 7 != 0
                data.records.append(DailyRecord(routineID: routine.id, day: day, outcome: done ? .done : .missed,
                                                seconds: done ? (routine.targetMinutes + offset % 4) * 60 : 5 * 60, note: ""))
            }
        }
        return data
    }
}
