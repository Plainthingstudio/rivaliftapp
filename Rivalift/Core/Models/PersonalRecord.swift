import Foundation
import SwiftData

/// A personal record reached in a completed session. Recomputed when a session is edited or deleted.
@Model
final class PersonalRecord {
    var id: UUID = UUID()
    var prTypeRaw: String = PRType.weight.rawValue
    /// Weight or e1RM in kg, session volume in kg, or the weight of a reps record.
    var valueKg: Double = 0
    var reps: Int = 0
    var previousValue: Double?
    var countsForLeague: Bool = false
    var achievedAt: Date = Date()
    var exercise: Exercise?
    var session: WorkoutSession?

    init(result: PRResult, achievedAt: Date, exercise: Exercise?, session: WorkoutSession?) {
        self.prTypeRaw = result.type.rawValue
        self.valueKg = result.value
        self.reps = result.reps
        self.previousValue = result.previousValue
        self.countsForLeague = result.countsForLeague
        self.achievedAt = achievedAt
        self.exercise = exercise
        self.session = session
    }

    var prType: PRType { PRType(rawValue: prTypeRaw) ?? .weight }
}
