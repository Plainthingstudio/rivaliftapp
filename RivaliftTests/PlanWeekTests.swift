import Foundation
import Testing
@testable import Rivalift

@Suite("PlanWeek")
struct PlanWeekTests {
    let calendar = WeekCalendar(timeZone: TimeZone(identifier: "Asia/Jakarta")!)
    let a = UUID(), b = UUID(), c = UUID()
    var rotation: [UUID] { [a, b, c] }

    /// 18:00 local on a yyyy-MM-dd day. 2026-11-23 is a Monday.
    func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)!.addingTimeInterval(18 * 3600)
    }

    @Test func assignsRotationToTrainingDays() {
        let week = PlanWeek.make(rotation: rotation, weekdays: [1, 3, 5], done: [], lastDone: nil, now: date("2026-11-23"), calendar: calendar)
        #expect(week.days.map(\.state) == [.today, .rest, .upcoming, .rest, .upcoming, .rest, .rest])
        #expect(week.days.map(\.workoutID) == [a, nil, b, nil, c, nil, nil])
        #expect(week.nextWorkoutID == a)
    }

    @Test func continuesAfterLastWorkoutAndMarksDoneAndMissed() {
        // Monday done (A), Wednesday skipped, today is Thursday (not a training day).
        let week = PlanWeek.make(
            rotation: rotation, weekdays: [1, 3, 5],
            done: [.init(date: date("2026-11-23"), workoutID: a)], lastDone: a,
            now: date("2026-11-26"), calendar: calendar
        )
        #expect(week.days.map(\.state) == [.done, .rest, .missed, .rest, .upcoming, .rest, .rest])
        #expect(week.days[4].workoutID == b)
        #expect(week.today.state == .rest)
        #expect(week.nextWorkoutID == b)
        #expect(week.nextDay?.workoutID == b)
    }

    @Test func daysBeforeThePlanStartedAreRestNotMissed() {
        // Plan started Wednesday; Monday was a training day but the plan did not exist yet.
        let week = PlanWeek.make(
            rotation: rotation, weekdays: [1, 3, 5], done: [], lastDone: nil,
            now: date("2026-11-25"), startedAt: date("2026-11-25"), calendar: calendar
        )
        #expect(week.days.map(\.state) == [.rest, .rest, .today, .rest, .upcoming, .rest, .rest])
        #expect(week.today.workoutID == a)
    }

    @Test func todayDoneShowsNextUp() {
        let week = PlanWeek.make(
            rotation: rotation, weekdays: [1, 3, 5],
            done: [.init(date: date("2026-11-25"), workoutID: b)], lastDone: b,
            now: date("2026-11-25"), calendar: calendar
        )
        #expect(week.today.state == .done)
        #expect(week.nextDay?.workoutID == c)
        #expect(week.nextWorkoutID == c)
    }

    @Test func noTrainingDaysFallsBackToSpreadForTarget() {
        #expect(PlanWeek.defaultWeekdays(count: 1) == [6])
        #expect(PlanWeek.defaultWeekdays(count: 3) == [1, 3, 5])
        #expect(PlanWeek.defaultWeekdays(count: 6) == [1, 2, 3, 4, 5, 6])
        #expect(PlanWeek.defaultWeekdays(count: 9).count == 7)
    }

    @Test func emptyRotationPlansNothing() {
        let week = PlanWeek.make(rotation: [], weekdays: [1], done: [], lastDone: nil, now: date("2026-11-23"), calendar: calendar)
        #expect(week.days.allSatisfy { $0.workoutID == nil })
        #expect(week.nextWorkoutID == nil)
    }

    @Test func shortDayLabels() {
        #expect(PlanWeekStrip.shortLabel("Upper A") == "Upper")
        #expect(PlanWeekStrip.shortLabel("Full Body B") == "B")
        #expect(PlanWeekStrip.shortLabel("5×5 Workout A") == "A")
        #expect(PlanWeekStrip.shortLabel("Push") == "Push")
        #expect(PlanWeekStrip.shortLabel(nil) == "")
    }

    @Test func progressCountsWeeksFromStart() {
        let progress = PlanProgress.make(start: date("2026-11-16"), now: date("2026-11-25"), weeks: 8, perWeek: 3, done: 4, calendar: calendar)
        #expect(progress == PlanProgress(week: 2, weeks: 8, done: 4, total: 24))
        let late = PlanProgress.make(start: date("2026-01-05"), now: date("2026-11-25"), weeks: 8, perWeek: 3, done: 30, calendar: calendar)
        #expect(late.week == 8)
        #expect(late.done == 24)
    }
}
