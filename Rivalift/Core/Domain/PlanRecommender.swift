import Foundation

enum TrainingGoal: String, CaseIterable, Sendable, Identifiable {
    case strength, muscle, consistency, fitness
    var id: String { rawValue }
}

enum ExperienceLevel: String, CaseIterable, Sendable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
}

/// Picks a built-in program from the onboarding answers and the next workout in a rotation.
/// Program names match `program` in templates.json.
enum PlanRecommender {
    static let fullBody = "Full Body 3×"
    static let upperLower = "Upper/Lower 4×"
    static let pushPullLegs = "Push/Pull/Legs 6×"
    static let fiveByFive = "5×5"
    /// Higher reps, short rests and a finisher; only offered through the Get Lean plan.
    static let getLean = "Get Lean 3×"

    static func program(goal: TrainingGoal, level: ExperienceLevel, weeklyTarget: Int) -> String {
        if weeklyTarget >= 5, level != .beginner { return pushPullLegs }
        if weeklyTarget >= 4 { return upperLower }
        if goal == .strength, level == .beginner { return fiveByFive }
        return fullBody
    }

    /// The item after `last`, wrapping around; the first item when `last` is nil or unknown.
    static func next<ID: Equatable>(in rotation: [ID], after last: ID?) -> ID? {
        guard let last, let index = rotation.firstIndex(of: last) else { return rotation.first }
        return rotation[(index + 1) % rotation.count]
    }
}
