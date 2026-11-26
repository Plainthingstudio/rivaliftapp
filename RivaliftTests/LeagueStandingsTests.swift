import Foundation
import Testing
@testable import Rivalift

@Suite("LeagueStandings")
struct LeagueStandingsTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func entry(_ id: String, score: Int, sessions: Int = 3, at offset: TimeInterval = 0, previous: Int? = nil) -> LeagueEntry {
        LeagueEntry(id: id, name: id, isMe: false, score: score, validSessions: sessions, target: 3,
                    reachedScoreAt: t0.addingTimeInterval(offset), previousRank: previous)
    }

    @Test func ranksByScoreThenSessionsThenTime() {
        let ranked = LeagueStandings.rank([
            entry("low", score: 40),
            entry("late", score: 85, sessions: 4, at: 60),
            entry("early", score: 85, sessions: 4, at: 0),
            entry("fewer", score: 85, sessions: 3, at: -600),
            entry("top", score: 110),
        ])
        #expect(ranked.map(\.id) == ["top", "early", "late", "fewer", "low"])
        #expect(ranked.map(\.rank) == [1, 2, 3, 4, 5])
    }

    @Test func movementComparesWithPreviousRank() {
        let ranked = LeagueStandings.rank([entry("a", score: 90, previous: 3), entry("b", score: 80, previous: 1), entry("c", score: 70)])
        #expect(ranked[0].movement == 2)
        #expect(ranked[1].movement == -1)
        #expect(ranked[2].movement == 0)
    }

    @Test func gapToTheMemberAbove() {
        let ranked = LeagueStandings.rank([entry("rina", score: 97), entry("me", score: 85), entry("dimas", score: 60)])
        #expect(LeagueStandings.gap(for: "me", in: ranked) == .behind(points: 12, name: "rina"))
        #expect(LeagueStandings.gap(for: "rina", in: ranked) == .leading(by: 12))
        #expect(LeagueStandings.gap(for: "solo", in: ranked) == nil)
        #expect(LeagueStandings.gap(for: "me", in: LeagueStandings.rank([entry("me", score: 10)])) == .leading(by: 0))
    }
}

@Suite("InviteCode")
struct InviteCodeTests {
    @Test func generatesValidCodes() {
        for _ in 0..<50 {
            let code = InviteCode.generate()
            #expect(InviteCode.isValid(code), "\(code)")
        }
    }

    @Test func normalizesPastedText() {
        #expect(InviteCode.normalize(" ab3 k7q ") == "AB3K7Q")
        #expect(InviteCode.normalize("ab-3k-7q-zz") == "AB3K7Q")
    }

    @Test func rejectsAmbiguousOrShortCodes() {
        #expect(!InviteCode.isValid("AB3K7"))
        #expect(!InviteCode.isValid("AB0K7Q"))
        #expect(!InviteCode.isValid("AB1K7Q"))
        #expect(InviteCode.isValid("AB3K7Q"))
    }
}

@Suite("LeagueCountdown")
struct LeagueCountdownTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func formatsRemainingTime() {
        #expect(LeagueCountdown.remaining(from: now, to: now.addingTimeInterval(2 * 86_400 + 14 * 3_600 + 59)) == "2d 14h")
        #expect(LeagueCountdown.remaining(from: now, to: now.addingTimeInterval(5 * 3_600 + 20 * 60)) == "5h 20m")
        #expect(LeagueCountdown.remaining(from: now, to: now.addingTimeInterval(12 * 60 + 30)) == "12m")
        #expect(LeagueCountdown.remaining(from: now, to: now.addingTimeInterval(20)) == "1m")
        #expect(LeagueCountdown.remaining(from: now, to: now) == nil)
    }
}
