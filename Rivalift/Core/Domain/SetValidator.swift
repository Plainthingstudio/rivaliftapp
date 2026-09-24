import Foundation

/// Input limits and sanity checks for logging a set (LOG-06, section 14.1).
enum SetValidator {
    static let weightRangeKg: ClosedRange<Double> = 0...1000
    static let repsRange: ClosedRange<Int> = 0...100
    static let durationRangeSec: ClosedRange<Int> = 0...(3 * 3600)

    enum Outcome: Equatable, Sendable {
        case ok
        /// Completion must be refused, e.g. zero reps. Highlight the reps field.
        case rejectMissingReps
        case rejectMissingDuration
        case rejectOutOfRange
        /// The weight is more than 2× the previous record; ask "Did you mean …?".
        case confirmSuspiciousWeight(suggestedKg: Double)
    }

    static func clampWeight(_ kg: Double) -> Double { min(max(kg, weightRangeKg.lowerBound), weightRangeKg.upperBound) }
    static func clampReps(_ reps: Int) -> Int { min(max(reps, repsRange.lowerBound), repsRange.upperBound) }

    static func validateCompletion(_ set: SetSample, type: ExerciseType, heaviestKg: Double?) -> Outcome {
        guard weightRangeKg.contains(set.weightKg), repsRange.contains(set.reps) else { return .rejectOutOfRange }
        switch type {
        case .duration:
            if set.durationSec <= 0 { return .rejectMissingDuration }
        case .weightReps, .bodyweightReps:
            if set.reps <= 0 { return .rejectMissingReps }
        }
        if let heaviestKg, heaviestKg > 0, set.weightKg > heaviestKg * 2 {
            return .confirmSuspiciousWeight(suggestedKg: set.weightKg / 10)
        }
        return .ok
    }
}
