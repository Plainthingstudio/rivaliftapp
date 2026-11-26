import Foundation
import Testing
@testable import Rivalift

@Suite("ExerciseSwap")
struct ExerciseSwapTests {
    let pulldown = ExerciseSwap.Option(id: UUID(), primary: .back, secondary: [.biceps], isCompound: true)
    let row = ExerciseSwap.Option(id: UUID(), primary: .back, secondary: [.biceps], isCompound: true)
    let pullover = ExerciseSwap.Option(id: UUID(), primary: .back, secondary: [], isCompound: false)
    let shrug = ExerciseSwap.Option(id: UUID(), primary: .traps, secondary: [.back], isCompound: false)
    let pullUp = ExerciseSwap.Option(id: UUID(), primary: .back, secondary: [.biceps, .forearms], isCompound: true)

    @Test func sameMuscleBestMatchFirst() {
        let ids = ExerciseSwap.candidates(for: pulldown, from: [pullover, shrug, row, pulldown, pullUp], excluding: [])
        #expect(ids == [row.id, pullUp.id, pullover.id])
    }

    @Test func skipsExercisesAlreadyInTheWorkoutAndHonoursLimit() {
        let ids = ExerciseSwap.candidates(for: pulldown, from: [pullover, row, pullUp], excluding: [row.id], limit: 1)
        #expect(ids == [pullUp.id])
    }

    @Test func daySwapsRoundTripAndExpire() {
        let from = UUID(), to = UUID()
        let swaps = ExerciseSwap.DaySwaps(day: "2026-11-23", map: [from: to])
        let decoded = ExerciseSwap.DaySwaps(raw: swaps.raw)
        #expect(decoded == swaps)
        #expect(decoded.active(on: "2026-11-23") == [from: to])
        #expect(decoded.active(on: "2026-11-24").isEmpty)
        #expect(ExerciseSwap.DaySwaps(raw: "").map.isEmpty)
        #expect(ExerciseSwap.DaySwaps(day: "2026-11-23").raw == "")
    }
}
