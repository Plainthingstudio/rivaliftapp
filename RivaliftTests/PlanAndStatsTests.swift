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
