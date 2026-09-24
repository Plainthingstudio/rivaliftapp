import Foundation
import SwiftData
import Testing
@testable import Rivalift

/// Integration tests against an in-memory SwiftData store.
@MainActor
@Suite("SessionRepository")
struct SessionRepositoryTests {
    let container: ModelContainer
    let sessions: SessionRepository
    let exercises: ExerciseRepository
    let bench: Exercise

    init() {
        container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        sessions = SessionRepository(context: context)
        exercises = ExerciseRepository(context: context)
        bench = Exercise(key: "barbell_bench_press", name: "Barbell Bench Press", primaryMuscle: .chest, equipment: .barbell, type: .weightReps, isCompound: true)
        context.insert(bench)
    }

    private func log(_ weights: [(Double, Int)], startedAt: Date) -> WorkoutSession {
        let session = sessions.startEmpty()
        session.startedAt = startedAt
        let entry = sessions.addExercise(bench, to: session)
        for (index, (weight, reps)) in weights.enumerated() {
            let existing = entry.orderedSets
            let set = index < existing.count ? existing[index] : sessions.addSet(to: entry)
            set.weightKg = weight
            set.reps = reps
            set.hasWeight = true
            set.hasReps = true
            set.isCompleted = true
            set.completedAt = startedAt.addingTimeInterval(600)
        }
        sessions.finish(session, endedAt: startedAt.addingTimeInterval(3600))
        return session
    }

    @Test func onlyOneActiveSession() {
        let first = sessions.startEmpty()
        #expect(sessions.activeSession()?.id == first.id)
        sessions.discard(first)
        #expect(sessions.activeSession() == nil)
    }

    @Test func firstLogIsBaselineThenRecords() {
        let day = 86_400.0
        let first = log([(80, 8)], startedAt: Date().addingTimeInterval(-3 * day))
        #expect((first.personalRecords ?? []).isEmpty)

        let second = log([(85, 6)], startedAt: Date().addingTimeInterval(-day))
        let types = Set((second.personalRecords ?? []).map(\.prType))
        #expect(types.contains(.weight))
        #expect(second.orderedExercises.first?.orderedSets.first?.isPR == true)
    }

    @Test func previousColumnUsesLastSession() {
        _ = log([(60, 10), (62.5, 8)], startedAt: Date().addingTimeInterval(-86_400))
        let previous = sessions.previousSets(for: bench, excluding: nil)
        #expect(previous.map(\.weightKg) == [60, 62.5])
    }

    @Test func finishDropsUncheckedSets() {
        let session = sessions.startEmpty()
        let entry = sessions.addExercise(bench, to: session)
        let done = entry.orderedSets[0]
        done.weightKg = 50
        done.reps = 5
        done.isCompleted = true
        done.completedAt = Date()
        sessions.addSet(to: entry)
        sessions.finish(session)
        #expect(session.status == .completed)
        #expect(session.orderedExercises.first?.orderedSets.count == 1)
    }

    @Test func deletingSessionRecomputesRecords() {
        let day = 86_400.0
        _ = log([(80, 8)], startedAt: Date().addingTimeInterval(-3 * day))
        let middle = log([(90, 5)], startedAt: Date().addingTimeInterval(-2 * day))
        let last = log([(85, 5)], startedAt: Date().addingTimeInterval(-day))
        #expect(!(middle.personalRecords ?? []).isEmpty)
        #expect(!(last.personalRecords ?? []).contains { $0.prType == .weight })

        sessions.delete(middle)
        #expect((last.personalRecords ?? []).contains { $0.prType == .weight })
    }

    @Test func archivedCustomExerciseStaysInHistory() {
        let custom = exercises.createCustom(name: "My Press", primaryMuscle: .shoulders, secondaryMuscles: [], equipment: .machine, type: .weightReps, isCompound: false)
        let session = sessions.startEmpty()
        let entry = sessions.addExercise(custom, to: session)
        entry.orderedSets[0].reps = 10
        entry.orderedSets[0].isCompleted = true
        sessions.finish(session)

        exercises.deleteCustom(custom)
        #expect(custom.isArchived)
        #expect(!exercises.activeExercises().contains { $0.id == custom.id })
        #expect(sessions.history(for: custom).count == 1)
    }
}
