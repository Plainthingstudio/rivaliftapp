import Foundation

/// Best values an exercise has reached before the set/session being evaluated.
struct ExerciseBests: Equatable, Codable, Sendable {
    var heaviestKg: Double?
    var bestE1RMKg: Double?
    /// Most reps achieved per weight bucket (see `WeightTolerance.bucket`).
    var repsAtWeight: [Int: Int] = [:]
    var bestSessionVolumeKg: Double?
    /// False when the exercise has never been logged: the first log is a baseline,
    /// never a record (section 6.1 anti-cheat, section 14.2).
    var hasHistory: Bool = false

    static let empty = ExerciseBests()

    /// Folds one completed session of the exercise into the bests.
    mutating func absorb(session sets: [SetSample]) {
        let working = sets.filter { $0.setType.isWorking && $0.reps > 0 }
        guard !working.isEmpty else { return }
        hasHistory = true
        for set in working {
            if set.weightKg > 0 {
                heaviestKg = max(heaviestKg ?? 0, set.weightKg)
            }
            if let e1rm = OneRepMax.estimate(for: set) {
                bestE1RMKg = max(bestE1RMKg ?? 0, e1rm)
            }
            let bucket = WeightTolerance.bucket(set.weightKg)
            repsAtWeight[bucket] = max(repsAtWeight[bucket] ?? 0, set.reps)
        }
        let volume = PRCalculator.sessionVolume(sets)
        if volume > 0 {
            bestSessionVolumeKg = max(bestSessionVolumeKg ?? 0, volume)
        }
    }

    /// Builds bests from a chronological list of past sessions.
    static func from(sessions: [[SetSample]]) -> ExerciseBests {
        var bests = ExerciseBests()
        for session in sessions { bests.absorb(session: session) }
        return bests
    }
}

/// A record reached during a session, with the value it replaced.
struct PRResult: Equatable, Sendable {
    var type: PRType
    var value: Double
    var reps: Int
    var previousValue: Double?

    /// Section 6.1: an e1RM or weight jump of more than 25% is kept as a personal
    /// record but earns no league points.
    var countsForLeague: Bool {
        guard type.countsTowardConsistencyLeague else { return false }
        guard let previousValue, previousValue > 0 else { return false }
        return value <= previousValue * (1 + LeagueRules.weightSpikeLimit) + WeightTolerance.kg
    }
}

/// Personal record detection (PROG-04, PROG-05).
enum PRCalculator {
    /// Sum of weight × reps over working sets with weight and reps.
    static func sessionVolume(_ sets: [SetSample]) -> Double {
        sets.filter { $0.setType.isWorking && $0.weightKg > 0 && $0.reps > 0 }
            .reduce(0) { $0 + $1.volumeKg }
    }

    /// Records a single set would set given prior bests and the sets already completed
    /// earlier in the same session. Used for the live badge on the set row.
    static func recordsForSet(_ set: SetSample, prior: ExerciseBests, earlierInSession: [SetSample]) -> [PRType] {
        guard prior.hasHistory, set.setType.isWorking, set.reps > 0 else { return [] }
        var bests = prior
        for earlier in earlierInSession where earlier.setType.isWorking && earlier.reps > 0 {
            if earlier.weightKg > 0 { bests.heaviestKg = max(bests.heaviestKg ?? 0, earlier.weightKg) }
            if let e = OneRepMax.estimate(for: earlier) { bests.bestE1RMKg = max(bests.bestE1RMKg ?? 0, e) }
            let bucket = WeightTolerance.bucket(earlier.weightKg)
            bests.repsAtWeight[bucket] = max(bests.repsAtWeight[bucket] ?? 0, earlier.reps)
        }

        var records: [PRType] = []
        if set.weightKg > 0, WeightTolerance.isGreater(set.weightKg, than: bests.heaviestKg ?? 0) {
            records.append(.weight)
        }
        if let e1rm = OneRepMax.estimate(for: set), WeightTolerance.isGreater(e1rm, than: bests.bestE1RMKg ?? 0) {
            records.append(.e1rm)
        }
        let bucket = WeightTolerance.bucket(set.weightKg)
        if let previous = bests.repsAtWeight[bucket], set.reps > previous {
            records.append(.repsAtWeight)
        }
        return records
    }

    /// Records set by a whole session for one exercise: at most one per type, using the
    /// session's best value (LOG-12 summary, PersonalRecord rows).
    static func sessionRecords(_ sets: [SetSample], prior: ExerciseBests) -> [PRResult] {
        guard prior.hasHistory else { return [] }
        let working = sets.filter { $0.setType.isWorking && $0.reps > 0 }
        var results: [PRResult] = []

        if let heaviest = working.filter({ $0.weightKg > 0 }).max(by: { $0.weightKg < $1.weightKg }),
           WeightTolerance.isGreater(heaviest.weightKg, than: prior.heaviestKg ?? 0) {
            results.append(PRResult(type: .weight, value: heaviest.weightKg, reps: heaviest.reps, previousValue: prior.heaviestKg))
        }

        let e1rmSets = working.compactMap { set in OneRepMax.estimate(for: set).map { (set, $0) } }
        if let best = e1rmSets.max(by: { $0.1 < $1.1 }),
           WeightTolerance.isGreater(best.1, than: prior.bestE1RMKg ?? 0) {
            results.append(PRResult(type: .e1rm, value: best.1, reps: best.0.reps, previousValue: prior.bestE1RMKg))
        }

        // Most reps at a weight: report the single biggest improvement.
        var bestRepsGain: (set: SetSample, previous: Int)?
        for set in working {
            let bucket = WeightTolerance.bucket(set.weightKg)
            guard let previous = prior.repsAtWeight[bucket], set.reps > previous else { continue }
            if let current = bestRepsGain, set.reps - previous <= current.set.reps - current.previous { continue }
            bestRepsGain = (set, previous)
        }
        if let gain = bestRepsGain {
            results.append(PRResult(type: .repsAtWeight, value: gain.set.weightKg, reps: gain.set.reps, previousValue: Double(gain.previous)))
        }

        let volume = sessionVolume(sets)
        if volume > 0, let previous = prior.bestSessionVolumeKg, WeightTolerance.isGreater(volume, than: previous) {
            results.append(PRResult(type: .volume, value: volume, reps: 0, previousValue: previous))
        }
        return results
    }
}
