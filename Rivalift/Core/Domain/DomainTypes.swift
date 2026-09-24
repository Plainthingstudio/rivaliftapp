import Foundation

/// Weight unit chosen by the user. All values are stored in kilograms (SET-01);
/// this only affects input and display.
enum WeightUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }
    var symbol: String { rawValue }
    var columnTitle: String { rawValue.uppercased() }
}

enum MuscleGroup: String, Codable, CaseIterable, Sendable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, core
    case quads, hamstrings, glutes, calves, traps, fullBody = "full_body"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBody: "Full body"
        default: rawValue.capitalized
        }
    }

    /// Used by the progression engine to pick the increment (PRG-01).
    var bodyRegion: BodyRegion {
        switch self {
        case .quads, .hamstrings, .glutes, .calves, .fullBody: .lower
        default: .upper
        }
    }
}

enum BodyRegion: String, Codable, Sendable {
    case upper, lower
}

enum Equipment: String, Codable, CaseIterable, Sendable, Identifiable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum ExerciseType: String, Codable, CaseIterable, Sendable, Identifiable {
    case weightReps = "weight_reps"
    case bodyweightReps = "bodyweight_reps"
    case duration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weightReps: "Weight × reps"
        case .bodyweightReps: "Bodyweight reps"
        case .duration: "Duration"
        }
    }
}

/// LOG-05. Warm-up sets never count for records, volume or competition.
enum SetType: String, Codable, CaseIterable, Sendable {
    case warmup = "W"
    case working = "N"
    case drop = "D"
    case failure = "F"

    /// Everything except warm-up is treated as a working set.
    var isWorking: Bool { self != .warmup }

    var badge: String? {
        switch self {
        case .working: nil
        default: rawValue
        }
    }

    var displayName: String {
        switch self {
        case .warmup: "Warm-up"
        case .working: "Working"
        case .drop: "Drop set"
        case .failure: "Failure"
        }
    }
}

enum PRType: String, Codable, CaseIterable, Sendable {
    case weight
    case e1rm
    case repsAtWeight
    case volume

    var displayName: String {
        switch self {
        case .weight: "Heaviest weight"
        case .e1rm: "Est. 1RM"
        case .repsAtWeight: "Most reps"
        case .volume: "Session volume"
        }
    }

    /// Only heaviest weight and estimated 1RM earn league points (section 6.1, R).
    var countsTowardConsistencyLeague: Bool { self == .weight || self == .e1rm }
}

/// A value-type snapshot of a logged set. Domain logic works on these so it can be
/// tested without SwiftData.
struct SetSample: Hashable, Codable, Sendable {
    var setType: SetType
    var weightKg: Double
    var reps: Int
    var durationSec: Int = 0

    init(setType: SetType = .working, weightKg: Double, reps: Int, durationSec: Int = 0) {
        self.setType = setType
        self.weightKg = weightKg
        self.reps = reps
        self.durationSec = durationSec
    }

    var volumeKg: Double { weightKg * Double(reps) }
}

/// Weight comparisons across units use a 0.05 kg tolerance so kg/lb rounding never
/// produces fake records (section 14.1).
enum WeightTolerance {
    static let kg: Double = 0.05

    static func isGreater(_ a: Double, than b: Double) -> Bool { a - b > kg }
    static func isEqual(_ a: Double, _ b: Double) -> Bool { abs(a - b) <= kg }

    /// Integer bucket for "reps at a given weight" records.
    static func bucket(_ weightKg: Double) -> Int { Int((weightKg / kg).rounded()) }
}
