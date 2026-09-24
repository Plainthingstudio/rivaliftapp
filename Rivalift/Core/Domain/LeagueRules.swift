import Foundation

/// Point values and limits for the Consistency league (section 6.1). The server keeps
/// the same numbers in `league_config`; these are the defaults the app estimates with.
struct LeagueConfig: Codable, Equatable, Sendable {
    var sessionPoints = 10
    var maxSessionsPerWeek = 5
    var prPoints = 5
    var maxPRsPerSession = 5
    var maxPRsPerWeek = 10
    var targetBonus = 20
    var minTargetForBonus = 2
    var streakPointsPerWeek = 5
    var maxStreakWeeks = 4
    var minSessionDurationSec = 15 * 60
    var minWorkingSets = 6

    static let `default` = LeagueConfig()

    var maxScore: Int {
        sessionPoints * maxSessionsPerWeek + prPoints * maxPRsPerWeek + targetBonus + streakPointsPerWeek * maxStreakWeeks
    }
}

/// Rules shared by every league mode (section 6.4 and 14.3).
enum LeagueRules {
    /// Weight / e1RM spikes above this fraction of the 8-week best don't count.
    static let weightSpikeLimit = 0.25
    /// Reps / duration spikes above this fraction of the 8-week best don't count.
    static let repsSpikeLimit = 0.50
    /// Sessions started more than this long before submission don't count (backdating).
    static let maxBackdate: TimeInterval = 48 * 3600
    /// Sessions whose start is further in the future than this don't count (clock tampering).
    static let maxFutureSkew: TimeInterval = 5 * 60
    /// Grace period after the league closes during which synced sessions still count.
    static let gracePeriod: TimeInterval = 6 * 3600
    /// Custom mode: total reps per category per week are capped (section 14.6).
    static let maxTotalRepsPerCategory = 2000
    /// Weeks of history used for baselines in Strength and Custom modes.
    static let baselineWeeks = 8

    static func isEligible(startedAt: Date, submittedAt: Date) -> Bool {
        if startedAt.timeIntervalSince(submittedAt) > maxFutureSkew { return false }
        if submittedAt.timeIntervalSince(startedAt) > maxBackdate { return false }
        return true
    }

    /// True when `value` is within the allowed jump over `best` (no baseline → allowed).
    static func withinSpikeLimit(_ value: Double, best: Double?, limit: Double) -> Bool {
        guard let best, best > 0 else { return true }
        return value <= best * (1 + limit) + 1e-9
    }
}
