import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    /// Built-in program this day belongs to, e.g. "Push/Pull/Legs 6×". Empty for user templates.
    var programName: String = ""
    var isBuiltIn: Bool = false
    var createdAt: Date = Date()
    var lastUsedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]? = []

    init(name: String, programName: String = "", isBuiltIn: Bool = false) {
        self.name = name
        self.programName = programName
        self.isBuiltIn = isBuiltIn
    }

    var orderedExercises: [TemplateExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var totalSets: Int { orderedExercises.reduce(0) { $0 + $1.setCount } }

    /// Rough duration: ~45 s per set plus rest between sets.
    var estimatedDurationMin: Int {
        let seconds = orderedExercises.reduce(0) { $0 + $1.setCount * (45 + $1.restSec) }
        return max(5, Int((Double(seconds) / 60 / 5).rounded()) * 5)
    }
}

@Model
final class TemplateExercise {
    var id: UUID = UUID()
    var order: Int = 0
    var setCount: Int = 3
    var targetReps: Int = 10
    var restSec: Int = 90
    var template: WorkoutTemplate?
    var exercise: Exercise?

    init(order: Int, setCount: Int, targetReps: Int, restSec: Int, exercise: Exercise?) {
        self.order = order
        self.setCount = setCount
        self.targetReps = targetReps
        self.restSec = restSec
        self.exercise = exercise
    }
}
