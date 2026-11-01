import Foundation

/// Local civil dates use Gregorian yyyy-MM-dd keys, independent of device language.
public enum HabitCalendar {
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = gregorian(calendar).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1, parts.month ?? 1, parts.day ?? 1)
    }

    /// Stored dates are validated on load and save. Invalid input returns distantPast.
    public static func date(_ day: String, calendar: Calendar = .current) -> Date {
        parsedDate(day, calendar: calendar) ?? .distantPast
    }

    public static func isValidDay(_ day: String) -> Bool {
        parsedDate(day, calendar: utcCalendar) != nil
    }

    public static func weekDays(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let calendar = gregorian(calendar)
        let start = calendar.startOfDay(for: date)
        let mondayOffset = (calendar.component(.weekday, from: start) + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: start) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// Monday is 1 and Sunday is 7. Invalid input returns 0.
    public static func weekday(_ day: String) -> Int {
        guard let date = parsedDate(day, calendar: utcCalendar) else { return 0 }
        return (utcCalendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    static func days(from first: String, through last: String) -> [String] {
        let calendar = utcCalendar
        guard first <= last,
              var current = parsedDate(first, calendar: calendar),
              let end = parsedDate(last, calendar: calendar) else { return [] }
        var days: [String] = []
        while current <= end {
            days.append(dayKey(current, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current), next > current else { break }
            current = next
        }
        return days
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func gregorian(_ source: Calendar) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }

    private static func parsedDate(_ day: String, calendar source: Calendar) -> Date? {
        let bytes = Array(day.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45,
              bytes.enumerated().allSatisfy({ $0.offset == 4 || $0.offset == 7 || (48...57).contains($0.element) }) else { return nil }
        let pieces = day.split(separator: "-")
        guard pieces.count == 3,
              let year = Int(pieces[0]), (1...9999).contains(year),
              let month = Int(pieces[1]), (1...12).contains(month),
              let dateOfMonth = Int(pieces[2]), (1...31).contains(dateOfMonth) else { return nil }
        let calendar = gregorian(source)
        let parts = DateComponents(year: year, month: month, day: dateOfMonth)
        guard let result = calendar.date(from: parts), dayKey(result, calendar: calendar) == day else { return nil }
        return result
    }
}
