import Foundation
import SwiftData

enum SessionStatus: String, Codable, Sendable {
    case active, completed, discarded
}

enum SyncState: String, Codable, Sendable {
    /// Not relevant for the server yet (no account) or not queued.
    case local
    case pending
    case synced
    case rejected
}

@Model
final class WorkoutSession {
    /// Client-generated so server upserts are idempotent (section 9).
    var id: UUID = UUID()
    var name: String = ""
    var startedAt: Date = Date()
    var endedAt: Date?
    var statusRaw: String = SessionStatus.active.rawValue
    var notes: String = ""
    var syncStateRaw: String = SyncState.local.rawValue
    /// Device time zone when the session started; decides its local date (section 14.1).
    var timeZoneID: String = TimeZone.current.identifier
    var templateID: UUID?
    /// Updated whenever a set is completed; used for stale-session handling.
    var lastActivityAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]? = []
    @Relationship(deleteRule: .cascade, inverse: \PersonalRecord.session)
    var personalRecords: [PersonalRecord]? = []

    init(name: String, startedAt: Date = Date(), templateID: UUID? = nil) {
        self.name = name
        self.startedAt = startedAt
        self.templateID = templateID
        self.lastActivityAt = startedAt
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .local }
        set { syncStateRaw = newValue.rawValue }
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    var orderedExercises: [SessionExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var completedWorkingSets: [SetEntry] {
        orderedExercises.flatMap(\.orderedSets).filter { $0.isCompleted && $0.setType.isWorking }
    }

    var completedSetCount: Int {
        orderedExercises.flatMap(\.orderedSets).filter(\.isCompleted).count
    }

    var totalVolumeKg: Double {
        completedWorkingSets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    var totalReps: Int { completedWorkingSets.reduce(0) { $0 + $1.reps } }

    var lastCompletedSetAt: Date? {
        orderedExercises.flatMap(\.orderedSets).compactMap(\.completedAt).max()
    }

    var durationSec: Int {
        Int((endedAt ?? Date()).timeIntervalSince(startedAt))
    }
}

@Model
final class SessionExercise {
    var id: UUID = UUID()
    var order: Int = 0
    var notes: String = ""
    var restSec: Int = 90
    /// Target reps copied from the template, drives weight suggestions (PRG-01).
    var targetReps: Int?
    var session: WorkoutSession?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry]? = []

    init(order: Int, exercise: Exercise?, restSec: Int, targetReps: Int? = nil) {
        self.order = order
        self.exercise = exercise
        self.restSec = restSec
        self.targetReps = targetReps
    }

    var orderedSets: [SetEntry] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    var samples: [SetSample] {
        orderedSets.filter(\.isCompleted).map(\.sample)
    }
}

@Model
final class SetEntry {
    var id: UUID = UUID()
    var order: Int = 0
    var setTypeRaw: String = SetType.working.rawValue
    var weightKg: Double = 0
    var reps: Int = 0
    var durationSec: Int = 0
    var isCompleted: Bool = false
    var completedAt: Date?
    var isPR: Bool = false
    /// Whether weight/reps were typed by the user (vs. still empty placeholders).
    var hasWeight: Bool = false
    var hasReps: Bool = false
    var sessionExercise: SessionExercise?

    init(order: Int, setType: SetType = .working) {
        self.order = order
        self.setTypeRaw = setType.rawValue
    }

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

    var sample: SetSample {
        SetSample(setType: setType, weightKg: weightKg, reps: reps, durationSec: durationSec)
    }
}
