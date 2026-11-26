import Foundation
import SwiftData

/// JSON shapes of the bundled `exercises.json` and `templates.json` (LIB-01, LIB-04).
struct ExerciseSeed: Codable, Sendable {
    var key: String
    var name: String
    var primaryMuscle: MuscleGroup
    var secondaryMuscles: [MuscleGroup]
    var equipment: Equipment
    var type: ExerciseType
    var isCompound: Bool
    var defaultRestSec: Int
}

/// How-to text for a built-in exercise, from the bundled `exercise_guides.json` keyed by exercise key.
struct ExerciseGuide: Codable, Sendable {
    var about: String
    var steps: [String]
    var tips: [String]
}

struct ProgramSeed: Codable, Sendable {
    struct Day: Codable, Sendable {
        var name: String
        var exercises: [Item]
    }

    struct Item: Codable, Sendable {
        var exerciseKey: String
        var sets: Int
        var targetReps: Int
        var restSec: Int?
    }

    var program: String
    var days: [Day]
}

enum SeedLoader {
    static func loadExercises(bundle: Bundle = .main) throws -> [ExerciseSeed] {
        try decode("exercises", bundle: bundle)
    }

    static func loadGuides(bundle: Bundle = .main) throws -> [String: ExerciseGuide] {
        try decode("exercise_guides", bundle: bundle)
    }

    static func loadPrograms(bundle: Bundle = .main) throws -> [ProgramSeed] {
        try decode("templates", bundle: bundle)
    }

    private static func decode<T: Decodable>(_ name: String, bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    /// Inserts missing built-in exercises and refreshes names of existing ones (matched by
    /// `key`, so renames never break history). Safe to run on every launch.
    @MainActor
    static func seedIfNeeded(context: ModelContext, bundle: Bundle = .main) throws {
        let seeds = try loadExercises(bundle: bundle)
        let existing = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { !$0.isCustom }))
        var byKey: [String: Exercise] = [:]
        for exercise in existing {
            if byKey[exercise.key] == nil {
                byKey[exercise.key] = exercise
            } else {
                // iCloud can deliver the same seed from two devices; uniqueness is enforced in code.
                context.delete(exercise)
            }
        }
        for seed in seeds {
            if let exercise = byKey[seed.key] {
                exercise.name = seed.name
                exercise.primaryMuscle = seed.primaryMuscle
                exercise.secondaryMuscles = seed.secondaryMuscles
                exercise.equipment = seed.equipment
                exercise.type = seed.type
                exercise.isCompound = seed.isCompound
            } else {
                let exercise = Exercise(
                    key: seed.key,
                    name: seed.name,
                    primaryMuscle: seed.primaryMuscle,
                    secondaryMuscles: seed.secondaryMuscles,
                    equipment: seed.equipment,
                    type: seed.type,
                    isCompound: seed.isCompound,
                    defaultRestSec: seed.defaultRestSec
                )
                context.insert(exercise)
                byKey[seed.key] = exercise
            }
        }

        let builtInTemplates = try context.fetch(FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.isBuiltIn }))
        var existingTemplateKeys = Set<String>()
        for template in builtInTemplates {
            let key = "\(template.programName)|\(template.name)"
            if existingTemplateKeys.contains(key) {
                context.delete(template)
            } else {
                existingTemplateKeys.insert(key)
            }
        }
        for program in try loadPrograms(bundle: bundle) {
            for day in program.days where !existingTemplateKeys.contains("\(program.program)|\(day.name)") {
                let template = WorkoutTemplate(name: day.name, programName: program.program, isBuiltIn: true)
                context.insert(template)
                for (index, item) in day.exercises.enumerated() {
                    guard let exercise = byKey[item.exerciseKey] else { continue }
                    let entry = TemplateExercise(
                        order: index,
                        setCount: item.sets,
                        targetReps: item.targetReps,
                        restSec: item.restSec ?? exercise.defaultRestSec,
                        exercise: exercise
                    )
                    entry.template = template
                    context.insert(entry)
                }
            }
        }
        try context.save()
    }
}
