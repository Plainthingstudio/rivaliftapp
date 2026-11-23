import Foundation
import Observation

struct RecordLine: Identifiable, Hashable {
    let id = UUID()
    var exerciseName: String
    var type: PRType
    var value: Double
    var reps: Int
    var previousValue: Double?
}

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let session: WorkoutSession
    let records: [RecordLine]
    /// "Workout #12".
    let sessionNumber: Int
    let template: WorkoutTemplate?
    let templateChanged: Bool
    /// Estimated Consistency points this session adds to the week (section 6.1).
    let estimatedLeaguePoints: Int
    let isValidForLeague: Bool
}

/// State and actions of the active workout (LOG-01 … LOG-14).
@MainActor
@Observable
final class WorkoutStore {
    enum StartRequest: Equatable {
        case empty
        /// `swaps`: template exercise ID → exercise ID to use instead, today only.
        case template(UUID, swaps: [UUID: UUID] = [:])
        case repeatLast
        /// Empty session prefilled with exercises picked before starting.
        case exercises([UUID])
    }

    enum CompletionOutcome: Equatable {
        case completed(isPR: Bool)
        case uncompleted
        case rejected(SetValidator.Outcome)
        case needsConfirmation(suggestedKg: Double)
    }

    enum FinishCheck: Equatable {
        case ready
        case nothingCompleted
        case unfinishedFilledSets(Int)
    }

    private(set) var session: WorkoutSession?
    var isPresented = false
    var summary: WorkoutSummary?
    var isStalePromptPresented = false
    /// Set when a start is requested while another session is active.
    var pendingStart: StartRequest?
    /// "Start workout" pushes a chooser screen on Home first; the session (and its clock)
    /// starts only after the user picks what to do. Starting pops the chooser.
    var isStartScreenPresented = false
    var notice: String?
    var onDataChange: (@MainActor () -> Void)?

    let settings: UserSettings
    private let sessions: SessionRepository
    private let exercises: ExerciseRepository
    private let templates: TemplateRepository
    let restTimer: RestTimerService
    private let notifications: NotificationService

    private var previousCache: [UUID: [SetEntry]] = [:]
    private var bestsCache: [UUID: ExerciseBests] = [:]
    private var suggestionCache: [UUID: ProgressionEngine.Suggestion?] = [:]

    static let staleInterval: TimeInterval = 6 * 3600

    init(
        sessions: SessionRepository,
        exercises: ExerciseRepository,
        templates: TemplateRepository,
        restTimer: RestTimerService,
        notifications: NotificationService,
        settings: UserSettings
    ) {
        self.sessions = sessions
        self.exercises = exercises
        self.templates = templates
        self.restTimer = restTimer
        self.notifications = notifications
        self.settings = settings
    }

    var unit: WeightUnit { settings.unit }

    // MARK: Lifecycle

    func restoreActiveSession() {
        session = sessions.activeSession()
        checkStaleSession()
    }

    func checkStaleSession() {
        guard let session else { return }
        let lastActivity = session.lastCompletedSetAt ?? session.startedAt
        if Date().timeIntervalSince(lastActivity) > Self.staleInterval {
            isStalePromptPresented = true
        }
    }

    /// Returns false when another session is active; the UI then offers resume or discard.
    @discardableResult
    func requestStart(_ request: StartRequest) -> Bool {
        if session != nil {
            pendingStart = request
            return false
        }
        start(request)
        return true
    }

    func resumeInsteadOfStarting() {
        pendingStart = nil
        isPresented = true
    }

    func discardAndStartPending() {
        guard let request = pendingStart else { return }
        pendingStart = nil
        discard()
        start(request)
    }

    private func start(_ request: StartRequest) {
        clearCaches()
        switch request {
        case .empty:
            session = sessions.startEmpty(name: defaultName())
        case .template(let id, let swaps):
            guard let template = templates.template(id: id) else { return }
            let result = sessions.start(from: template, swaps: swaps.compactMapValues(exercises.exercise(id:)))
            session = result.session
            if !result.skipped.isEmpty {
                notice = String(localized: "Skipped archived exercises: \(result.skipped.joined(separator: ", "))")
            }
        case .repeatLast:
            session = sessions.repeatLast() ?? sessions.startEmpty(name: defaultName())
        case .exercises(let ids):
            let session = sessions.startEmpty(name: defaultName())
            for exercise in ids.compactMap(exercises.exercise(id:)) {
                sessions.addExercise(exercise, to: session)
            }
            self.session = session
        }
        isPresented = true
        isStartScreenPresented = false
        onDataChange?()
    }

    private func defaultName() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return String(localized: "Morning Workout")
        case 12..<17: return String(localized: "Afternoon Workout")
        default: return String(localized: "Evening Workout")
        }
    }

    // MARK: Exercises (LOG-02)

    func addExercises(_ list: [Exercise]) {
        guard let session else { return }
        for exercise in list { sessions.addExercise(exercise, to: session) }
    }

    /// Removing an exercise with completed sets needs confirmation (section 14.1).
    func needsConfirmationToRemove(_ entry: SessionExercise) -> Bool {
        entry.orderedSets.contains(where: \.isCompleted)
    }

    func removeExercise(_ entry: SessionExercise) {
        suggestionCache[entry.id] = nil
        sessions.removeExercise(entry)
    }

    func moveExercises(from source: IndexSet, to destination: Int) {
        guard let session else { return }
        sessions.moveExercises(in: session, from: source, to: destination)
    }

    func replaceExercise(_ entry: SessionExercise, with exercise: Exercise) {
        suggestionCache[entry.id] = nil
        sessions.replaceExercise(entry, with: exercise)
    }

    func setRest(_ entry: SessionExercise, seconds: Int) {
        entry.restSec = seconds
        if let exercise = entry.exercise { exercises.updateRest(exercise, seconds: seconds) }
        sessions.save()
    }

    func setNotes(_ entry: SessionExercise, _ notes: String) {
        entry.notes = notes
        sessions.save()
    }

    func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let session, !trimmed.isEmpty else { return }
        session.name = trimmed
        sessions.save()
    }

    // MARK: Sets (LOG-03 … LOG-06)

    func addSet(to entry: SessionExercise) {
        sessions.addSet(to: entry)
    }

    func removeSet(_ set: SetEntry) {
        sessions.removeSet(set)
    }

    func setType(_ set: SetEntry, _ type: SetType) {
        set.setType = type
        sessions.save()
    }

    /// `value` is in the user's display unit; nil clears the field.
    func setWeight(_ set: SetEntry, displayValue value: Double?) {
        if let value {
            set.weightKg = SetValidator.clampWeight(UnitConverter.toKg(max(value, 0), from: unit))
            set.hasWeight = true
        } else {
            set.weightKg = 0
            set.hasWeight = false
        }
        sessions.save()
    }

    func setReps(_ set: SetEntry, _ reps: Int?) {
        set.reps = SetValidator.clampReps(reps ?? 0)
        set.hasReps = reps != nil
        sessions.save()
    }

    func setDuration(_ set: SetEntry, _ seconds: Int?) {
        set.durationSec = min(max(seconds ?? 0, 0), SetValidator.durationRangeSec.upperBound)
        set.hasReps = seconds != nil
        sessions.save()
    }

    /// LOG-04: tapping "previous" copies it into the row.
    func fillFromPrevious(_ set: SetEntry, previous: SetEntry) {
        set.weightKg = previous.weightKg
        set.hasWeight = true
        set.reps = previous.reps
        set.durationSec = previous.durationSec
        set.hasReps = true
        sessions.save()
    }

    func previousSets(for entry: SessionExercise) -> [SetEntry] {
        guard let exercise = entry.exercise else { return [] }
        if let cached = previousCache[exercise.id] { return cached }
        let sets = sessions.previousSets(for: exercise, excluding: session?.id)
        previousCache[exercise.id] = sets
        return sets
    }

    func previous(for set: SetEntry, in entry: SessionExercise) -> SetEntry? {
        guard let index = entry.orderedSets.firstIndex(where: { $0.id == set.id }) else { return nil }
        let previous = previousSets(for: entry)
        return index < previous.count ? previous[index] : nil
    }

    func bests(for exercise: Exercise) -> ExerciseBests {
        if let cached = bestsCache[exercise.id] { return cached }
        let bests = sessions.bests(for: exercise, before: session?.startedAt ?? Date(), excluding: session?.id)
        bestsCache[exercise.id] = bests
        return bests
    }

    /// PRG-01 … PRG-04: suggested weight shown as a placeholder.
    func suggestion(for entry: SessionExercise) -> ProgressionEngine.Suggestion? {
        if let cached = suggestionCache[entry.id] { return cached }
        guard let exercise = entry.exercise, exercise.type == .weightReps else { return nil }
        let result = ProgressionEngine.suggest(
            recentSessions: sessions.recentSamples(for: exercise, excluding: session?.id),
            targetReps: entry.targetReps,
            region: exercise.primaryMuscle.bodyRegion,
            unit: unit
        )
        suggestionCache[entry.id] = result
        return result
    }

    /// Placeholder weight (kg) for an empty weight field.
    func placeholderWeightKg(for set: SetEntry, in entry: SessionExercise) -> Double? {
        if set.setType.isWorking, let suggestion = suggestion(for: entry) { return suggestion.weightKg }
        return previous(for: set, in: entry)?.weightKg
    }

    func placeholderReps(for set: SetEntry, in entry: SessionExercise) -> Int? {
        if let previous = previous(for: set, in: entry) {
            return entry.exercise?.type == .duration ? previous.durationSec : previous.reps
        }
        return set.setType.isWorking ? entry.targetReps : nil
    }

    /// Checking a set (LOG-08). Empty fields take their placeholder, so a row prefilled from
    /// "previous" or a suggestion completes with a single tap.
    func toggleComplete(_ set: SetEntry, in entry: SessionExercise, confirmed: Bool = false) -> CompletionOutcome {
        if set.isCompleted {
            set.isCompleted = false
            set.completedAt = nil
            set.isPR = false
            sessions.save()
            return .uncompleted
        }
        guard let exercise = entry.exercise else { return .rejected(.rejectOutOfRange) }

        if !set.hasWeight, let placeholder = placeholderWeightKg(for: set, in: entry) {
            set.weightKg = placeholder
            set.hasWeight = true
        }
        if !set.hasReps, let placeholder = placeholderReps(for: set, in: entry) {
            if exercise.type == .duration { set.durationSec = placeholder } else { set.reps = placeholder }
            set.hasReps = true
        }

        let bests = bests(for: exercise)
        switch SetValidator.validateCompletion(set.sample, type: exercise.type, heaviestKg: bests.heaviestKg) {
        case .ok:
            break
        case .confirmSuspiciousWeight(let suggested):
            if !confirmed { return .needsConfirmation(suggestedKg: suggested) }
        case let rejection:
            Haptics.warning()
            return .rejected(rejection)
        }

        let now = Date()
        let earlier = entry.orderedSets.filter { $0.isCompleted && $0.order < set.order }.map(\.sample)
        let records = PRCalculator.recordsForSet(set.sample, prior: bests, earlierInSession: earlier)
        set.isCompleted = true
        set.completedAt = now
        set.isPR = !records.isEmpty
        session?.lastActivityAt = now
        sessions.save()

        if set.isPR { Haptics.success() } else { Haptics.light() }
        restTimer.start(seconds: entry.restSec, nextExerciseName: nextExerciseName(after: set, in: entry))
        notifications.scheduleStaleSessionReminder(after: now)
        return .completed(isPR: set.isPR)
    }

    private func nextExerciseName(after set: SetEntry, in entry: SessionExercise) -> String? {
        if entry.orderedSets.contains(where: { !$0.isCompleted && $0.id != set.id }) {
            return entry.exercise?.name
        }
        guard let session else { return nil }
        let items = session.orderedExercises
        guard let index = items.firstIndex(where: { $0.id == entry.id }), index + 1 < items.count else { return nil }
        return items[index + 1].exercise?.name
    }

    // MARK: Finish and discard (LOG-12, LOG-14, section 14.1)

    func finishCheck() -> FinishCheck {
        guard let session else { return .nothingCompleted }
        let sets = session.orderedExercises.flatMap(\.orderedSets)
        if !sets.contains(where: \.isCompleted) { return .nothingCompleted }
        let filled = sets.filter { !$0.isCompleted && $0.hasReps }.count
        return filled > 0 ? .unfinishedFilledSets(filled) : .ready
    }

    /// "Mark all as done" for filled but unchecked sets.
    func completeFilledSets() {
        guard let session else { return }
        let now = Date()
        for entry in session.orderedExercises {
            for set in entry.orderedSets where !set.isCompleted && set.hasReps {
                let valid = entry.exercise?.type == .duration ? set.durationSec > 0 : set.reps > 0
                guard valid else { continue }
                set.isCompleted = true
                set.completedAt = now
            }
        }
        sessions.save()
    }

    func finish(endedAt: Date = Date()) {
        guard let session else { return }
        let weekEstimateBefore = estimatedWeekPoints(including: nil)
        let records = sessions.finish(session, endedAt: endedAt)
        let weekEstimateAfter = estimatedWeekPoints(including: session)

        let template = session.templateID.flatMap { templates.template(id: $0) }
        let lines = records.map {
            RecordLine(exerciseName: $0.exercise?.name ?? "", type: $0.prType, value: $0.valueKg, reps: $0.reps, previousValue: $0.previousValue)
        }
        summary = WorkoutSummary(
            session: session,
            records: lines,
            sessionNumber: sessions.completedSessionCount(),
            template: template,
            templateChanged: template.map { !$0.isBuiltIn && Self.differs(template: $0, session: session) } ?? false,
            estimatedLeaguePoints: max(0, weekEstimateAfter - weekEstimateBefore),
            isValidForLeague: session.durationSec >= LeagueConfig.default.minSessionDurationSec
                && session.completedWorkingSets.count >= LeagueConfig.default.minWorkingSets
        )

        restTimer.stop()
        notifications.cancelStaleSessionReminder()
        self.session = nil
        isPresented = false
        clearCaches()
        onDataChange?()

        if !settings.hasAskedNotificationPermission {
            settings.hasAskedNotificationPermission = true
            sessions.save()
            Task { await notifications.requestAuthorization() }
        }
    }

    func finishStaleAtLastSet() {
        guard let session else { return }
        guard let last = session.lastCompletedSetAt else {
            discard()
            return
        }
        finish(endedAt: last)
    }

    func discard() {
        guard let session else { return }
        sessions.discard(session)
        restTimer.stop()
        notifications.cancelStaleSessionReminder()
        self.session = nil
        isPresented = false
        clearCaches()
        onDataChange?()
    }

    private func clearCaches() {
        previousCache = [:]
        bestsCache = [:]
        suggestionCache = [:]
    }

    private static func differs(template: WorkoutTemplate, session: WorkoutSession) -> Bool {
        let templateShape = template.orderedExercises.map { "\($0.exercise?.key ?? ""):\($0.setCount)" }
        let sessionShape = session.orderedExercises.map { entry in
            "\(entry.exercise?.key ?? ""):\(entry.orderedSets.filter { $0.setType.isWorking && $0.isCompleted }.count)"
        }
        return templateShape != sessionShape
    }

    /// Consistency points of the current week, used to show "+N pts" on the summary.
    private func estimatedWeekPoints(including extra: WorkoutSession?) -> Int {
        let calendar = WeekCalendar()
        let now = Date()
        let weekSessions = sessions.completedSessions(from: calendar.weekStart(for: now), to: calendar.weekEnd(for: now))
        var inputs = weekSessions.filter { $0.id != extra?.id }.map { Self.scoreInput($0) }
        if let extra { inputs.append(Self.scoreInput(extra)) }

        var perWeek: [Date: Int] = [:]
        for s in sessions.completedSessions() { perWeek[calendar.weekStart(for: s.startedAt), default: 0] += 1 }
        let target = settings.effectiveWeeklyTarget(at: now)
        let week = LeagueScoreEstimator.WeekInput(
            sessions: inputs,
            weeklyTarget: target,
            streakWeeks: calendar.streak(before: now, sessionsPerWeek: perWeek, target: target)
        )
        return LeagueScoreEstimator.score(week).total
    }

    private static func scoreInput(_ session: WorkoutSession) -> LeagueScoreEstimator.SessionInput {
        let calendar = WeekCalendar(timeZone: session.timeZone)
        return LeagueScoreEstimator.SessionInput(
            id: session.id.uuidString,
            localDate: calendar.localDateString(for: session.startedAt),
            durationSec: session.durationSec,
            workingSets: session.completedWorkingSets.count,
            leaguePRs: (session.personalRecords ?? []).filter(\.countsForLeague).count,
            startedAt: session.startedAt,
            submittedAt: session.endedAt ?? Date()
        )
    }
}
