import Foundation

/// Home metrics: totals per week, week-over-week change and a weekly volume series.
enum TrainingStats {
    struct Entry: Sendable {
        var startedAt: Date
        var volumeKg: Double
        var sets: Int
        var durationSec: Int
    }

    struct Totals: Equatable, Sendable {
        var sessions = 0
        var volumeKg = 0.0
        var sets = 0
        var durationSec = 0
    }

    struct WeekVolume: Equatable, Sendable {
        var weekStart: Date
        var volumeKg: Double
    }

    static func totals(_ entries: [Entry], from start: Date, to end: Date) -> Totals {
        entries.filter { $0.startedAt >= start && $0.startedAt < end }.reduce(into: Totals()) {
            $0.sessions += 1
            $0.volumeKg += $1.volumeKg
            $0.sets += $1.sets
            $0.durationSec += $1.durationSec
        }
    }

    /// Volume of the `weeks` weeks ending with the week containing `date`, oldest first.
    static func weeklyVolume(_ entries: [Entry], weeks: Int, endingAt date: Date, calendar: WeekCalendar = WeekCalendar()) -> [WeekVolume] {
        let current = calendar.weekStart(for: date)
        let starts = (0..<weeks).reversed().compactMap {
            calendar.calendar.date(byAdding: .weekOfYear, value: -$0, to: current)
        }
        var byWeek: [Date: Double] = [:]
        for entry in entries {
            byWeek[calendar.weekStart(for: entry.startedAt), default: 0] += entry.volumeKg
        }
        return starts.map { WeekVolume(weekStart: $0, volumeKg: byWeek[$0] ?? 0) }
    }

    /// Rounded percent change; nil when there is nothing to compare against.
    static func percentChange(current: Double, previous: Double) -> Int? {
        guard previous > 0 else { return nil }
        return Int(((current - previous) / previous * 100).rounded())
    }
}
