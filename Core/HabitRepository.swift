import Foundation

public enum HabitDataError: Error, LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): "このデータ形式（バージョン\(version)）には対応していません。"
        case .invalid(let reason): "保存データを確認できませんでした。\(reason)"
        }
    }
}

public extension HabitData {
    func validate() throws {
        guard schemaVersion == 1 else { throw HabitDataError.unsupportedSchema(schemaVersion) }
        var routineIDs = Set<UUID>()
        for routine in routines {
            guard routineIDs.insert(routine.id).inserted else { throw HabitDataError.invalid("習慣のIDが重複しています。") }
            guard !routine.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw HabitDataError.invalid("習慣の名前が空です。") }
            guard routine.targetMinutes > 0 else { throw HabitDataError.invalid("目標時間は1分以上にしてください。") }
            if let weeklyGoalMinutes = routine.weeklyGoalMinutes {
                guard (1...10_080).contains(weeklyGoalMinutes) else { throw HabitDataError.invalid("週間目標は1〜10,080分の範囲で指定してください。") }
            }
            guard HabitCalendar.isValidDay(routine.createdDay) else { throw HabitDataError.invalid("習慣の開始日が正しくありません。") }
            if let archived = routine.archivedDay {
                guard HabitCalendar.isValidDay(archived), archived >= routine.createdDay else { throw HabitDataError.invalid("習慣の終了日が正しくありません。") }
            }
            if let pausedWeekdays = routine.pausedWeekdays {
                guard pausedWeekdays.allSatisfy({ (1...7).contains($0) }), Set(pausedWeekdays).count == pausedWeekdays.count else { throw HabitDataError.invalid("休止前の曜日設定が正しくありません。") }
            }
            if !routine.preferredTime.isEmpty {
                let time = Array(routine.preferredTime.utf8)
                guard time.count == 5, time[2] == 58,
                      time.enumerated().allSatisfy({ $0.offset == 2 || (48...57).contains($0.element) }),
                      let hour = Int(routine.preferredTime.prefix(2)), (0...23).contains(hour),
                      let minute = Int(routine.preferredTime.suffix(2)), (0...59).contains(minute) else { throw HabitDataError.invalid("予定時刻が正しくありません。") }
            }
            guard !routine.schedules.isEmpty else { throw HabitDataError.invalid("曜日の設定がありません。") }
            var revisionDays = Set<String>()
            for revision in routine.schedules {
                guard HabitCalendar.isValidDay(revision.effectiveDay), revision.effectiveDay >= routine.createdDay,
                      revisionDays.insert(revision.effectiveDay).inserted else { throw HabitDataError.invalid("曜日設定の適用日が正しくありません。") }
                guard revision.weekdays.allSatisfy({ (1...7).contains($0) }), Set(revision.weekdays).count == revision.weekdays.count else { throw HabitDataError.invalid("曜日は月曜から日曜の範囲で指定してください。") }
            }
        }
        var recordIDs = Set<UUID>()
        var recordDays: [UUID: Set<String>] = [:]
        for record in records {
            guard recordIDs.insert(record.id).inserted else { throw HabitDataError.invalid("記録のIDが重複しています。") }
            guard routineIDs.contains(record.routineID) else { throw HabitDataError.invalid("記録に対応する習慣が見つかりません。") }
            guard HabitCalendar.isValidDay(record.day) else { throw HabitDataError.invalid("記録の日付が正しくありません。") }
            guard record.seconds >= 0 else { throw HabitDataError.invalid("実施時間は0秒以上にしてください。") }
            guard recordDays[record.routineID, default: []].insert(record.day).inserted else { throw HabitDataError.invalid("同じ日の記録が重複しています。") }
        }
        if let timer {
            guard routineIDs.contains(timer.routineID), HabitCalendar.isValidDay(timer.day),
                  timer.startedAt.timeIntervalSinceReferenceDate.isFinite,
                  timer.accumulatedSeconds >= 0 else { throw HabitDataError.invalid("計測中のタイマー情報が正しくありません。") }
            if let pausedAt = timer.pausedAt {
                guard pausedAt.timeIntervalSinceReferenceDate.isFinite, pausedAt >= timer.startedAt else { throw HabitDataError.invalid("タイマーの一時停止時刻が正しくありません。") }
            }
        }
    }
}

public struct HabitRepository: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public var recoveryURL: URL {
        url.deletingLastPathComponent().appendingPathComponent("before-restore.json")
    }

    public func load() throws -> HabitData {
        guard FileManager.default.fileExists(atPath: url.path) else { return HabitData() }
        let data = try JSONDecoder().decode(HabitData.self, from: Data(contentsOf: url))
        try data.validate()
        return data
    }

    public func save(_ data: HabitData) throws {
        try data.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let contents = try encoder.encode(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, options: .atomic)
    }

    /// Preserves the exact prior bytes, even when the current file is damaged.
    /// Any validation, recovery-copy, or atomic-save failure leaves the main file intact.
    public func restore(_ data: HabitData) throws {
        try data.validate()
        guard url.standardizedFileURL != recoveryURL.standardizedFileURL else {
            throw HabitDataError.invalid("保存先と復元用の控えは別のファイルにしてください。")
        }
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            try previous.write(to: recoveryURL, options: .atomic)
        }
        try save(data)
    }

    public func loadRecovery() throws -> HabitData {
        guard FileManager.default.fileExists(atPath: recoveryURL.path) else {
            throw HabitDataError.invalid("復元前の控えが見つかりません。")
        }
        let data = try JSONDecoder().decode(HabitData.self, from: Data(contentsOf: recoveryURL))
        try data.validate()
        return data
    }
}
