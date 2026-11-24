import Foundation
import Observation
import SwiftData

enum AppTab: Hashable {
    case home, library, leagues, profile
}

/// Dependency container shared through the SwiftUI environment. Views talk to stores and
/// repositories from here; they never touch SwiftData or the network directly (section 9).
@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let exercises: ExerciseRepository
    let templates: TemplateRepository
    let sessions: SessionRepository
    let settingsRepository: SettingsRepository
    let notifications: NotificationService
    let restTimer: RestTimerService
    let sync: SyncService
    let workout: WorkoutStore
    let leagues = LeagueStore()

    private(set) var settings: UserSettings

    var selectedTab: AppTab = .home
    /// Bumped after any data change so list screens can reload.
    private(set) var dataVersion = 0
    var seedError: String?

    init(inMemory: Bool = false) {
        let container = PersistenceController.makeContainer(inMemory: inMemory)
        let context = container.mainContext

        var seedError: String?
        do {
            try SeedLoader.seedIfNeeded(context: context)
        } catch {
            seedError = error.localizedDescription
        }

        let sessions = SessionRepository(context: context)
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let settingsRepository = SettingsRepository(context: context)
        let notifications = NotificationService()
        let restTimer = RestTimerService(notifications: notifications)
        let settings = settingsRepository.current()
        restTimer.soundEnabled = settings.restSoundEnabled
        restTimer.hapticsEnabled = settings.restHapticsEnabled

        self.container = container
        self.exercises = exercises
        self.templates = templates
        self.sessions = sessions
        self.settingsRepository = settingsRepository
        self.notifications = notifications
        self.restTimer = restTimer
        self.sync = SyncService(context: context)
        self.settings = settings
        self.seedError = seedError
        self.workout = WorkoutStore(
            sessions: sessions,
            exercises: exercises,
            templates: templates,
            restTimer: restTimer,
            notifications: notifications,
            settings: settings
        )

        workout.onDataChange = { [weak self] in self?.dataDidChange() }
        workout.restoreActiveSession()
    }

    var unit: WeightUnit { settings.unit }

    func dataDidChange() {
        dataVersion &+= 1
        refreshWorkoutReminders()
    }

    /// Reminders for the next two weeks (NOT-02). Runs on every data or settings change and
    /// when the app becomes active, so a finished workout cancels today's reminder.
    func refreshWorkoutReminders(now: Date = Date()) {
        var dates: [Date] = []
        if settings.onboardingDone && settings.notifyWorkoutReminder {
            let calendar = WeekCalendar().calendar
            let today = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
            dates = ReminderPlanner.dates(
                weekdays: settings.trainingWeekdays,
                hour: settings.reminderHour,
                trainedToday: !sessions.completedSessions(from: today, to: tomorrow).isEmpty,
                now: now,
                calendar: calendar
            )
        }
        notifications.scheduleWorkoutReminders(at: dates)
    }

    func saveSettings() {
        restTimer.soundEnabled = settings.restSoundEnabled
        restTimer.hapticsEnabled = settings.restHapticsEnabled
        settingsRepository.save()
        dataDidChange()
    }

    /// Weekly progress for Home and History headers (PROG-06).
    func weekProgress(for date: Date = Date()) -> WeekProgress {
        let calendar = WeekCalendar()
        let start = calendar.weekStart(for: date)
        let end = calendar.weekEnd(for: date)
        let thisWeek = sessions.completedSessions(from: start, to: end)
        let trainedDays = Set(thisWeek.map { calendar.localDateString(for: $0.startedAt) })

        var perWeek: [Date: Int] = [:]
        for session in sessions.completedSessions() {
            perWeek[calendar.weekStart(for: session.startedAt), default: 0] += 1
        }
        let target = settings.effectiveWeeklyTarget(at: date)
        let streak = calendar.streak(before: date, sessionsPerWeek: perWeek, target: target)
        let metNow = thisWeek.count >= target
        return WeekProgress(
            days: calendar.days(ofWeekContaining: date),
            trainedDays: trainedDays,
            sessions: thisWeek.count,
            target: target,
            streakWeeks: streak + (metNow ? 1 : 0)
        )
    }
}

extension AppEnvironment {
    /// The personal streak with rest weeks and the weeks behind it (Streak screen, Home 🔥).
    struct StreakOverview {
        var streak: PersonalStreak
        /// Week starts of `streak.history`, oldest first.
        var weeks: [Date]
        var thisWeek: Date
        var sessionsThisWeek: Int
        var target: Int
    }

    /// From the week of the first workout up to now. Each week is judged by the target in
    /// effect that week. League points keep using `WeekCalendar.streak` (no rest weeks).
    func streakOverview(now: Date = Date()) -> StreakOverview {
        let calendar = WeekCalendar()
        let thisWeek = calendar.weekStart(for: now)
        var perWeek: [Date: Int] = [:]
        for session in sessions.completedSessions() {
            perWeek[calendar.weekStart(for: session.startedAt), default: 0] += 1
        }
        var weeks: [Date] = []
        if var week = perWeek.keys.min() {
            while week < thisWeek {
                weeks.append(week)
                guard let next = calendar.calendar.date(byAdding: .weekOfYear, value: 1, to: week) else { break }
                week = next
            }
        }
        let target = settings.effectiveWeeklyTarget(at: now)
        let streak = PersonalStreak.make(
            completedWeeks: weeks.map { (perWeek[$0] ?? 0) >= settings.effectiveWeeklyTarget(at: $0) },
            thisWeekMet: (perWeek[thisWeek] ?? 0) >= target
        )
        return StreakOverview(streak: streak, weeks: weeks, thisWeek: thisWeek, sessionsThisWeek: perWeek[thisWeek] ?? 0, target: target)
    }

    /// Quick Workout for today. Lifts the built-in programs use most come first, so a beginner
    /// gets squats, presses and rows before niche moves.
    func quickWorkout(kit: QuickWorkout.Kit, minutes: Int, focus: QuickWorkout.Focus, shuffle: Int) -> [(item: QuickWorkout.Item, exercise: Exercise)] {
        var uses: [UUID: Int] = [:]
        for template in templates.builtInTemplates() {
            for item in template.orderedExercises { if let id = item.exercise?.id { uses[id, default: 0] += 1 } }
        }
        let all = exercises.activeExercises()
            .filter { !QuickWorkout.advancedKeys.contains($0.key) }
            .sorted { (uses[$0.id] ?? 0, $1.name) > (uses[$1.id] ?? 0, $0.name) }
        let options = all.map {
            QuickWorkout.Option(id: $0.id, primary: $0.primaryMuscle, equipment: $0.equipment, isCompound: $0.isCompound, isDuration: $0.type == .duration)
        }
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return QuickWorkout.build(kit: kit, minutes: minutes, focus: focus, from: options, shuffle: shuffle)
            .compactMap { item in byID[item.id].map { (item, $0) } }
    }

    /// Client estimate of this week's Consistency score from the user's own workouts.
    /// `excluding` leaves one session out, for "before this workout" comparisons (SOC-18).
    func leagueEstimate(now: Date = Date(), excluding sessionID: UUID? = nil) -> LeagueScoreEstimator.Breakdown {
        let calendar = WeekCalendar()
        let progress = weekProgress(for: now)
        let thisWeek = sessions.completedSessions(from: calendar.weekStart(for: now), to: calendar.weekEnd(for: now))
            .filter { $0.id != sessionID }
        let inputs = thisWeek.map { session in
            LeagueScoreEstimator.SessionInput(
                id: session.id.uuidString,
                localDate: WeekCalendar(timeZone: session.timeZone).localDateString(for: session.startedAt),
                durationSec: session.durationSec,
                workingSets: session.completedWorkingSets.count,
                leaguePRs: (session.personalRecords ?? []).filter(\.countsForLeague).count,
                startedAt: session.startedAt,
                submittedAt: session.endedAt ?? now
            )
        }
        let metNow = progress.sessions >= progress.target
        let week = LeagueScoreEstimator.WeekInput(
            sessions: inputs,
            weeklyTarget: progress.target,
            streakWeeks: max(0, progress.streakWeeks - (metNow ? 1 : 0))
        )
        return LeagueScoreEstimator.score(week)
    }

    /// The user's own row in a league, from real workouts.
    func myLeagueEntry(now: Date = Date(), excluding sessionID: UUID? = nil) -> LeagueEntry {
        let score = leagueEstimate(now: now, excluding: sessionID)
        return LeagueEntry(
            id: LeagueStore.meID,
            name: settings.displayName.isEmpty ? String(localized: "You") : settings.displayName,
            isMe: true,
            score: score.total,
            validSessions: score.validSessions,
            target: settings.effectiveWeeklyTarget(at: now),
            reachedScoreAt: now,
            previousRank: nil
        )
    }

    /// The user's inputs for any league mode: Consistency score, Strength lifts and Custom
    /// category values from this week's sets, compared with the 8 weeks before.
    func myLeagueInput(for mode: LeagueMode, now: Date = Date(), excluding sessionID: UUID? = nil) -> LeagueMemberInput {
        var input = LeagueMemberInput(entry: myLeagueEntry(now: now, excluding: sessionID))
        let calendar = WeekCalendar()
        let weekStart = calendar.weekStart(for: now)
        let weekEnd = calendar.weekEnd(for: now)
        let baselineStart = calendar.calendar.date(byAdding: .weekOfYear, value: -8, to: weekStart) ?? weekStart

        /// Completed appearances of an exercise, split into this week and the 8 weeks before
        /// (grouped by week so weekly totals compare fairly).
        func samples(for key: String) -> (week: [SetSample], earlierWeeks: [[SetSample]]) {
            guard let exercise = exercises.exercise(key: key) else { return ([], []) }
            var week: [SetSample] = []
            var earlier: [Date: [SetSample]] = [:]
            for item in sessions.history(for: exercise, excluding: sessionID) {
                guard let started = item.session?.startedAt else { continue }
                if started >= weekStart && started < weekEnd {
                    week += item.samples
                } else if started >= baselineStart && started < weekStart {
                    earlier[calendar.weekStart(for: started), default: []] += item.samples
                }
            }
            return (week, Array(earlier.values))
        }

        switch mode {
        case .consistency:
            break
        case .strength(let setup):
            for key in setup.exerciseKeys {
                let (week, earlier) = samples(for: key)
                input.lifts[key] = StrengthScorer.LiftInput(
                    exerciseKey: key,
                    baselineE1RMKg: earlier.joined().compactMap(OneRepMax.estimate(for:)).max(),
                    weekE1RMsKg: week.compactMap(OneRepMax.estimate(for:))
                )
            }
        case .custom(let categories):
            for category in categories {
                let (week, earlier) = samples(for: category.exerciseKey)
                let previousBest = earlier
                    .compactMap { CustomCategoryScorer.value(of: $0, metric: category.metric, minReps: category.minReps, previousBest: nil) }
                    .max()
                let value = CustomCategoryScorer.value(of: week, metric: category.metric, minReps: category.minReps, previousBest: previousBest)
                if let compared = CustomCategoryScorer.comparedValue(value, comparison: category.comparison, previousBest: previousBest) {
                    input.categoryValues[category.id] = compared
                }
            }
        }
        return input
    }

    /// "Back Squat" for "Barbell Back Squat": short names for leaderboard details.
    func shortExerciseName(key: String) -> String {
        let name = exercises.exercise(key: key)?.name ?? key
        for prefix in ["Barbell ", "Dumbbell "] where name.hasPrefix(prefix) {
            return String(name.dropFirst(prefix.count))
        }
        return name
    }

    /// Leaderboards of a group with the user's real row (SOC-06, SOC-15).
    func leagueBoards(for group: LeagueGroup, now: Date = Date(), excluding sessionID: UUID? = nil) -> [LeagueBoard] {
        leagues.boards(for: group, me: myLeagueInput(for: group.mode, now: now, excluding: sessionID), unit: unit) {
            shortExerciseName(key: $0)
        }
    }

    /// "Pull-up Club · Your best: 12 reps · Leader: 14 reps" for an exercise that counts in
    /// one of the user's leagues (SOC-17). Uses finished workouts of this week.
    func competitionHint(exerciseKey: String, now: Date = Date()) -> String? {
        for group in leagues.groups(competingOn: exerciseKey) {
            let boards = leagueBoards(for: group, now: now)
            let board: LeagueBoard?
            let mineLabel: String
            switch group.mode {
            case .custom(let categories):
                board = categories.first { $0.exerciseKey == exerciseKey }.flatMap { category in boards.first { $0.id == category.id } }
                mineLabel = String(localized: "Your best")
            case .strength:
                board = boards.first
                mineLabel = String(localized: "You")
            case .consistency:
                board = nil
                mineLabel = ""
            }
            guard let board, let leader = board.rows.first(where: { $0.rank == 1 }) else { continue }
            let mine = board.me.flatMap { $0.rank == nil ? nil : $0.valueText } ?? "—"
            return String(localized: "\(group.name) · \(mineLabel): \(mine) · Leader: \(leader.valueText)")
        }
        return nil
    }

    struct RankChange: Identifiable {
        var id: String
        var groupEmoji: String
        var title: String
        var before: Int?
        var after: Int?
    }

    /// Where a finished workout moved the user in each league board (SOC-18). Shows each
    /// group's main board, plus any Custom category where the rank changed.
    func leagueRankChanges(for sessionID: UUID, now: Date = Date()) -> [RankChange] {
        leagues.groups.flatMap { group -> [RankChange] in
            let before = Dictionary(uniqueKeysWithValues: leagueBoards(for: group, now: now, excluding: sessionID).map { ($0.id, $0.me?.rank) })
            return leagueBoards(for: group, now: now).enumerated().compactMap { index, board in
                let old = before[board.id] ?? nil
                let new = board.me?.rank
                guard index == 0 || old != new else { return nil }
                let title = index == 0 ? group.name : "\(group.name) · \(board.title)"
                return RankChange(id: "\(group.id)-\(board.id)", groupEmoji: group.emoji, title: title, before: old, after: new)
            }
        }
    }

    struct TrainingOverview {
        var thisWeek: TrainingStats.Totals
        var lastWeek: TrainingStats.Totals
        var weeklyVolume: [TrainingStats.WeekVolume]
        var totalWorkouts: Int
    }

    /// Home metrics (appendix A.2).
    func trainingOverview(now: Date = Date()) -> TrainingOverview {
        let calendar = WeekCalendar()
        let completed = sessions.completedSessions()
        let entries = completed.map {
            TrainingStats.Entry(startedAt: $0.startedAt, volumeKg: $0.totalVolumeKg, sets: $0.completedSetCount, durationSec: $0.durationSec)
        }
        let start = calendar.weekStart(for: now)
        let previous = calendar.calendar.date(byAdding: .weekOfYear, value: -1, to: start) ?? start
        return TrainingOverview(
            thisWeek: TrainingStats.totals(entries, from: start, to: calendar.weekEnd(for: now)),
            lastWeek: TrainingStats.totals(entries, from: previous, to: start),
            weeklyVolume: TrainingStats.weeklyVolume(entries, weeks: 8, endingAt: now, calendar: calendar),
            totalWorkouts: completed.count
        )
    }
}

extension AppEnvironment {
    /// Home in My Plan mode: the onboarding plan, how far along it is and this week's days.
    struct PlanHome {
        var program: TemplateRepository.Program
        var title: String
        var subtitle: String
        var progress: PlanProgress
        var week: PlanWeek
        var daysPerWeek: Int
        /// Plan workouts done this week.
        var doneThisWeek: Int

        func workout(_ id: UUID?) -> WorkoutTemplate? {
            guard let id else { return nil }
            return program.templates.first { $0.id == id }
        }
    }

    func planHome(now: Date = Date()) -> PlanHome? {
        guard let program = templates.programs().first(where: { $0.name == settings.planProgram }) else { return nil }
        let calendar = WeekCalendar()
        let ids = Set(program.templates.map(\.id))
        // Most recent first.
        let planSessions = sessions.completedSessions().filter { $0.templateID.map(ids.contains) ?? false }
        if settings.planStartedAt == nil {
            // Users who onboarded before plans had a start: count from their first plan workout.
            settings.planStartedAt = planSessions.last?.startedAt ?? now
            settingsRepository.save()
        }
        let start = settings.planStartedAt ?? now
        let weekdays = planWeekdays(now: now)
        let scheduleDays = thisWeekWeekdays(now: now)
        let weekStart = calendar.weekStart(for: now)
        let thisWeek = planSessions.filter { $0.startedAt >= weekStart }
        let week = PlanWeek.make(
            rotation: program.templates.map(\.id),
            weekdays: scheduleDays,
            done: thisWeek.reversed().compactMap { session in session.templateID.map { PlanWeek.Done(date: session.startedAt, workoutID: $0) } },
            lastDone: planSessions.first?.templateID,
            now: now,
            startedAt: start,
            calendar: calendar
        )
        let progress = PlanProgress.make(
            start: start, now: now,
            weeks: settings.streakGoalWeeks > 0 ? settings.streakGoalWeeks : 8,
            perWeek: weekdays.count,
            done: planSessions.filter { $0.startedAt >= start }.count,
            calendar: calendar
        )
        return PlanHome(
            program: program,
            title: currentPlan.title,
            subtitle: String(localized: "\(Self.splitName(for: program.name)) · \(weekdays.count) days a week"),
            progress: progress,
            week: week,
            daysPerWeek: weekdays.count,
            doneThisWeek: thisWeek.count
        )
    }

    /// New training days from the Plan screen. A different day count re-picks the plan's
    /// program (Get in Shape: 3 days Full body, 4 days Upper/Lower) and the weekly target.
    func setTrainingDays(_ days: Set<Int>) {
        let oldCount = planWeekdays().count
        settings.trainingWeekdays = days
        settings.weekOverrideRaw = ""
        if !days.isEmpty, days.count != oldCount {
            settings.planProgram = currentPlan.program(daysPerWeek: days.count)
            settings.requestWeeklyTarget(days.count)
        }
        saveSettings()
    }

    /// This week's training days: a mid-week start's one-week days, else `planWeekdays`.
    func thisWeekWeekdays(now: Date = Date()) -> Set<Int> {
        let calendar = WeekCalendar()
        let parts = settings.weekOverrideRaw.split(separator: "|")
        if parts.count == 2, parts[0] == calendar.localDateString(for: calendar.weekStart(for: now)) {
            return Set(parts[1].split(separator: ",").compactMap { Int($0) })
        }
        return planWeekdays(now: now)
    }

    /// Training days picked in onboarding or on the Plan screen, else spread over the week for the target.
    func planWeekdays(now: Date = Date()) -> Set<Int> {
        settings.trainingWeekdays.isEmpty
            ? PlanWeek.defaultWeekdays(count: settings.effectiveWeeklyTarget(at: now))
            : settings.trainingWeekdays
    }

    /// The chosen plan; users from before plans had names get the one for their goal.
    var currentPlan: TrainingPlan {
        PlanCatalog.plan(id: settings.planID) ?? PlanCatalog.plan(for: settings.goal)
    }

    /// Days a week the plan detail suggests first: the user's training days, kept inside the plan's range.
    func suggestedDays(for plan: TrainingPlan, now: Date = Date()) -> Int {
        min(max(planWeekdays(now: now).count, plan.days.lowerBound), plan.days.upperBound)
    }

    /// Switch plan: its program for `daysPerWeek`, its length, starting this week on Home.
    /// The weekly target follows from next week.
    /// - Parameters:
    ///   - weekdays: the training days from now on.
    ///   - thisWeek: other days for this week only (mid-week start), or nil.
    func startPlan(_ plan: TrainingPlan, daysPerWeek: Int, weekdays: Set<Int>, thisWeek: Set<Int>? = nil, now: Date = Date()) {
        settings.planID = plan.id
        settings.planProgram = plan.program(daysPerWeek: daysPerWeek)
        settings.trainingWeekdays = weekdays
        let calendar = WeekCalendar()
        settings.weekOverrideRaw = thisWeek.map {
            calendar.localDateString(for: calendar.weekStart(for: now)) + "|" + $0.sorted().map(String.init).joined(separator: ",")
        } ?? ""
        settings.requestWeeklyTarget(daysPerWeek, now: now)
        settings.streakGoalWeeks = plan.weeks
        settings.planStartedAt = now
        settings.daySwapsRaw = ""
        settings.homeMode = .plan
        saveSettings()
    }

    static func splitName(for program: String) -> String {
        switch program {
        case PlanRecommender.fullBody: String(localized: "Full body")
        case PlanRecommender.upperLower: String(localized: "Upper / Lower")
        case PlanRecommender.pushPullLegs: String(localized: "Push / Pull / Legs")
        case PlanRecommender.fiveByFive: String(localized: "Strength basics")
        case PlanRecommender.getLean: String(localized: "Full body burn")
        default: program
        }
    }

    /// "3 sets · 8 reps · 40 kg": the template's sets and reps plus the suggested weight (PRG-01).
    func prescription(for item: TemplateExercise) -> String {
        var parts = [String(localized: "\(item.setCount) sets")]
        if item.targetReps > 0 { parts.append(String(localized: "\(item.targetReps) reps")) }
        if let exercise = planExercise(for: item), exercise.type == .weightReps,
           let suggestion = ProgressionEngine.suggest(
               recentSessions: sessions.recentSamples(for: exercise, excluding: nil),
               targetReps: item.targetReps,
               region: exercise.primaryMuscle.bodyRegion,
               unit: unit
           ) {
            parts.append(WeightFormatter.string(kg: suggestion.weightKg, unit: unit, includeUnit: true))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Swaps (the ⇄ sheet)

    /// Today's "just today" swaps: template exercise ID → exercise ID.
    func todaySwaps(now: Date = Date()) -> [UUID: UUID] {
        ExerciseSwap.DaySwaps(raw: settings.daySwapsRaw).active(on: WeekCalendar().localDateString(for: now))
    }

    /// What a plan row does today: the swap if there is one, else the plan's exercise.
    func planExercise(for item: TemplateExercise) -> Exercise? {
        todaySwaps()[item.id].flatMap(exercises.exercise(id:)) ?? item.exercise
    }

    /// Up to four exercises for the same muscle that are not already in this workout.
    func swapCandidates(for item: TemplateExercise) -> [Exercise] {
        guard let current = planExercise(for: item) else { return [] }
        let inWorkout = Set((item.template?.orderedExercises ?? []).compactMap { planExercise(for: $0)?.id })
        let all = exercises.activeExercises()
        func option(_ e: Exercise) -> ExerciseSwap.Option {
            .init(id: e.id, primary: e.primaryMuscle, secondary: e.secondaryMuscles, isCompound: e.isCompound)
        }
        let ids = ExerciseSwap.candidates(for: option(current), from: all.map(option), excluding: inWorkout)
        return ids.compactMap { id in all.first { $0.id == id } }
    }

    /// "Always in my plan" changes the plan's workout; "Just today" only today's.
    // ponytail: edits the built-in template in place (the seeder never overwrites it); copy the program per user if plans get shared
    func swap(_ item: TemplateExercise, to exercise: Exercise, always: Bool, now: Date = Date()) {
        let today = WeekCalendar().localDateString(for: now)
        var swaps = ExerciseSwap.DaySwaps(raw: settings.daySwapsRaw)
        if swaps.day != today { swaps = .init(day: today) }
        if always {
            item.exercise = exercise
            templates.save()
            swaps.map[item.id] = nil
        } else {
            swaps.map[item.id] = exercise.id == item.exercise?.id ? nil : exercise.id
        }
        settings.daySwapsRaw = swaps.raw
        saveSettings()
    }
}

struct WeekProgress {
    var days: [Date]
    var trainedDays: Set<String>
    var sessions: Int
    var target: Int
    /// Consecutive weeks meeting the target, including this week once it is met.
    var streakWeeks: Int
}
