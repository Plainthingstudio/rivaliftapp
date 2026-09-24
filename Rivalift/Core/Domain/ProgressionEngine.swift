import Foundation

/// Rule-based next-weight suggestion (PRG-01 … PRG-04).
enum ProgressionEngine {
    enum Decision: String, Equatable, Sendable {
        case increase, same, deload
    }

    struct Suggestion: Equatable, Sendable {
        var decision: Decision
        var weightKg: Double
    }

    /// Sessions in a row that must miss the target before a deload is suggested (PRG-03).
    static let failuresBeforeDeload = 3
    static let deloadFactor = 0.9

    /// Increment in the user's unit: +2.5/+5 kg or +5/+10 lb.
    static func increment(for region: BodyRegion, unit: WeightUnit) -> Double {
        switch (unit, region) {
        case (.kg, .upper): 2.5
        case (.kg, .lower): 5
        case (.lb, .upper): 5
        case (.lb, .lower): 10
        }
    }

    /// - Parameters:
    ///   - recentSessions: working sets of previous sessions of this exercise, most recent first.
    ///   - targetReps: target reps from the template. Without a target there is no suggestion.
    static func suggest(
        recentSessions: [[SetSample]],
        targetReps: Int?,
        region: BodyRegion,
        unit: WeightUnit
    ) -> Suggestion? {
        guard let targetReps, targetReps > 0 else { return nil }
        let sessions = recentSessions
            .map { $0.filter { $0.setType.isWorking && $0.weightKg > 0 } }
            .filter { !$0.isEmpty }
        guard let last = sessions.first else { return nil }

        let topWeightKg = last.map(\.weightKg).max() ?? 0
        let topInUnit = UnitConverter.snap(UnitConverter.fromKg(topWeightKg, to: unit), in: unit)

        func hitTarget(_ sets: [SetSample]) -> Bool { sets.allSatisfy { $0.reps >= targetReps } }

        if hitTarget(last) {
            let next = topInUnit + increment(for: region, unit: unit)
            return Suggestion(decision: .increase, weightKg: UnitConverter.toKg(next, from: unit))
        }

        let consecutiveFailures = sessions.prefix { !hitTarget($0) }.count
        if consecutiveFailures >= failuresBeforeDeload {
            let next = UnitConverter.snap(topInUnit * deloadFactor, in: unit)
            return Suggestion(decision: .deload, weightKg: UnitConverter.toKg(next, from: unit))
        }
        return Suggestion(decision: .same, weightKg: UnitConverter.toKg(topInUnit, from: unit))
    }
}
