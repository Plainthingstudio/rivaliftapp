import Foundation

/// Monday-based weeks (SOC-05, PROG-06).
struct WeekCalendar: Sendable {
    var timeZone: TimeZone

    init(timeZone: TimeZone = .current) {
        self.timeZone = timeZone
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    /// Monday 00:00 of the week containing `date`.
    func weekStart(for date: Date) -> Date {
        let cal = calendar
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    /// Next Monday 00:00. Using calendar arithmetic keeps DST weeks at 167/169 hours.
    func weekEnd(for date: Date) -> Date {
        calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart(for: date)) ?? date
    }

    func weekNumber(for date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    /// Seven days of the week containing `date`, Monday first.
    func days(ofWeekContaining date: Date) -> [Date] {
        let start = weekStart(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// "yyyy-MM-dd" for the day containing `date` in this calendar's time zone.
    func localDateString(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Consecutive weeks before the current one whose session count met the target.
    /// - Parameter sessionsPerWeek: session counts keyed by week start.
    func streak(before date: Date, sessionsPerWeek: [Date: Int], target: Int) -> Int {
        guard target > 0 else { return 0 }
        var streak = 0
        var week = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart(for: date))
        while let current = week, (sessionsPerWeek[current] ?? 0) >= target {
            streak += 1
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: current)
        }
        return streak
    }
}
