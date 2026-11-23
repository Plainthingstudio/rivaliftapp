import Foundation

/// A plan named for what it does ("Build Muscle"). The split (Full body, Push/Pull/Legs…)
/// is what is inside it and depends on how many days a week you train.
struct TrainingPlan: Identifiable, Equatable, Sendable {
    enum Level: Sendable { case beginner, allLevels, experienced }

    var id: String
    var title: String
    var summary: String
    var weeks: Int
    var days: ClosedRange<Int>
    var level: Level
    /// (from this many days a week, program name), ascending by days.
    var programs: [(days: Int, program: String)]

    /// The program for a weekly target: the last one whose day count fits, else the first.
    func program(daysPerWeek: Int) -> String {
        programs.last { $0.days <= daysPerWeek }?.program ?? programs[0].program
    }

    var levelName: String {
        switch level {
        case .beginner: String(localized: "Beginner")
        case .allLevels: String(localized: "All levels")
        case .experienced: String(localized: "Experienced")
        }
    }

    /// "3–4 days", "3 days".
    var daysText: String {
        days.lowerBound == days.upperBound
            ? String(localized: "\(days.lowerBound) days")
            : String(localized: "\(days.lowerBound)–\(days.upperBound) days")
    }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

enum PlanCatalog {
    static let all: [TrainingPlan] = [
        TrainingPlan(
            id: "get-in-shape", title: String(localized: "Get in Shape"),
            summary: String(localized: "Build the habit with full-body workouts you can keep up."),
            weeks: 8, days: 3...4, level: .beginner,
            programs: [(1, PlanRecommender.fullBody), (4, PlanRecommender.upperLower)]
        ),
        TrainingPlan(
            id: "get-lean", title: String(localized: "Get Lean"),
            summary: String(localized: "Burn fat and keep your muscle with steady, short sessions."),
            weeks: 8, days: 3...4, level: .beginner,
            programs: [(1, PlanRecommender.fullBody), (4, PlanRecommender.upperLower)]
        ),
        TrainingPlan(
            id: "build-muscle", title: String(localized: "Build Muscle"),
            summary: String(localized: "Bigger arms, chest, back and legs with more work per muscle."),
            weeks: 12, days: 4...6, level: .allLevels,
            programs: [(1, PlanRecommender.upperLower), (5, PlanRecommender.pushPullLegs)]
        ),
        TrainingPlan(
            id: "get-stronger", title: String(localized: "Get Stronger"),
            summary: String(localized: "Lift heavier on the big lifts, a little more each week."),
            weeks: 8, days: 3...3, level: .beginner,
            programs: [(1, PlanRecommender.fiveByFive)]
        ),
        TrainingPlan(
            id: "overall-fitness", title: String(localized: "Overall Fitness"),
            summary: String(localized: "Feel fitter and move better in two or three workouts a week."),
            weeks: 6, days: 2...3, level: .beginner,
            programs: [(1, PlanRecommender.fullBody)]
        ),
        TrainingPlan(
            id: "go-all-in", title: String(localized: "Go All In"),
            summary: String(localized: "Push, pull and leg days for people who love to train often."),
            weeks: 12, days: 5...6, level: .experienced,
            programs: [(1, PlanRecommender.pushPullLegs)]
        ),
    ]

    static func plan(id: String) -> TrainingPlan? {
        all.first { $0.id == id }
    }

    /// The plan onboarding picks for a goal.
    static func plan(for goal: TrainingGoal) -> TrainingPlan {
        let id = switch goal {
        case .strength: "get-stronger"
        case .muscle: "build-muscle"
        case .consistency: "get-in-shape"
        case .fitness: "overall-fitness"
        }
        return plan(id: id) ?? all[0]
    }
}
