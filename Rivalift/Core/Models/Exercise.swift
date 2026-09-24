import Foundation
import SwiftData

/// Built-in or custom exercise. Built-ins are matched across app versions by `key` (section 14.2).
/// CloudKit compatibility: every attribute has a default, relationships are optional, no unique constraints.
@Model
final class Exercise {
    var id: UUID = UUID()
    /// Stable slug, e.g. "barbell_bench_press". Custom exercises get "custom_<uuid>".
    var key: String = ""
    var name: String = ""
    var primaryMuscleRaw: String = MuscleGroup.chest.rawValue
    /// Comma-separated `MuscleGroup` raw values.
    var secondaryMusclesRaw: String = ""
    var equipmentRaw: String = Equipment.barbell.rawValue
    var typeRaw: String = ExerciseType.weightReps.rawValue
    var isCompound: Bool = false
    var isCustom: Bool = false
    /// Custom exercises used in history are archived instead of deleted (section 14.2).
    var isArchived: Bool = false
    var defaultRestSec: Int = 90
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
    var sessionExercises: [SessionExercise]? = []
    @Relationship(deleteRule: .nullify, inverse: \TemplateExercise.exercise)
    var templateExercises: [TemplateExercise]? = []
    @Relationship(deleteRule: .nullify, inverse: \PersonalRecord.exercise)
    var personalRecords: [PersonalRecord]? = []

    init(
        key: String,
        name: String,
        primaryMuscle: MuscleGroup,
        secondaryMuscles: [MuscleGroup] = [],
        equipment: Equipment,
        type: ExerciseType,
        isCompound: Bool,
        isCustom: Bool = false,
        defaultRestSec: Int? = nil
    ) {
        self.key = key
        self.name = name
        self.primaryMuscleRaw = primaryMuscle.rawValue
        self.secondaryMusclesRaw = secondaryMuscles.map(\.rawValue).joined(separator: ",")
        self.equipmentRaw = equipment.rawValue
        self.typeRaw = type.rawValue
        self.isCompound = isCompound
        self.isCustom = isCustom
        self.defaultRestSec = defaultRestSec ?? (isCompound ? 150 : 90)
    }

    var primaryMuscle: MuscleGroup {
        get { MuscleGroup(rawValue: primaryMuscleRaw) ?? .fullBody }
        set { primaryMuscleRaw = newValue.rawValue }
    }

    var secondaryMuscles: [MuscleGroup] {
        get { secondaryMusclesRaw.split(separator: ",").compactMap { MuscleGroup(rawValue: String($0)) } }
        set { secondaryMusclesRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .bodyweight }
        set { equipmentRaw = newValue.rawValue }
    }

    var type: ExerciseType {
        get { ExerciseType(rawValue: typeRaw) ?? .weightReps }
        set { typeRaw = newValue.rawValue }
    }

    /// Dumbbell weights are entered per dumbbell (LOG-06).
    var isPerDumbbell: Bool { equipment == .dumbbell }

    var subtitle: String { "\(primaryMuscle.displayName) · \(equipment.displayName)" }
}
