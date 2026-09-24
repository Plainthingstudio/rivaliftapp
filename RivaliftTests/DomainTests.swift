import Foundation
import Testing
@testable import Rivalift

@Suite("UnitConverter")
struct UnitConverterTests {
    @Test func roundTripsPounds() {
        let kg = UnitConverter.toKg(100, from: .lb)
        #expect(abs(kg - 45.359237) < 1e-9)
        #expect(UnitConverter.displayValue(kg, in: .lb) == 100)
    }

    @Test func snapsToInputIncrement() {
        #expect(UnitConverter.snap(62.3, in: .kg) == 62.5)
        #expect(UnitConverter.snap(62.2, in: .kg) == 62.0)
        #expect(UnitConverter.snap(135.4, in: .lb) == 135)
    }

    @Test func parsesDecimalComma() {
        #expect(WeightFormatter.parse("62,5", locale: Locale(identifier: "id_ID")) == 62.5)
        #expect(WeightFormatter.parse("62.5", locale: Locale(identifier: "en_US")) == 62.5)
        #expect(WeightFormatter.parse("", locale: .current) == nil)
    }

    @Test func formatsWithLocale() {
        #expect(WeightFormatter.string(kg: 62.5, unit: .kg, locale: Locale(identifier: "de_DE")) == "62,5")
        #expect(WeightFormatter.string(kg: 100, unit: .kg, locale: Locale(identifier: "en_US"), includeUnit: true) == "100 kg")
    }
}

@Suite("OneRepMax")
struct OneRepMaxTests {
    @Test func epley() {
        #expect(OneRepMax.epley(weightKg: 100, reps: 1) == 100)
        #expect(abs(OneRepMax.epley(weightKg: 100, reps: 10) - 133.3333) < 0.001)
        #expect(OneRepMax.epley(weightKg: 0, reps: 5) == 0)
    }

    @Test func ignoresUnreliableSets() {
        #expect(OneRepMax.estimate(for: SetSample(weightKg: 60, reps: 13)) == nil)
        #expect(OneRepMax.estimate(for: SetSample(setType: .warmup, weightKg: 60, reps: 5)) == nil)
        #expect(OneRepMax.estimate(for: SetSample(weightKg: 60, reps: 12)) != nil)
    }
}

@Suite("PRCalculator")
struct PRCalculatorTests {
    let history: [[SetSample]] = [
        [SetSample(weightKg: 80, reps: 8), SetSample(weightKg: 80, reps: 7)],
        [SetSample(weightKg: 82.5, reps: 6), SetSample(weightKg: 80, reps: 8)],
    ]

    @Test func firstLogIsBaseline() {
        let sets = [SetSample(weightKg: 100, reps: 5)]
        #expect(PRCalculator.sessionRecords(sets, prior: .empty).isEmpty)
        #expect(PRCalculator.recordsForSet(sets[0], prior: .empty, earlierInSession: []).isEmpty)
    }

    @Test func detectsWeightAndE1RM() {
        let prior = ExerciseBests.from(sessions: history)
        let records = PRCalculator.sessionRecords([SetSample(weightKg: 85, reps: 7)], prior: prior)
        #expect(records.map(\.type).contains(.weight))
        #expect(records.map(\.type).contains(.e1rm))
        let weight = records.first { $0.type == .weight }
        #expect(weight?.previousValue == 82.5)
        #expect(weight?.countsForLeague == true)
    }

    @Test func repsAtWeight() {
        let prior = ExerciseBests.from(sessions: history)
        let records = PRCalculator.sessionRecords([SetSample(weightKg: 80, reps: 9)], prior: prior)
        #expect(records.contains { $0.type == .repsAtWeight && $0.reps == 9 && $0.previousValue == 8 })
    }

    @Test func warmupsNeverCount() {
        let prior = ExerciseBests.from(sessions: history)
        let warmup = SetSample(setType: .warmup, weightKg: 120, reps: 3)
        #expect(PRCalculator.recordsForSet(warmup, prior: prior, earlierInSession: []).isEmpty)
        #expect(PRCalculator.sessionRecords([warmup], prior: prior).isEmpty)
        #expect(PRCalculator.sessionVolume([warmup]) == 0)
    }

    @Test func overTwelveRepsSkipsE1RMOnly() {
        let prior = ExerciseBests.from(sessions: history)
        let types = PRCalculator.sessionRecords([SetSample(weightKg: 85, reps: 15)], prior: prior).map(\.type)
        #expect(types.contains(.weight))
        #expect(!types.contains(.e1rm))
    }

    @Test func unitRoundingDoesNotCreateFakeRecords() {
        let prior = ExerciseBests.from(sessions: [[SetSample(weightKg: 45.36, reps: 5)]])
        let sameInPounds = SetSample(weightKg: UnitConverter.toKg(100, from: .lb), reps: 5)
        #expect(PRCalculator.recordsForSet(sameInPounds, prior: prior, earlierInSession: []).isEmpty)
    }

    @Test func liveBadgeConsidersEarlierSets() {
        let prior = ExerciseBests.from(sessions: history)
        let first = SetSample(weightKg: 85, reps: 5)
        #expect(!PRCalculator.recordsForSet(first, prior: prior, earlierInSession: []).isEmpty)
        #expect(PRCalculator.recordsForSet(first, prior: prior, earlierInSession: [first]).isEmpty)
    }

    @Test func largeJumpKeepsRecordButNoLeaguePoints() {
        let prior = ExerciseBests.from(sessions: history)
        let records = PRCalculator.sessionRecords([SetSample(weightKg: 110, reps: 3)], prior: prior)
        let weight = records.first { $0.type == .weight }
        #expect(weight != nil)
        #expect(weight?.countsForLeague == false)
    }

    @Test func zeroWeightNeverAWeightRecord() {
        let prior = ExerciseBests.from(sessions: [[SetSample(weightKg: 0, reps: 10)]])
        let types = PRCalculator.sessionRecords([SetSample(weightKg: 0, reps: 12)], prior: prior).map(\.type)
        #expect(types == [.repsAtWeight])
    }
}

@Suite("ProgressionEngine")
struct ProgressionEngineTests {
    @Test func increasesWhenAllSetsHitTarget() {
        let last = [SetSample(weightKg: 60, reps: 8), SetSample(weightKg: 60, reps: 8), SetSample(weightKg: 60, reps: 9)]
        let upper = ProgressionEngine.suggest(recentSessions: [last], targetReps: 8, region: .upper, unit: .kg)
        #expect(upper == ProgressionEngine.Suggestion(decision: .increase, weightKg: 62.5))
        let lower = ProgressionEngine.suggest(recentSessions: [last], targetReps: 8, region: .lower, unit: .kg)
        #expect(lower?.weightKg == 65)
    }

    @Test func poundIncrements() {
        let last = [SetSample(weightKg: UnitConverter.toKg(135, from: .lb), reps: 5)]
        let result = ProgressionEngine.suggest(recentSessions: [last], targetReps: 5, region: .lower, unit: .lb)
        #expect(result?.decision == .increase)
        #expect(UnitConverter.displayValue(result?.weightKg ?? 0, in: .lb) == 145)
    }

    @Test func keepsWeightAfterAMiss() {
        let last = [SetSample(weightKg: 60, reps: 8), SetSample(weightKg: 60, reps: 6)]
        #expect(ProgressionEngine.suggest(recentSessions: [last], targetReps: 8, region: .upper, unit: .kg) == ProgressionEngine.Suggestion(decision: .same, weightKg: 60))
    }

    @Test func deloadsAfterThreeMisses() {
        let miss = [SetSample(weightKg: 100, reps: 4)]
        let result = ProgressionEngine.suggest(recentSessions: [miss, miss, miss], targetReps: 5, region: .lower, unit: .kg)
        #expect(result == ProgressionEngine.Suggestion(decision: .deload, weightKg: 90))
        let notYet = ProgressionEngine.suggest(recentSessions: [miss, miss, [SetSample(weightKg: 100, reps: 5)]], targetReps: 5, region: .lower, unit: .kg)
        #expect(notYet?.decision == .same)
    }

    @Test func noSuggestionWithoutTargetOrHistory() {
        #expect(ProgressionEngine.suggest(recentSessions: [], targetReps: 8, region: .upper, unit: .kg) == nil)
        #expect(ProgressionEngine.suggest(recentSessions: [[SetSample(weightKg: 50, reps: 8)]], targetReps: nil, region: .upper, unit: .kg) == nil)
    }

    @Test func warmupsAreIgnored() {
        let last = [SetSample(setType: .warmup, weightKg: 40, reps: 3), SetSample(weightKg: 60, reps: 8)]
        #expect(ProgressionEngine.suggest(recentSessions: [last], targetReps: 8, region: .upper, unit: .kg)?.weightKg == 62.5)
    }
}

@Suite("SetValidator")
struct SetValidatorTests {
    @Test func rejectsZeroReps() {
        #expect(SetValidator.validateCompletion(SetSample(weightKg: 50, reps: 0), type: .weightReps, heaviestKg: nil) == .rejectMissingReps)
    }

    @Test func rejectsMissingDuration() {
        #expect(SetValidator.validateCompletion(SetSample(weightKg: 0, reps: 0, durationSec: 0), type: .duration, heaviestKg: nil) == .rejectMissingDuration)
    }

    @Test func zeroWeightIsAllowed() {
        #expect(SetValidator.validateCompletion(SetSample(weightKg: 0, reps: 10), type: .weightReps, heaviestKg: 50) == .ok)
    }

    @Test func asksAboutSuspiciousWeight() {
        #expect(SetValidator.validateCompletion(SetSample(weightKg: 950, reps: 5), type: .weightReps, heaviestKg: 100) == .confirmSuspiciousWeight(suggestedKg: 95))
    }

    @Test func clampsHardLimits() {
        #expect(SetValidator.clampWeight(1500) == 1000)
        #expect(SetValidator.clampReps(150) == 100)
        #expect(SetValidator.clampReps(-2) == 0)
    }
}

@Suite("WeekCalendar")
struct WeekCalendarTests {
    let calendar = WeekCalendar(timeZone: TimeZone(identifier: "Asia/Jakarta")!)

    func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }

    @Test func weekStartsMonday() {
        // Thursday 24 Sep 2026, 10:00 Jakarta.
        let start = calendar.weekStart(for: date("2026-09-24T03:00:00Z"))
        #expect(calendar.localDateString(for: start) == "2026-09-21")
        #expect(calendar.calendar.component(.hour, from: start) == 0)
    }

    @Test func sundayNightBelongsToSameWeek() {
        let sunday = date("2026-09-27T16:50:00Z") // 23:50 Jakarta
        #expect(calendar.localDateString(for: calendar.weekStart(for: sunday)) == "2026-09-21")
    }

    @Test func dstWeekLength() {
        let berlin = WeekCalendar(timeZone: TimeZone(identifier: "Europe/Berlin")!)
        let inDSTChangeWeek = date("2026-10-21T12:00:00Z") // DST ends Sunday 25 Oct 2026
        let start = berlin.weekStart(for: inDSTChangeWeek)
        let hours = berlin.weekEnd(for: inDSTChangeWeek).timeIntervalSince(start) / 3600
        #expect(hours == 169)
    }

    @Test func streakCountsConsecutivePreviousWeeks() {
        let now = date("2026-09-24T03:00:00Z")
        let thisWeek = calendar.weekStart(for: now)
        func week(_ offset: Int) -> Date { calendar.calendar.date(byAdding: .weekOfYear, value: offset, to: thisWeek)! }
        let counts = [thisWeek: 1, week(-1): 3, week(-2): 4, week(-3): 1, week(-4): 3]
        #expect(calendar.streak(before: now, sessionsPerWeek: counts, target: 3) == 2)
    }
}

@Suite("CSVExporter")
struct CSVExporterTests {
    @Test func escapesAndFormats() {
        let row = CSVExporter.Row(
            date: Date(timeIntervalSince1970: 0), workout: "Push, heavy", durationSec: 3600, exercise: "Bench \"Press\"",
            setOrder: 1, setType: .working, weightKg: 100, reps: 5, durationSetSec: 0, isPR: true, notes: ""
        )
        let lines = CSVExporter.csv(rows: [row]).split(separator: "\n")
        #expect(lines.first.map(String.init) == CSVExporter.header)
        #expect(lines[1].contains("\"Push, heavy\""))
        #expect(lines[1].contains("\"Bench \"\"Press\"\"\""))
        #expect(lines[1].contains("100.00,220.46,5"))
    }
}

@Suite("Seed data")
struct SeedDataTests {
    @Test func libraryIsComplete() throws {
        let exercises = try SeedLoader.loadExercises(bundle: Bundle(for: BundleToken.self).appBundle)
        #expect(exercises.count >= 120)
        #expect(Set(exercises.map(\.key)).count == exercises.count)
        for equipment in Equipment.allCases {
            #expect(exercises.contains { $0.equipment == equipment }, "missing \(equipment)")
        }
    }

    @Test func templatesReferenceKnownExercises() throws {
        let bundle = Bundle(for: BundleToken.self).appBundle
        let keys = Set(try SeedLoader.loadExercises(bundle: bundle).map(\.key))
        let programs = try SeedLoader.loadPrograms(bundle: bundle)
        #expect(Set(programs.map(\.program)) == ["Full Body 3×", "Upper/Lower 4×", "Push/Pull/Legs 6×", "5×5"])
        for program in programs {
            for day in program.days {
                for item in day.exercises {
                    #expect(keys.contains(item.exerciseKey), "\(day.name): \(item.exerciseKey)")
                }
            }
        }
    }
}

final class BundleToken {}

extension Bundle {
    /// Resources live in the host app bundle; fall back to `.main` when tests run hosted.
    var appBundle: Bundle {
        if url(forResource: "exercises", withExtension: "json") != nil { return self }
        return .main
    }
}
