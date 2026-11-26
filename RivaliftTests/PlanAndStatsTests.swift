import Foundation
import Testing
@testable import Rivalift

@Suite("PlanRecommender")
struct PlanRecommenderTests {
    @Test func picksProgramFromAnswers() {
        #expect(PlanRecommender.program(goal: .fitness, level: .beginner, weeklyTarget: 3) == PlanRecommender.fullBody)
        #expect(PlanRecommender.program(goal: .strength, level: .beginner, weeklyTarget: 3) == PlanRecommender.fiveByFive)
        #expect(PlanRecommender.program(goal: .strength, level: .advanced, weeklyTarget: 2) == PlanRecommender.fullBody)
        #expect(PlanRecommender.program(goal: .muscle, level: .intermediate, weeklyTarget: 4) == PlanRecommender.upperLower)
        #expect(PlanRecommender.program(goal: .muscle, level: .beginner, weeklyTarget: 5) == PlanRecommender.upperLower)
        #expect(PlanRecommender.program(goal: .muscle, level: .advanced, weeklyTarget: 5) == PlanRecommender.pushPullLegs)
    }

    @Test func programsExistInSeedData() throws {
        let programs = Set(try SeedLoader.loadPrograms(bundle: Bundle(for: BundleToken.self).appBundle).map(\.program))
        for name in [PlanRecommender.fullBody, PlanRecommender.upperLower, PlanRecommender.pushPullLegs, PlanRecommender.fiveByFive] {
            #expect(programs.contains(name))
        }
    }

    @Test func rotatesThroughProgram() {
        let days = ["A", "B", "C"]
        #expect(PlanRecommender.next(in: days, after: nil) == "A")
        #expect(PlanRecommender.next(in: days, after: "A") == "B")
        #expect(PlanRecommender.next(in: days, after: "C") == "A")
        #expect(PlanRecommender.next(in: days, after: "X") == "A")
        #expect(PlanRecommender.next(in: [String](), after: "A") == nil)
    }
}

@Suite("TrainingStats")
struct TrainingStatsTests {
    let calendar = WeekCalendar(timeZone: TimeZone(identifier: "Asia/Jakarta")!)

    func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: string)!.addingTimeInterval(18 * 3600)
    }

    var entries: [TrainingStats.Entry] {
        [
            .init(startedAt: date("2026-09-14"), volumeKg: 1000, sets: 10, durationSec: 3000),
            .init(startedAt: date("2026-09-21"), volumeKg: 1500, sets: 12, durationSec: 3600),
            .init(startedAt: date("2026-09-23"), volumeKg: 500, sets: 6, durationSec: 1800),
        ]
    }

    @Test func totalsForWeek() {
        let now = date("2026-09-24")
        let totals = TrainingStats.totals(entries, from: calendar.weekStart(for: now), to: calendar.weekEnd(for: now))
        #expect(totals == TrainingStats.Totals(sessions: 2, volumeKg: 2000, sets: 18, durationSec: 5400))
    }

    @Test func weeklyVolumeOldestFirstWithEmptyWeeks() {
        let series = TrainingStats.weeklyVolume(entries, weeks: 3, endingAt: date("2026-09-24"), calendar: calendar)
        #expect(series.map(\.volumeKg) == [0, 1000, 2000])
        #expect(series.last?.weekStart == calendar.weekStart(for: date("2026-09-24")))
    }

    @Test func percentChange() {
        #expect(TrainingStats.percentChange(current: 2000, previous: 1000) == 100)
        #expect(TrainingStats.percentChange(current: 750, previous: 1000) == -25)
        #expect(TrainingStats.percentChange(current: 500, previous: 0) == nil)
    }
}

@Suite("ReminderPlanner")
struct ReminderPlannerTests {
    let calendar = WeekCalendar(timeZone: TimeZone(identifier: "Asia/Jakarta")!).calendar

    /// Wednesday 2026-10-14 at `hour`:00 Jakarta time.
    func wednesday(_ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: hour))!
    }

    func days(_ dates: [Date]) -> [Int] { dates.map { calendar.component(.day, from: $0) } }

    @Test func remindsOnTrainingDaysAtHour() {
        // Mon, Wed, Fri at 18:00, from Wednesday morning, one week ahead.
        let dates = ReminderPlanner.dates(weekdays: [1, 3, 5], hour: 18, trainedToday: false, now: wednesday(9), days: 7, calendar: calendar)
        #expect(days(dates) == [14, 16, 19])
        #expect(dates.allSatisfy { calendar.component(.hour, from: $0) == 18 })
    }

    @Test func skipsTodayWhenTrainedOrHourPassed() {
        let trained = ReminderPlanner.dates(weekdays: [3, 5], hour: 18, trainedToday: true, now: wednesday(9), days: 7, calendar: calendar)
        #expect(days(trained) == [16])
        let late = ReminderPlanner.dates(weekdays: [3, 5], hour: 18, trainedToday: false, now: wednesday(19), days: 7, calendar: calendar)
        #expect(days(late) == [16])
    }

    @Test func sundayIsSeven() {
        let dates = ReminderPlanner.dates(weekdays: [7], hour: 8, trainedToday: false, now: wednesday(9), days: 7, calendar: calendar)
        #expect(days(dates) == [18])
        #expect(ReminderPlanner.dates(weekdays: [], hour: 8, trainedToday: false, now: wednesday(9), calendar: calendar).isEmpty)
    }
}
