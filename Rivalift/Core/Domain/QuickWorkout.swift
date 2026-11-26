import Foundation

/// One workout for today from the equipment at hand, the time available and a focus.
/// It never touches the plan: quick sessions have no template, so the plan does not move.
enum QuickWorkout {
    enum Kit: String, CaseIterable, Identifiable, Sendable {
        case gym, dumbbells, none, bands
        var id: String { rawValue }

        var equipment: Set<Equipment> {
            switch self {
            case .gym: Set(Equipment.allCases)
            case .dumbbells: [.dumbbell, .bodyweight]
            case .none: [.bodyweight]
            case .bands: [.band, .bodyweight]
            }
        }
    }

    enum Focus: String, CaseIterable, Identifiable, Sendable {
        case fullBody, upper, legs, core
        var id: String { rawValue }

        /// Muscles to fill, in order; one exercise per slot.
        var slots: [Set<MuscleGroup>] {
            switch self {
            case .fullBody: [[.quads, .glutes], [.chest, .shoulders], [.back], [.hamstrings, .glutes], [.core], [.biceps, .triceps]]
            case .upper: [[.chest], [.back], [.shoulders], [.chest], [.biceps], [.triceps]]
            case .legs: [[.quads], [.hamstrings], [.glutes], [.quads, .glutes], [.calves], [.core]]
            case .core: [[.core], [.glutes], [.core], [.back], [.core], [.core]]
            }
        }
    }

    struct Option: Equatable, Sendable {
        var id: UUID
        var primary: MuscleGroup
        var equipment: Equipment
        var isCompound: Bool = false
        var isDuration: Bool = false
    }

    struct Item: Equatable, Hashable, Sendable {
        var id: UUID
        var sets: Int
        /// 0 for timed exercises (plank).
        var reps: Int
    }

    static let minutes = [15, 30, 45, 60]

    /// Moves too hard for a workout picked on the spot.
    // ponytail: hand-picked keys; add a difficulty field to exercises.json if this list grows
    static let advancedKeys: Set<String> = ["pistol_squat", "sissy_squat", "nordic_hamstring_curl"]

    /// 15 min: 3 exercises, then one more per 15 minutes.
    static func exerciseCount(minutes: Int) -> Int {
        min(6, max(3, minutes / 15 + 2))
    }

    /// Fills the focus slots from exercises the kit allows, compound lifts first, no repeats.
    /// `shuffle` picks a different exercise per slot; the same value gives the same workout.
    /// - Parameter options: candidates in preference order (seed order works well).
    static func build(kit: Kit, minutes: Int, focus: Focus, from options: [Option], shuffle: Int = 0) -> [Item] {
        let pool = options.filter { kit.equipment.contains($0.equipment) }
        let count = exerciseCount(minutes: minutes)
        var used = Set<UUID>()
        var items: [Item] = []
        for (index, slot) in focus.slots.enumerated() where items.count < count {
            let candidates = pool.filter { slot.contains($0.primary) && !used.contains($0.id) }
            let ordered = candidates.filter(\.isCompound) + candidates.filter { !$0.isCompound }
            guard !ordered.isEmpty else { continue }
            let pick = ordered[(shuffle + index * shuffle) % ordered.count]
            used.insert(pick.id)
            items.append(Item(id: pick.id, sets: pick.isCompound ? 3 : 2, reps: pick.isDuration ? 0 : (pick.isCompound ? 10 : 12)))
        }
        return items
    }
}
