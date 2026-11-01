import Foundation

public enum HabitTransfer {
    /// Decimal megabytes, measured before JSON decoding.
    public static let maximumBackupBytes = 10_000_000

    /// Exports the existing schema-1 JSON format without a live timer session.
    public static func encodeBackup(_ data: HabitData) throws -> Data {
        try data.validate()
        var backup = data
        backup.timer = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let raw = try encoder.encode(backup)
        guard raw.count <= maximumBackupBytes else {
            throw HabitDataError.invalid("バックアップは10MB以内にしてください。")
        }
        return raw
    }

    /// A valid incoming timer is intentionally discarded so an imported session
    /// cannot start adding time. Future daily records are not accepted.
    public static func decodeBackup(_ raw: Data) throws -> HabitData {
        guard raw.count <= maximumBackupBytes else {
            throw HabitDataError.invalid("バックアップは10MB以内にしてください。")
        }
        var data = try JSONDecoder().decode(HabitData.self, from: raw)
        try data.validate()
        let today = HabitCalendar.dayKey(Date())
        guard data.records.allSatisfy({ $0.day <= today }) else {
            throw HabitDataError.invalid("未来の日付の記録は取り込めません。")
        }
        data.timer = nil
        return data
    }

    /// UTF-8 BOM, CRLF records and RFC-4180 quoting. Free-text values that could
    /// be interpreted as spreadsheet formulas are prefixed with an apostrophe.
    public static func csv(_ data: HabitData) -> String {
        let routines = Dictionary(data.routines.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let records = data.records.sorted { left, right in
            if left.day != right.day { return left.day < right.day }
            let leftTitle = routines[left.routineID]?.title ?? "不明なルーティン"
            let rightTitle = routines[right.routineID]?.title ?? "不明なルーティン"
            if leftTitle != rightTitle { return leftTitle < rightTitle }
            if left.routineID != right.routineID { return left.routineID.uuidString < right.routineID.uuidString }
            return left.id.uuidString < right.id.uuidString
        }
        var rows = ["日付,ルーティン,結果,実施秒,実施分,メモ"]
        for record in records {
            let minutes = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), Double(record.seconds) / 60)
            let fields = [record.day, routines[record.routineID]?.title ?? "不明なルーティン", record.outcome == .done ? "できた" : "できなかった", String(record.seconds), minutes, record.note]
            rows.append(fields.map(csvField).joined(separator: ","))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }

    private static func csvField(_ value: String) -> String {
        let ignoredLeading = CharacterSet.whitespacesAndNewlines.union(.controlCharacters).union(CharacterSet(charactersIn: "\u{FEFF}"))
        let firstMeaningful = value.unicodeScalars.first { !ignoredLeading.contains($0) }
        let formulaStart = firstMeaningful.map { "=+-@".unicodeScalars.contains($0) } ?? false
        let startsWithControl = value.unicodeScalars.first.map { CharacterSet.controlCharacters.contains($0) } ?? false
        let safeValue = formulaStart || startsWithControl ? "'" + value : value
        return "\"" + safeValue.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
