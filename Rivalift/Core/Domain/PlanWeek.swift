import Foundation

/// This week of the user's plan (Home, My Plan): which plan workout falls on which training day.
/// Workouts follow the plan's rotation from the last one done, so a missed day never skips a workout.
struct PlanWeek: Equatable, Sendable {
    enum State: Equatable, Sendable { case done, today, upcoming, missed, rest }

    struct Day: Equatable, Sendable {
        var date: Date
        var state: State
        /// The plan workout done (or planned) that day; nil on rest and missed days.
        var workoutID: UUID?
    }

    struct Done: Equatable, Sendable {
        var date: Date
        var workoutID: UUID
    }

    /// Monday first.
    var days: [Day]
    var todayIndex: Int
    /// The workout to do next, whatever the day: today's, or the one "Train anyway" starts.
    var nextWorkoutID: UUID?

    var today: Day { days[todayIndex] }
    /// First planned day after today this week.
    var nextDay: Day? { days[(todayIndex + 1)...].first { $0.state == .upcoming } }

    /// - Parameters:
    ///   - weekdays: ISO training weekdays (1 = Monday).
    ///   - done: plan workouts completed this week.
    ///   - lastDone: the most recent plan workout ever completed.
    /// - Parameter startedAt: when the plan started; training days before it are rest, not missed.
    static func make(rotation: [UUID], weekdays: Set<Int>, done: [Done], lastDone: UUID?, now: Date, startedAt: Date? = nil, calendar: WeekCalendar) -> PlanWeek {
        let start = startedAt.map(calendar.localDateString(for:))
        let next = PlanRecommender.next(in: rotation, after: lastDone)
        var pointer = next
        let today = calendar.localDateString(for: now)
        var todayIndex = 0
        let days = calendar.days(ofWeekContaining: now).enumerated().map { index, date -> Day in
            let key = calendar.localDateString(for: date)
            if key == today { todayIndex = index }
            if let workout = done.last(where: { calendar.localDateString(for: $0.date) == key }) {
                return Day(date: date, state: .done, workoutID: workout.workoutID)
            }
            guard weekdays.contains(index + 1), start.map({ key >= $0 }) ?? true else { return Day(date: date, state: .rest) }
            if key < today { return Day(date: date, state: .missed) }
            let workout = pointer
            pointer = pointer.flatMap { PlanRecommender.next(in: rotation, after: $0) }
            return Day(date: date, state: key == today ? .today : .upcoming, workoutID: workout)
        }
        return PlanWeek(days: days, todayIndex: todayIndex, nextWorkoutID: next)
    }

    /// Starting mid-week: days this week that fit `count` workouts from `today` (ISO weekday)
    /// on. Keeps the training days still ahead and adds free days, preferring ones not next to
    /// another workout. Nil when the usual days already fit. Late in the week it returns as
    /// many days as are left.
    static func catchUpWeekdays(count: Int, weekdays: Set<Int>, today: Int) -> Set<Int>? {
        var chosen = weekdays.filter { $0 >= today }
        guard chosen.count < count, today <= 7 else { return nil }
        var free = (today...7).filter { !chosen.contains($0) }
        while chosen.count < count, !free.isEmpty {
            let pick = free.first { !chosen.contains($0 - 1) && !chosen.contains($0 + 1) } ?? free[0]
            chosen.insert(pick)
            free.removeAll { $0 == pick }
        }
        return chosen
    }

    /// Training days spread over the week when the user has not picked any.
    static func defaultWeekdays(count: Int) -> Set<Int> {
        switch count {
        case ...1: [6]
        case 2: [2, 5]
        case 3: [1, 3, 5]
        case 4: [1, 2, 4, 5]
        case 5: [1, 2, 4, 5, 6]
        case 6: [1, 2, 3, 4, 5, 6]
        default: Set(1...7)
        }
    }
}

/// How far the user is through their plan: "Week 2 of 8", "4 of 24 workouts".
struct PlanProgress: Equatable, Sendable {
    var week: Int
    var weeks: Int
    var done: Int
    var total: Int

    static func make(start: Date, now: Date, weeks: Int, perWeek: Int, done: Int, calendar: WeekCalendar) -> PlanProgress {
        let elapsed = calendar.calendar.dateComponents([.weekOfYear], from: calendar.weekStart(for: start), to: calendar.weekStart(for: now)).weekOfYear ?? 0
        let total = max(1, weeks * perWeek)
        return PlanProgress(week: min(max(elapsed + 1, 1), weeks), weeks: weeks, done: min(done, total), total: total)
    }
}
