import Testing
@testable import Rivalift

@Suite("PersonalStreak")
struct PersonalStreakTests {
    @Test func countsMetWeeksAndThisWeekOnceMet() {
        let streak = PersonalStreak.make(completedWeeks: [true, true], thisWeekMet: false)
        #expect(streak.current == 2)
        #expect(PersonalStreak.make(completedWeeks: [true, true], thisWeekMet: true).current == 3)
        #expect(streak.weeksToNextRest == 2)
        #expect(streak.restWeeks == 0)
    }

    @Test func missWithoutRestWeekResets() {
        let streak = PersonalStreak.make(completedWeeks: [true, true, true, false, true], thisWeekMet: false)
        #expect(streak.current == 1)
        #expect(streak.best == 3)
        #expect(streak.history == [.met, .met, .met, .missed, .met])
    }

    @Test func fourWeeksEarnARestWeekThatSavesAMiss() {
        let streak = PersonalStreak.make(completedWeeks: [true, true, true, true, false, true], thisWeekMet: false)
        #expect(streak.history == [.met, .met, .met, .met, .rest, .met])
        #expect(streak.current == 5) // the rest week keeps the streak but does not add to it
        #expect(streak.restWeeks == 0)
        #expect(streak.weeksToNextRest == 3)
    }

    @Test func bankHoldsAtMostTwo() {
        let streak = PersonalStreak.make(completedWeeks: Array(repeating: true, count: 12), thisWeekMet: false)
        #expect(streak.restWeeks == 2)
        #expect(streak.weeksToNextRest == nil)
        let spent = PersonalStreak.make(completedWeeks: Array(repeating: true, count: 12) + [false, false, false], thisWeekMet: false)
        #expect(spent.history.suffix(3) == [.rest, .rest, .missed])
        #expect(spent.current == 0)
        #expect(spent.best == 12)
    }

    @Test func missBeforeAnyStreakIsJustMissed() {
        let streak = PersonalStreak.make(completedWeeks: [false, false], thisWeekMet: true)
        #expect(streak.history == [.missed, .missed])
        #expect(streak.current == 1)
    }
}
