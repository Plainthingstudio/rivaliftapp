import Foundation
import SwiftData

@MainActor
final class TemplateRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func builtInTemplates() -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.isBuiltIn }, sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func userTemplates() -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { !$0.isBuiltIn }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    struct Program: Identifiable {
        var name: String
        var templates: [WorkoutTemplate]
        var id: String { name }
    }

    /// Built-in programs grouped by program name, in seed order.
    func programs() -> [Program] {
        var order: [String] = []
        var groups: [String: [WorkoutTemplate]] = [:]
        for template in builtInTemplates() {
            if groups[template.programName] == nil { order.append(template.programName) }
            groups[template.programName, default: []].append(template)
        }
        return order.map { Program(name: $0, templates: groups[$0] ?? []) }
    }

    func template(id: UUID) -> WorkoutTemplate? {
        var descriptor = FetchDescriptor<WorkoutTemplate>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func create(name: String) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        context.insert(template)
        try? context.save()
        return template
    }

    func addExercise(_ exercise: Exercise, to template: WorkoutTemplate, sets: Int = 3, targetReps: Int = 10) {
        let entry = TemplateExercise(
            order: (template.orderedExercises.last?.order ?? -1) + 1,
            setCount: sets,
            targetReps: targetReps,
            restSec: exercise.defaultRestSec,
            exercise: exercise
        )
        entry.template = template
        context.insert(entry)
        try? context.save()
    }

    func removeExercise(_ entry: TemplateExercise) {
        context.delete(entry)
        try? context.save()
    }

    func move(in template: WorkoutTemplate, from source: IndexSet, to destination: Int) {
        var items = template.orderedExercises
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() { item.order = index }
        try? context.save()
    }

    @discardableResult
    func duplicate(_ template: WorkoutTemplate) -> WorkoutTemplate {
        let copy = WorkoutTemplate(name: "\(template.name) Copy")
        context.insert(copy)
        for item in template.orderedExercises {
            let entry = TemplateExercise(order: item.order, setCount: item.setCount, targetReps: item.targetReps, restSec: item.restSec, exercise: item.exercise)
            entry.template = copy
            context.insert(entry)
        }
        try? context.save()
        return copy
    }

    func delete(_ template: WorkoutTemplate) {
        guard !template.isBuiltIn else { return }
        context.delete(template)
        try? context.save()
    }

    /// LIB-05: save a completed session as a template.
    @discardableResult
    func createFromSession(_ session: WorkoutSession, name: String) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        context.insert(template)
        for (index, item) in session.orderedExercises.enumerated() {
            let working = item.orderedSets.filter { $0.setType.isWorking && $0.isCompleted }
            let entry = TemplateExercise(
                order: index,
                setCount: max(working.count, 1),
                targetReps: working.map(\.reps).max() ?? item.targetReps ?? 10,
                restSec: item.restSec,
                exercise: item.exercise
            )
            entry.template = template
            context.insert(entry)
        }
        try? context.save()
        return template
    }

    /// A-5 "Update template": overwrite the template's exercises with the session's.
    func update(_ template: WorkoutTemplate, from session: WorkoutSession) {
        for item in template.orderedExercises { context.delete(item) }
        for (index, item) in session.orderedExercises.enumerated() {
            let working = item.orderedSets.filter { $0.setType.isWorking && $0.isCompleted }
            let entry = TemplateExercise(
                order: index,
                setCount: max(working.count, 1),
                targetReps: item.targetReps ?? working.map(\.reps).max() ?? 10,
                restSec: item.restSec,
                exercise: item.exercise
            )
            entry.template = template
            context.insert(entry)
        }
        try? context.save()
    }

    func save() { try? context.save() }
}
