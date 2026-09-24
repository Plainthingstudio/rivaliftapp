import Foundation

/// SET-04: exports every completed session as CSV (one row per set).
enum CSVExporter {
    struct Row: Sendable {
        var date: Date
        var workout: String
        var durationSec: Int
        var exercise: String
        var setOrder: Int
        var setType: SetType
        var weightKg: Double
        var reps: Int
        var durationSetSec: Int
        var isPR: Bool
        var notes: String
    }

    static let header = "date,workout,duration_sec,exercise,set,set_type,weight_kg,weight_lb,reps,set_duration_sec,is_pr,notes"

    static func csv(rows: [Row]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = [header]
        for row in rows {
            let fields: [String] = [
                formatter.string(from: row.date),
                escape(row.workout),
                String(row.durationSec),
                escape(row.exercise),
                String(row.setOrder),
                row.setType.rawValue,
                String(format: "%.2f", row.weightKg),
                String(format: "%.2f", UnitConverter.fromKg(row.weightKg, to: .lb)),
                String(row.reps),
                String(row.durationSetSec),
                row.isPR ? "1" : "0",
                escape(row.notes),
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    @MainActor
    static func rows(from sessions: [WorkoutSession]) -> [Row] {
        sessions.sorted { $0.startedAt < $1.startedAt }.flatMap { session in
            session.orderedExercises.flatMap { entry in
                entry.orderedSets.filter(\.isCompleted).enumerated().map { index, set in
                    Row(
                        date: session.startedAt,
                        workout: session.name,
                        durationSec: session.durationSec,
                        exercise: entry.exercise?.name ?? "Unknown",
                        setOrder: index + 1,
                        setType: set.setType,
                        weightKg: set.weightKg,
                        reps: set.reps,
                        durationSetSec: set.durationSec,
                        isPR: set.isPR,
                        notes: entry.notes
                    )
                }
            }
        }
    }

    /// Writes the CSV to a temporary file for the share sheet.
    @MainActor
    static func exportFile(sessions: [WorkoutSession]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rivalift-export.csv")
        try csv(rows: rows(from: sessions)).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
