import Foundation

/// When to send workout reminders (NOT-02): at `hour` on the user's training days,
/// skipping today once a workout is done there or the hour has passed.
enum ReminderPlanner {
    /// - Parameter weekdays: ISO weekdays, 1 = Monday.
    static func dates(weekdays: Set<Int>, hour: Int, trainedToday: Bool, now: Date, days: Int = 14, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { return nil }
            let isoWeekday = (calendar.component(.weekday, from: day) + 5) % 7 + 1
            guard weekdays.contains(isoWeekday), fire > now, !(offset == 0 && trainedToday) else { return nil }
            return fire
        }
    }
}
