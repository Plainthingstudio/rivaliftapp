import Foundation

/// Strength league mode (section 6.2).
enum StrengthScorer {
    enum Comparison: String, Codable, Sendable {
        case relative, absolute
    }

    struct LiftInput: Codable, Equatable, Sendable {
        var exerciseKey: String
        /// Best e1RM in the 8 weeks before this week; nil means this is a baseline week.
        var baselineE1RMKg: Double?
        /// e1RM of every eligible working set (1–12 reps) this week.
        var weekE1RMsKg: [Double]
    }

    struct Result: Codable, Equatable, Sendable {
        /// Relative: average % gain. Absolute: sum of best e1RMs in kg. Nil when every lift
        /// is still in its baseline week (relative mode).
        var score: Double?
        var baselineLifts: [String]
    }

    /// Best value this week that respects the 25% spike rule.
    static func bestCountedE1RM(_ lift: LiftInput) -> Double? {
        lift.weekE1RMsKg
            .filter { LeagueRules.withinSpikeLimit($0, best: lift.baselineE1RMKg, limit: LeagueRules.weightSpikeLimit) }
            .max()
    }

    static func score(_ lifts: [LiftInput], comparison: Comparison) -> Result {
        switch comparison {
        case .absolute:
            let total = lifts.reduce(0.0) { $0 + (bestCountedE1RM($1) ?? 0) }
            return Result(score: total, baselineLifts: [])
        case .relative:
            var gains: [Double] = []
            var baselineLifts: [String] = []
            for lift in lifts {
                guard let baseline = lift.baselineE1RMKg, baseline > 0 else {
                    baselineLifts.append(lift.exerciseKey)
                    continue
                }
                // Lifts not performed this week score 0; drops are floored at 0.
                let best = bestCountedE1RM(lift) ?? baseline
                gains.append(max(0, (best - baseline) / baseline * 100))
            }
            let score = gains.isEmpty ? nil : gains.reduce(0, +) / Double(gains.count)
            return Result(score: score, baselineLifts: baselineLifts)
        }
    }
}
