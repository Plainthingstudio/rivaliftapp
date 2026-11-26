import Foundation
import SwiftData

@MainActor
final class ExerciseRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Exercises available in the picker (archived ones are hidden, LIB-02).
    func activeExercises() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func exercise(key: String) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private lazy var guides: [String: ExerciseGuide] = (try? SeedLoader.loadGuides()) ?? [:]

    /// How-to text for built-in exercises; nil for custom ones.
    func guide(for exercise: Exercise) -> ExerciseGuide? {
        guides[exercise.key]
    }

    func exercise(id: UUID) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// LIB-02 search and filters.
    func search(_ text: String, muscles: Set<MuscleGroup>, equipment: Set<Equipment>) -> [Exercise] {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        return activeExercises().filter { exercise in
            (query.isEmpty || exercise.name.lowercased().contains(query))
                && (muscles.isEmpty || muscles.contains(exercise.primaryMuscle))
                && (equipment.isEmpty || equipment.contains(exercise.equipment))
        }
    }

    /// Most recently used exercises, newest first.
    func recentExercises(limit: Int = 8) -> [Exercise] {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == "completed" },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        let sessions = (try? context.fetch(descriptor)) ?? []
        var seen = Set<UUID>()
        var result: [Exercise] = []
        for session in sessions {
            for item in session.orderedExercises {
                guard let exercise = item.exercise, !exercise.isArchived, !seen.contains(exercise.id) else { continue }
                seen.insert(exercise.id)
                result.append(exercise)
                if result.count == limit { return result }
            }
        }
        return result
    }

    /// LIB-03.
    @discardableResult
    func createCustom(name: String, primaryMuscle: MuscleGroup, secondaryMuscles: [MuscleGroup], equipment: Equipment, type: ExerciseType, isCompound: Bool) -> Exercise {
        let exercise = Exercise(
            key: "custom_\(UUID().uuidString.lowercased())",
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryMuscle: primaryMuscle,
            secondaryMuscles: secondaryMuscles,
            equipment: equipment,
            type: type,
            isCompound: isCompound,
            isCustom: true
        )
        context.insert(exercise)
        try? context.save()
        return exercise
    }

    /// Custom exercises used anywhere are archived; unused ones are deleted (section 14.2).
    func deleteCustom(_ exercise: Exercise) {
        guard exercise.isCustom else { return }
        let used = !(exercise.sessionExercises ?? []).isEmpty || !(exercise.templateExercises ?? []).isEmpty
        if used {
            exercise.isArchived = true
        } else {
            context.delete(exercise)
        }
        try? context.save()
    }

    /// Settings → Rest timer: new defaults for compound and isolation exercises (SET-02).
    func applyDefaultRest(compound: Int, isolation: Int) {
        for exercise in activeExercises() {
            exercise.defaultRestSec = exercise.isCompound ? compound : isolation
        }
        try? context.save()
    }

    func updateRest(_ exercise: Exercise, seconds: Int) {
        exercise.defaultRestSec = seconds
        try? context.save()
    }
}
