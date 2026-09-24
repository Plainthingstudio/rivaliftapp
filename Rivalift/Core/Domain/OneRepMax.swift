import Foundation

/// Estimated one-rep max using the Epley formula (PROG-04).
enum OneRepMax {
    /// e1RM is only considered reliable for 1–12 reps (sections 6.2 and 14.2).
    static let reliableReps = 1...12

    static func epley(weightKg: Double, reps: Int) -> Double {
        guard weightKg > 0, reps > 0 else { return 0 }
        if reps == 1 { return weightKg }
        return weightKg * (1 + Double(reps) / 30)
    }

    /// Returns nil when the set is unsuitable for e1RM records or competition.
    static func estimate(for set: SetSample) -> Double? {
        guard set.setType.isWorking, set.weightKg > 0, reliableReps.contains(set.reps) else { return nil }
        return epley(weightKg: set.weightKg, reps: set.reps)
    }
}
