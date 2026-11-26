import Foundation
import Testing
@testable import Rivalift

@Suite("RoutineNaming")
struct RoutineNamingTests {
    @Test func namesFromTheMainAreas() {
        #expect(RoutineNaming.name(primaryMuscles: [.chest, .chest, .back]) == "Chest & Back")
        #expect(RoutineNaming.name(primaryMuscles: [.quads, .hamstrings, .calves]) == "Legs")
        #expect(RoutineNaming.name(primaryMuscles: [.biceps, .triceps]) == "Arms")
        #expect(RoutineNaming.name(primaryMuscles: [.chest, .back, .shoulders, .triceps]) == "Upper Body")
        #expect(RoutineNaming.name(primaryMuscles: [.quads, .chest, .back]) == "Full Body")
        #expect(RoutineNaming.name(primaryMuscles: [.fullBody]) == "Full Body")
        #expect(RoutineNaming.name(primaryMuscles: []) == "Routine")
    }

    @Test func busiestAreaComesFirst() {
        #expect(RoutineNaming.name(primaryMuscles: [.back, .chest, .chest]) == "Chest & Back")
    }

    @Test func uniqueAddsANumber() {
        #expect(RoutineNaming.unique("Upper A", existing: ["Legs"]) == "Upper A")
        #expect(RoutineNaming.unique("Upper A", existing: ["upper a"]) == "Upper A 2")
        #expect(RoutineNaming.unique("Upper A", existing: ["Upper A", "Upper A 2"]) == "Upper A 3")
    }
}

@Suite("RoutineWeek")
struct RoutineWeekTests {
    @Test func statesFollowTodayAndTrainedDays() {
        let push = UUID(), pull = UUID()
        let week = RoutineWeek.make(assignments: [1: push, 2: pull, 4: push], trainedWeekdays: [1, 3], today: 4)
        #expect(week.map(\.state) == [.done, .missed, .done, .today, .rest, .rest, .rest])
        #expect(week[1].routineID == pull)
        #expect(week[2].routineID == nil)
    }

    @Test func laterDaysAreUpcoming() {
        let legs = UUID()
        let week = RoutineWeek.make(assignments: [6: legs], trainedWeekdays: [], today: 2)
        #expect(week[5].state == .upcoming)
        #expect(week[1].state == .rest)
    }
}
