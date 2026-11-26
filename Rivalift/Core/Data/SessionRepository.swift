import Foundation
import SwiftData

/// All reads and writes of workout sessions. Every mutation saves immediately so an
/// active session survives force quit or power loss (LOG-13).
@MainActor
final class SessionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save() {
        do {
            try context.save()
        } catch {
            // Storage full etc.: the session stays in memory and the next mutation retries (section 14.2).
            lastSaveError = error
        }
    }

    private(set) var lastSaveError: Error?

    // MARK: Queries

    /// At most one active session exists at a time (section 8.1). Extra ones (e.g. from
    /// iCloud merges) are left alone; the newest wins.
    func activeSession() -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == "active" },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func completedSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == "completed" },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func completedSessions(from start: Date, to end: Date) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == "completed" && $0.startedAt >= start && $0.startedAt < end },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func session(id: UUID) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func completedSessionCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.statusRaw == "completed" }))) ?? 0
    }

    /// Completed appearances of an exercise, most recent first.
    func history(for exercise: Exercise, before date: Date? = nil, excluding sessionID: UUID? = nil) -> [SessionExercise] {
        (exercise.sessionExercises ?? [])
            .filter { item in
                guard let session = item.session, session.status == .completed else { return false }
                if let sessionID, session.id == sessionID { return false }
                if let date, session.startedAt >= date { return false }
                return true
            }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
    }

    /// LOG-04: sets of the most recent completed session of this exercise.
    func previousSets(for exercise: Exercise, excluding sessionID: UUID?) -> [SetEntry] {
        guard let last = history(for: exercise, excluding: sessionID).first else { return [] }
        return last.orderedSets.filter(\.isCompleted)
    }

    func bests(for exercise: Exercise, before date: Date, excluding sessionID: UUID? = nil) -> ExerciseBests {
        let sessions = history(for: exercise, before: date, excluding: sessionID).reversed().map(\.samples)
        return ExerciseBests.from(sessions: Array(sessions))
    }

    func recentSamples(for exercise: Exercise, excluding sessionID: UUID?, limit: Int = 5) -> [[SetSample]] {
        history(for: exercise, excluding: sessionID).prefix(limit).map(\.samples)
    }

    // MARK: Starting sessions (LOG-01)

    @discardableResult
    func startEmpty(name: String = "Workout") -> WorkoutSession {
        let session = WorkoutSession(name: name)
        context.insert(session)
        save()
        return session
    }

    /// Starts from a template. Archived exercises are skipped and returned so the UI can
    /// mention them (section 14.2).
    func start(from template: WorkoutTemplate, swaps: [UUID: Exercise] = [:]) -> (session: WorkoutSession, skipped: [String]) {
        let session = WorkoutSession(name: template.name, templateID: template.id)
        context.insert(session)
        var skipped: [String] = []
        var order = 0
        for item in template.orderedExercises {
            guard let exercise = swaps[item.id] ?? item.exercise, !exercise.isArchived else {
                if let name = item.exercise?.name { skipped.append(name) }
                continue
            }
            let entry = SessionExercise(order: order, exercise: exercise, restSec: item.restSec, targetReps: item.targetReps > 0 ? item.targetReps : nil)
            entry.session = session
            context.insert(entry)
            for index in 0..<max(item.setCount, 1) {
                let set = SetEntry(order: index)
                set.sessionExercise = entry
                context.insert(set)
            }
            order += 1
        }
        template.lastUsedAt = Date()
        save()
        return (session, skipped)
    }

    /// A session with no template (Quick Workout): exercises with their sets and target reps
    /// (0 = no rep target, e.g. a plank).
    func start(name: String, items: [(exercise: Exercise, sets: Int, reps: Int)]) -> WorkoutSession {
        let session = WorkoutSession(name: name)
        context.insert(session)
        for (order, item) in items.enumerated() {
            let entry = SessionExercise(order: order, exercise: item.exercise, restSec: item.exercise.defaultRestSec, targetReps: item.reps > 0 ? item.reps : nil)
            entry.session = session
            context.insert(entry)
            for index in 0..<max(item.sets, 1) {
                let set = SetEntry(order: index)
                set.sessionExercise = entry
                context.insert(set)
            }
        }
        save()
        return session
    }

    /// "Repeat last session": same exercises and set structure as the latest completed session.
    func repeatLast() -> WorkoutSession? {
        guard let last = completedSessions().first else { return nil }
        let session = WorkoutSession(name: last.name, templateID: last.templateID)
        context.insert(session)
        var order = 0
        for item in last.orderedExercises {
            guard let exercise = item.exercise, !exercise.isArchived else { continue }
            let entry = SessionExercise(order: order, exercise: exercise, restSec: item.restSec, targetReps: item.targetReps)
            entry.session = session
            context.insert(entry)
            for (index, old) in item.orderedSets.filter(\.isCompleted).enumerated() {
                let set = SetEntry(order: index, setType: old.setType)
                set.sessionExercise = entry
                context.insert(set)
            }
            if (entry.sets ?? []).isEmpty {
                let set = SetEntry(order: 0)
                set.sessionExercise = entry
                context.insert(set)
            }
            order += 1
        }
        save()
        return session
    }

    // MARK: Editing (LOG-02)

    @discardableResult
    func addExercise(_ exercise: Exercise, to session: WorkoutSession) -> SessionExercise {
        let entry = SessionExercise(
            order: (session.orderedExercises.last?.order ?? -1) + 1,
            exercise: exercise,
            restSec: exercise.defaultRestSec
        )
        entry.session = session
        context.insert(entry)
        let previousCount = previousSets(for: exercise, excluding: session.id).count
        for index in 0..<max(previousCount, 1) {
            let set = SetEntry(order: index)
            set.sessionExercise = entry
            context.insert(set)
        }
        save()
        return entry
    }

    func removeExercise(_ entry: SessionExercise) {
        context.delete(entry)
        if let session = entry.session {
            for (index, item) in session.orderedExercises.filter({ $0.id != entry.id }).enumerated() { item.order = index }
        }
        save()
    }

    func moveExercises(in session: WorkoutSession, from source: IndexSet, to destination: Int) {
        var items = session.orderedExercises
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() { item.order = index }
        save()
    }

    func replaceExercise(_ entry: SessionExercise, with exercise: Exercise) {
        entry.exercise = exercise
        entry.restSec = exercise.defaultRestSec
        for set in entry.orderedSets where !set.isCompleted {
            set.hasWeight = false
            set.weightKg = 0
        }
        save()
    }

    @discardableResult
    func addSet(to entry: SessionExercise) -> SetEntry {
        let last = entry.orderedSets.last
        let set = SetEntry(order: (last?.order ?? -1) + 1, setType: last?.setType == .warmup ? .warmup : .working)
        set.sessionExercise = entry
        context.insert(set)
        save()
        return set
    }

    func removeSet(_ set: SetEntry) {
        let entry = set.sessionExercise
        context.delete(set)
        if let entry {
            for (index, item) in entry.orderedSets.filter({ $0.id != set.id }).enumerated() { item.order = index }
        }
        save()
    }

    // MARK: Finishing (LOG-12, LOG-14)

    /// Completes the session and stores its personal records. Incomplete sets are removed.
    @discardableResult
    func finish(_ session: WorkoutSession, endedAt: Date = Date()) -> [PersonalRecord] {
        var kept: [SessionExercise] = []
        for entry in session.orderedExercises {
            let sets = entry.orderedSets
            if sets.contains(where: \.isCompleted) {
                for set in sets where !set.isCompleted { context.delete(set) }
                entry.order = kept.count
                kept.append(entry)
            } else {
                context.delete(entry)
            }
        }
        session.endedAt = endedAt
        session.status = .completed

        var records: [PersonalRecord] = []
        for entry in kept {
            guard let exercise = entry.exercise else { continue }
            let prior = bests(for: exercise, before: session.startedAt, excluding: session.id)
            records += storeRecords(for: entry, exercise: exercise, prior: prior, session: session)
        }
        save()
        return records
    }

    func discard(_ session: WorkoutSession) {
        context.delete(session)
        save()
    }

    /// Deletes a completed session and recomputes records of the affected exercises.
    func delete(_ session: WorkoutSession) {
        let exercises = session.orderedExercises.compactMap(\.exercise)
        context.delete(session)
        save()
        for exercise in exercises { recomputeRecords(for: exercise) }
    }

    /// Rebuilds PersonalRecord rows and set badges of an exercise from its full history.
    func recomputeRecords(for exercise: Exercise) {
        for record in exercise.personalRecords ?? [] { context.delete(record) }
        var bests = ExerciseBests()
        for entry in history(for: exercise).reversed() {
            guard let session = entry.session else { continue }
            _ = storeRecords(for: entry, exercise: exercise, prior: bests, session: session)
            bests.absorb(session: entry.samples)
        }
        save()
    }

    private func storeRecords(for entry: SessionExercise, exercise: Exercise, prior: ExerciseBests, session: WorkoutSession) -> [PersonalRecord] {
        var earlier: [SetSample] = []
        for set in entry.orderedSets where set.isCompleted {
            set.isPR = !PRCalculator.recordsForSet(set.sample, prior: prior, earlierInSession: earlier).isEmpty
            earlier.append(set.sample)
        }
        return PRCalculator.sessionRecords(entry.samples, prior: prior).map { result in
            let record = PersonalRecord(result: result, achievedAt: session.endedAt ?? session.startedAt, exercise: exercise, session: session)
            context.insert(record)
            return record
        }
    }
}
