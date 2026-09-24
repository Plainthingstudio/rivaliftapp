import Foundation

/// Client-side estimate of the Consistency league score (section 6.1). The server is
/// the source of truth; `scoring_vectors.json` keeps both implementations in agreement.
enum LeagueScoreEstimator {
    struct SessionInput: Codable, Equatable, Sendable {
        var id: String
        /// Local calendar day of `startedAt` in the device time zone, "yyyy-MM-dd".
        var localDate: String
        var durationSec: Int
        var workingSets: Int
        /// Weight / e1RM records from this session that count for the league
        /// (`PRResult.countsForLeague`).
        var leaguePRs: Int
        var startedAt: Date
        var submittedAt: Date
    }

    struct WeekInput: Codable, Equatable, Sendable {
        var sessions: [SessionInput]
        var weeklyTarget: Int
        /// Consecutive weeks before this one in which the target was met.
        var streakWeeks: Int
    }

    struct Breakdown: Codable, Equatable, Sendable {
        var validSessions: Int
        var sessionPoints: Int
        var prPoints: Int
        var targetPoints: Int
        var streakPoints: Int
        var total: Int { sessionPoints + prPoints + targetPoints + streakPoints }
    }

    static func isValid(_ session: SessionInput, config: LeagueConfig = .default) -> Bool {
        session.durationSec >= config.minSessionDurationSec
            && session.workingSets >= config.minWorkingSets
            && LeagueRules.isEligible(startedAt: session.startedAt, submittedAt: session.submittedAt)
    }

    static func score(_ week: WeekInput, config: LeagueConfig = .default) -> Breakdown {
        let valid = week.sessions
            .filter { isValid($0, config: config) }
            .sorted { $0.startedAt < $1.startedAt }

        // S: one session per calendar day.
        let validDays = Set(valid.map(\.localDate)).count
        let countedSessions = min(validDays, config.maxSessionsPerWeek)

        // R: records from valid sessions, capped per session and per week.
        let prs = valid.reduce(0) { $0 + min(max($1.leaguePRs, 0), config.maxPRsPerSession) }
        let countedPRs = min(prs, config.maxPRsPerWeek)

        // T: target met; targets below the minimum don't earn the bonus.
        let targetMet = week.weeklyTarget >= config.minTargetForBonus && validDays >= week.weeklyTarget

        // K: streak of previous weeks.
        let streak = min(max(week.streakWeeks, 0), config.maxStreakWeeks)

        return Breakdown(
            validSessions: validDays,
            sessionPoints: countedSessions * config.sessionPoints,
            prPoints: countedPRs * config.prPoints,
            targetPoints: targetMet ? config.targetBonus : 0,
            streakPoints: streak * config.streakPointsPerWeek
        )
    }
}
