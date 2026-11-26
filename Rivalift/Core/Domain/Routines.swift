import Foundation

/// Names for the user's routines (Custom mode): a default from the muscles trained, and
/// "Upper A 2" instead of "Upper A Copy" when a name is taken.
enum RoutineNaming {
    private enum Area: Equatable { case chest, back, shoulders, arms, legs, core }

    private static func area(_ muscle: MuscleGroup) -> Area? {
        switch muscle {
        case .chest: .chest
        case .back, .traps: .back
        case .shoulders: .shoulders
        case .biceps, .triceps, .forearms: .arms
        case .quads, .hamstrings, .glutes, .calves: .legs
        case .core: .core
        case .fullBody: nil
        }
    }

    private static func title(_ area: Area) -> String {
        switch area {
        case .chest: String(localized: "Chest")
        case .back: String(localized: "Back")
        case .shoulders: String(localized: "Shoulders")
        case .arms: String(localized: "Arms")
        case .legs: String(localized: "Legs")
        case .core: String(localized: "Core")
        }
    }

    /// "Chest & Back", "Legs", "Upper Body" or "Full Body", from each exercise's primary muscle.
    static func name(primaryMuscles: [MuscleGroup]) -> String {
        if primaryMuscles.contains(.fullBody) { return String(localized: "Full Body") }
        var order: [Area] = []
        var counts: [Area: Int] = [:]
        for area in primaryMuscles.compactMap(area) {
            if counts[area] == nil { order.append(area) }
            counts[area, default: 0] += 1
        }
        let areas = order.sorted { counts[$0, default: 0] > counts[$1, default: 0] }
        switch areas.count {
        case 0: return String(localized: "Routine")
        case 1, 2: return areas.map(title).joined(separator: " & ")
        default:
            let upper = areas.contains { [.chest, .back, .shoulders, .arms].contains($0) }
            if areas.contains(.legs), upper { return String(localized: "Full Body") }
            return upper ? String(localized: "Upper Body") : areas.prefix(2).map(title).joined(separator: " & ")
        }
    }

    /// `base`, or `base 2`, `base 3`… when that name is already used.
    static func unique(_ base: String, existing: [String]) -> String {
        let taken = Set(existing.map { $0.lowercased() })
        guard taken.contains(base.lowercased()) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)".lowercased()) { number += 1 }
        return "\(base) \(number)"
    }
}

/// This week for Custom mode: which routine is on which day (ISO weekday, Monday = 1).
enum RoutineWeek {
    enum State: Equatable { case done, today, upcoming, missed, rest }

    struct Day: Equatable {
        var weekday: Int
        var routineID: UUID?
        var state: State
    }

    /// One routine per weekday; trained days count as done whatever was scheduled.
    static func make(assignments: [Int: UUID], trainedWeekdays: Set<Int>, today: Int) -> [Day] {
        (1...7).map { weekday in
            let routine = assignments[weekday]
            let state: State
            if trainedWeekdays.contains(weekday) {
                state = .done
            } else if routine == nil {
                state = .rest
            } else if weekday == today {
                state = .today
            } else {
                state = weekday < today ? .missed : .upcoming
            }
            return Day(weekday: weekday, routineID: routine, state: state)
        }
    }
}
