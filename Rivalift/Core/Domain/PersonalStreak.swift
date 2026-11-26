import Foundation

/// The user's own weekly streak with rest weeks. Rest weeks only protect this streak; league
/// points use `WeekCalendar.streak`, which has none.
///
/// Rules: a week counts when its workouts reach the weekly target. Every 4 counted weeks earn a
/// rest week, at most 2 banked. A missed week spends a rest week and the streak carries on
/// (the rest week itself does not add to the count). With none banked the streak and bank reset.
/// The current week never breaks the streak; it adds one once its target is met.
struct PersonalStreak: Equatable, Sendable {
    enum Week: Equatable, Sendable { case met, rest, missed }

    static let earnEvery = 4
    static let maxRestWeeks = 2

    /// Counted weeks in the running streak, this week included once it is met.
    var current: Int
    var best: Int
    /// Rest weeks banked, 0…`maxRestWeeks`.
    var restWeeks: Int
    /// Counted weeks until the next rest week; nil while the bank is full.
    var weeksToNextRest: Int?
    /// One entry per completed week, oldest first.
    var history: [Week]
    var thisWeekMet: Bool

    /// - Parameter completedWeeks: whether each finished week met its target, oldest first.
    static func make(completedWeeks: [Bool], thisWeekMet: Bool) -> PersonalStreak {
        var current = 0, best = 0, bank = 0, sinceEarn = 0
        var history: [Week] = []

        func count() {
            current += 1
            sinceEarn += 1
            if sinceEarn == earnEvery {
                sinceEarn = 0
                bank = min(maxRestWeeks, bank + 1)
            }
            best = max(best, current)
        }

        for met in completedWeeks {
            if met {
                count()
                history.append(.met)
            } else if current > 0 && bank > 0 {
                bank -= 1
                history.append(.rest)
            } else {
                current = 0
                bank = 0
                sinceEarn = 0
                history.append(.missed)
            }
        }
        if thisWeekMet { count() }

        return PersonalStreak(
            current: current,
            best: best,
            restWeeks: bank,
            weeksToNextRest: bank >= maxRestWeeks ? nil : earnEvery - sinceEarn,
            history: history,
            thisWeekMet: thisWeekMet
        )
    }
}
