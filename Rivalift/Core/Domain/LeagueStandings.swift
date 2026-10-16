import Foundation

/// One member's standing in a group's league week (SOC-06).
struct LeagueEntry: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var isMe: Bool
    var score: Int
    var validSessions: Int
    var target: Int
    /// When the member reached `score`; the earlier one wins a tie (section 6.1).
    var reachedScoreAt: Date
    /// Rank at the previous snapshot (yesterday), nil when unknown.
    var previousRank: Int?
}

struct RankedEntry: Identifiable, Equatable, Sendable {
    var entry: LeagueEntry
    var rank: Int
    var id: String { entry.id }

    /// Positive when the member moved up since `previousRank`, negative when down.
    var movement: Int {
        guard let previous = entry.previousRank else { return 0 }
        return previous - rank
    }
}

/// Ranking and leaderboard helpers for the Consistency league.
enum LeagueStandings {
    /// Highest score first; ties go to more valid sessions, then to whoever reached the
    /// score first. Every member gets a distinct rank.
    static func rank(_ entries: [LeagueEntry]) -> [RankedEntry] {
        entries
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.validSessions != $1.validSessions { return $0.validSessions > $1.validSessions }
                if $0.reachedScoreAt != $1.reachedScoreAt { return $0.reachedScoreAt < $1.reachedScoreAt }
                return $0.id < $1.id
            }
            .enumerated()
            .map { RankedEntry(entry: $1, rank: $0 + 1) }
    }

    enum Gap: Equatable, Sendable {
        /// Points behind the member directly above.
        case behind(points: Int, name: String)
        /// First place, with the lead over second place (0 when alone or tied).
        case leading(by: Int)
    }

    static func gap(for id: String, in ranked: [RankedEntry]) -> Gap? {
        guard let index = ranked.firstIndex(where: { $0.id == id }) else { return nil }
        if index == 0 {
            let lead = ranked.count > 1 ? ranked[0].entry.score - ranked[1].entry.score : 0
            return .leading(by: lead)
        }
        let above = ranked[index - 1].entry
        return .behind(points: above.score - ranked[index].entry.score, name: above.name)
    }
}

/// 6-character group invite codes (SOC-02). The alphabet leaves out 0/O and 1/I so codes
/// read aloud or typed from a screenshot don't get mixed up.
enum InviteCode {
    static let length = 6
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func generate<G: RandomNumberGenerator>(using generator: inout G) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    /// Uppercased, without spaces or dashes, cut to `length`, so pasted text like
    /// "ab3 k7q" becomes "AB3K7Q".
    static func normalize(_ text: String) -> String {
        String(text.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(length))
    }

    static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }
}

/// "Ends in …" countdown to the league close (SOC-07).
enum LeagueCountdown {
    /// "2d 14h", "5h 20m" or "12m"; nil once the week has closed.
    static func remaining(from now: Date, to end: Date) -> String? {
        let seconds = Int(end.timeIntervalSince(now))
        guard seconds > 0 else { return nil }
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3_600
        let minutes = seconds % 3_600 / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(minutes, 1))m"
    }
}
