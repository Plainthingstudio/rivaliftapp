import Foundation

/// Custom league mode (section 6.3).
enum CustomCategoryScorer {
    enum Metric: String, Codable, CaseIterable, Sendable {
        case maxReps = "max_reps"
        case totalReps = "total_reps"
        case heaviestWeight = "heaviest_weight"
        case estimated1RM = "e1rm"
        case bestSetVolume = "best_set_volume"
        case longestHold = "longest_hold"

        var displayName: String {
            switch self {
            case .maxReps: "Max reps"
            case .totalReps: "Total reps"
            case .heaviestWeight: "Heaviest weight"
            case .estimated1RM: "Estimated 1RM"
            case .bestSetVolume: "Best set volume"
            case .longestHold: "Longest hold"
            }
        }

        /// Weight-based metrics use the 25% spike rule, reps and duration use 50%.
        var spikeLimit: Double {
            switch self {
            case .heaviestWeight, .estimated1RM, .bestSetVolume: LeagueRules.weightSpikeLimit
            case .maxReps, .totalReps, .longestHold: LeagueRules.repsSpikeLimit
            }
        }

        var isWeightBased: Bool {
            switch self {
            case .heaviestWeight, .estimated1RM, .bestSetVolume: true
            default: false
            }
        }
    }

    enum Comparison: String, Codable, Sendable {
        case absolute, improvement
    }

    struct Category: Codable, Equatable, Sendable {
        var id: String
        var exerciseKey: String
        var metric: Metric
        var comparison: Comparison
        var minReps: Int?
    }

    /// Metric value of one user's week of sets for a category. Nil means no eligible record.
    /// `previousBest` is the best value in the 8 weeks before, used for the spike rule.
    static func value(of sets: [SetSample], metric: Metric, minReps: Int?, previousBest: Double?) -> Double? {
        let working = sets.filter(\.setType.isWorking)
        let limit = metric.spikeLimit
        func allowed(_ v: Double) -> Bool { LeagueRules.withinSpikeLimit(v, best: previousBest, limit: limit) }

        switch metric {
        case .maxReps:
            return working.filter { $0.reps > 0 }.map { Double($0.reps) }.filter(allowed).max()
        case .totalReps:
            let total = working.reduce(0) { $0 + max($1.reps, 0) }
            guard total > 0 else { return nil }
            let capped = Double(min(total, LeagueRules.maxTotalRepsPerCategory))
            return allowed(capped) ? capped : nil
        case .heaviestWeight:
            let minimum = max(minReps ?? 1, 1)
            return working.filter { $0.weightKg > 0 && $0.reps >= minimum }.map(\.weightKg).filter(allowed).max()
        case .estimated1RM:
            return working.compactMap { OneRepMax.estimate(for: $0) }.filter(allowed).max()
        case .bestSetVolume:
            let minimum = max(minReps ?? 1, 1)
            return working.filter { $0.weightKg > 0 && $0.reps >= minimum }.map(\.volumeKg).filter(allowed).max()
        case .longestHold:
            return working.filter { $0.durationSec > 0 }.map { Double($0.durationSec) }.filter(allowed).max()
        }
    }

    /// Improvement comparison subtracts the 8-week best; without a baseline there is no value.
    static func comparedValue(_ value: Double?, comparison: Comparison, previousBest: Double?) -> Double? {
        guard let value else { return nil }
        switch comparison {
        case .absolute: return value
        case .improvement:
            guard let previousBest else { return nil }
            return value - previousBest
        }
    }

    struct Placement: Codable, Equatable, Sendable {
        var userID: String
        var value: Double?
        var rank: Int?
        var points: Int
    }

    /// Ranks one category. With N participants who logged it, rank 1 earns N points,
    /// rank 2 earns N−1 … Users without a value earn 0. Values within the weight
    /// tolerance (weight metrics) or exactly equal share a rank.
    static func rank(values: [String: Double?], metric: Metric) -> [Placement] {
        let logged = values.compactMap { user, value in value.map { (user, $0) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
        let n = logged.count
        var placements: [Placement] = []
        var previous: Double?
        var currentRank = 0
        for (index, entry) in logged.enumerated() {
            let tied = previous.map { metric.isWeightBased ? WeightTolerance.isEqual($0, entry.1) : $0 == entry.1 } ?? false
            if !tied { currentRank = index + 1 }
            previous = entry.1
            placements.append(Placement(userID: entry.0, value: entry.1, rank: currentRank, points: n - currentRank + 1))
        }
        // Logged users keep their value order; users without a value follow, by ID.
        for user in values.filter({ $0.value == nil }).keys.sorted() {
            placements.append(Placement(userID: user, value: nil, rank: nil, points: 0))
        }
        return placements
    }

    struct OverallEntry: Codable, Equatable, Sendable {
        var userID: String
        var points: Int
        var categoryWins: Int
        var rank: Int
    }

    /// Overall ranking: total points; ties broken by number of category wins, then by
    /// points in the first category. Still tied users share a rank.
    static func overall(categoryPlacements: [[Placement]]) -> [OverallEntry] {
        var totals: [String: (points: Int, wins: Int, first: Int)] = [:]
        for (index, placements) in categoryPlacements.enumerated() {
            for p in placements {
                var t = totals[p.userID] ?? (0, 0, 0)
                t.points += p.points
                if p.rank == 1 { t.wins += 1 }
                if index == 0 { t.first = p.points }
                totals[p.userID] = t
            }
        }
        let sorted = totals.sorted { a, b in
            if a.value.points != b.value.points { return a.value.points > b.value.points }
            if a.value.wins != b.value.wins { return a.value.wins > b.value.wins }
            if a.value.first != b.value.first { return a.value.first > b.value.first }
            return a.key < b.key
        }
        var result: [OverallEntry] = []
        for (index, entry) in sorted.enumerated() {
            var rank = index + 1
            if let last = result.last, let lastTotals = totals[last.userID],
               lastTotals.points == entry.value.points, lastTotals.wins == entry.value.wins, lastTotals.first == entry.value.first {
                rank = last.rank
            }
            result.append(OverallEntry(userID: entry.key, points: entry.value.points, categoryWins: entry.value.wins, rank: rank))
        }
        return result
    }
}
