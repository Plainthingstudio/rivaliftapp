import Foundation

/// The ⇄ sheet on a plan workout: alternatives for an exercise, and swaps that last one day.
enum ExerciseSwap {
    struct Option: Equatable, Sendable {
        var id: UUID
        var primary: MuscleGroup
        var secondary: [MuscleGroup] = []
        var isCompound: Bool = false
    }

    /// Same main muscle and not already in the workout. Most shared helper muscles first,
    /// then the same kind of lift (compound or isolation); ties keep the input order.
    static func candidates(for target: Option, from all: [Option], excluding: Set<UUID>, limit: Int = 4) -> [UUID] {
        let pool = all.enumerated().filter { $0.element.primary == target.primary && $0.element.id != target.id && !excluding.contains($0.element.id) }
        func score(_ option: Option) -> Int {
            2 * Set(option.secondary).intersection(target.secondary).count + (option.isCompound == target.isCompound ? 1 : 0)
        }
        return pool
            .sorted { (score($0.element), -$0.offset) > (score($1.element), -$1.offset) }
            .prefix(limit)
            .map(\.element.id)
    }

    /// "Just today" swaps: template exercise ID → exercise ID, valid on one local day.
    /// Stored as "2026-11-23|teID:exID,teID:exID".
    struct DaySwaps: Equatable, Sendable {
        var day: String
        var map: [UUID: UUID]

        init(day: String, map: [UUID: UUID] = [:]) {
            self.day = day
            self.map = map
        }

        init(raw: String) {
            let parts = raw.split(separator: "|", maxSplits: 1)
            day = parts.first.map(String.init) ?? ""
            var map: [UUID: UUID] = [:]
            for pair in parts.dropFirst().first?.split(separator: ",") ?? [] {
                let ids = pair.split(separator: ":").compactMap { UUID(uuidString: String($0)) }
                if ids.count == 2 { map[ids[0]] = ids[1] }
            }
            self.map = map
        }

        var raw: String {
            map.isEmpty ? "" : day + "|" + map.map { "\($0.key.uuidString):\($0.value.uuidString)" }.sorted().joined(separator: ",")
        }

        /// Swaps for `today`; yesterday's are gone.
        func active(on today: String) -> [UUID: UUID] {
            day == today ? map : [:]
        }
    }
}
