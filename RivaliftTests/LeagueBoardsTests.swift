import Foundation
import Testing
@testable import Rivalift

@Suite("LeagueBoards")
struct LeagueBoardsTests {
    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    private func member(_ id: String, score: Int = 0, isMe: Bool = false,
                        lifts: [String: StrengthScorer.LiftInput] = [:], values: [String: Double] = [:]) -> LeagueMemberInput {
        LeagueMemberInput(
            entry: LeagueEntry(id: id, name: "\(id) Surname", isMe: isMe, score: score, validSessions: 2, target: 3,
                               reachedScoreAt: t0, previousRank: nil),
            lifts: lifts,
            categoryValues: values
        )
    }

    private func name(_ key: String) -> String { key }

    @Test func consistencyRowsCarryGapText() {
        let board = LeagueBoards.boards(mode: .consistency, members: [member("rina", score: 97), member("me", score: 85, isMe: true)],
                                        unit: .kg, exerciseName: name)[0]
        #expect(board.rows.map(\.id) == ["rina", "me"])
        #expect(board.me?.rank == 2)
        #expect(board.me?.gapText == "12 pts behind rina")
        #expect(board.rows[0].gapText == "Leading by 12 pts")
    }

    @Test func strengthRelativeRanksGainsAndListsBaselineWeeksLast() {
        let setup = StrengthSetup(exerciseKeys: ["bench", "squat"], comparison: .relative)
        let members = [
            member("andi", lifts: [
                "bench": .init(exerciseKey: "bench", baselineE1RMKg: 100, weekE1RMsKg: [103]),
                "squat": .init(exerciseKey: "squat", baselineE1RMKg: 120, weekE1RMsKg: [126]),
            ]),
            member("me", isMe: true, lifts: [
                "bench": .init(exerciseKey: "bench", baselineE1RMKg: 80, weekE1RMsKg: [82]),
                "squat": .init(exerciseKey: "squat", baselineE1RMKg: 100, weekE1RMsKg: [99]),
            ]),
            member("new"),
        ]
        let board = LeagueBoards.boards(mode: .strength(setup), members: members, unit: .kg, exerciseName: name)[0]
        #expect(board.rows.map(\.id) == ["andi", "me", "new"])
        #expect(board.rows[0].rank == 1)
        #expect(board.rows[1].rank == 2)
        #expect(board.rows[2].rank == nil)
        // andi: (3% + 5%) / 2 = 4%; me: (2.5% + 0%) / 2 = 1.25%, drops floored at 0.
        #expect(board.rows[0].valueText.hasPrefix("+4") && board.rows[0].valueText.hasSuffix("%"))
        #expect(board.me?.gapText?.hasSuffix("behind andi") == true)
    }

    @Test func customBuildsOverallAndOneBoardPerCategory() {
        let pullUps = CustomCategoryScorer.Category(id: "c1", exerciseKey: "pull_up", metric: .maxReps, comparison: .absolute, minReps: nil)
        let plank = CustomCategoryScorer.Category(id: "c2", exerciseKey: "plank", metric: .longestHold, comparison: .absolute, minReps: nil)
        let members = [
            member("andi", values: ["c1": 14, "c2": 60]),
            member("me", isMe: true, values: ["c1": 12, "c2": 95]),
            member("putri", values: ["c1": 9]),
        ]
        let boards = LeagueBoards.boards(mode: .custom([pullUps, plank]), members: members, unit: .kg, exerciseName: name)
        #expect(boards.map(\.id) == ["overall", "c1", "c2"])
        // Pull-ups: andi 3, me 2, putri 1. Plank: me 2, andi 1, putri 0.
        #expect(boards[0].rows.map(\.id) == ["andi", "me", "putri"])
        #expect(boards[0].rows.map(\.valueText) == ["4 pts", "4 pts", "1 pt"])
        #expect(boards[1].rows.first?.valueText == "14 reps")
        #expect(boards[2].me?.valueText == "1:35")
        #expect(boards[2].rows.last?.rank == nil)
        #expect(boards[2].rows.last?.valueText == "—")
    }

    @Test func formatsImprovementWithSign() {
        let category = CustomCategoryScorer.Category(id: "c", exerciseKey: "pull_up", metric: .maxReps, comparison: .improvement, minReps: nil)
        #expect(LeagueBoards.format(3, category: category, unit: .kg) == "+3 reps")
        #expect(LeagueBoards.format(1, category: category, unit: .kg, signed: false) == "1 rep")
    }

    @Test func competedKeysFollowTheMode() {
        #expect(LeagueMode.consistency.competedExerciseKeys.isEmpty)
        #expect(LeagueMode.strength(StrengthSetup()).competedExerciseKeys == StrengthSetup.defaultLifts)
        #expect(LeagueMode.custom(CustomCategoryScorer.presets).competedExerciseKeys.contains("plank"))
    }
}
