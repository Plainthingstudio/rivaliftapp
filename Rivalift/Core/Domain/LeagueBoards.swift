import Foundation

/// How a group competes (SOC-12). Locked for the running week; changes start next week.
enum LeagueMode: Hashable, Sendable {
    case consistency
    case strength(StrengthSetup)
    case custom([CustomCategoryScorer.Category])

    enum Kind: String, CaseIterable, Identifiable, Hashable, Sendable {
        case consistency, strength, custom
        var id: String { rawValue }
    }

    var kind: Kind {
        switch self {
        case .consistency: .consistency
        case .strength: .strength
        case .custom: .custom
        }
    }

    /// Exercises whose sets decide this mode (SOC-17), by key.
    var competedExerciseKeys: [String] {
        switch self {
        case .consistency: []
        case .strength(let setup): setup.exerciseKeys
        case .custom(let categories): categories.map(\.exerciseKey)
        }
    }
}

/// Strength mode settings (SOC-13).
struct StrengthSetup: Hashable, Sendable {
    static let defaultLifts = ["barbell_back_squat", "barbell_bench_press", "deadlift"]
    /// PRD SOC-13 said 1–3; raised to 5 on 26 Sep 2026 at Herdetya's request.
    static let liftRange = 1...5

    var exerciseKeys: [String] = defaultLifts
    var comparison: StrengthScorer.Comparison = .relative
}

extension CustomCategoryScorer {
    static let categoryRange = 1...5

    /// Popular categories to start from (SOC-16).
    static let presets: [Category] = [
        Category(id: "preset-pull-up", exerciseKey: "pull_up", metric: .maxReps, comparison: .absolute, minReps: nil),
        Category(id: "preset-push-up", exerciseKey: "push_up", metric: .totalReps, comparison: .absolute, minReps: nil),
        Category(id: "preset-bench", exerciseKey: "barbell_bench_press", metric: .estimated1RM, comparison: .absolute, minReps: nil),
        Category(id: "preset-curl", exerciseKey: "dumbbell_bicep_curl", metric: .bestSetVolume, comparison: .absolute, minReps: 8),
        Category(id: "preset-plank", exerciseKey: "plank", metric: .longestHold, comparison: .absolute, minReps: nil),
    ]
}

/// One member's inputs for every mode.
struct LeagueMemberInput: Sendable {
    /// Name, identity, Consistency score and yesterday's rank.
    var entry: LeagueEntry
    /// Strength lifts by exercise key.
    var lifts: [String: StrengthScorer.LiftInput] = [:]
    /// Custom category values by category ID, already compared (absolute or improvement).
    var categoryValues: [String: Double] = [:]
}

/// A row ready to show: rank, formatted value, detail line, gap to the member above.
struct BoardRow: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var isMe: Bool
    /// Nil when the member has no counted value yet (baseline week, no entry).
    var rank: Int?
    var valueText: String
    var detail: String
    var movement: Int = 0
    var gapText: String?
}

struct LeagueBoard: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var rows: [BoardRow]

    var me: BoardRow? { rows.first { $0.isMe } }
}

/// Builds leaderboards for every mode (SOC-06, SOC-15). The server computes the final
/// numbers with the same scorers; this turns them into rows.
enum LeagueBoards {
    static func boards(
        mode: LeagueMode,
        members: [LeagueMemberInput],
        unit: WeightUnit,
        exerciseName: (String) -> String
    ) -> [LeagueBoard] {
        switch mode {
        case .consistency:
            [consistency(members.map(\.entry))]
        case .strength(let setup):
            [strength(members, setup: setup, unit: unit, exerciseName: exerciseName)]
        case .custom(let categories):
            custom(members, categories: categories, unit: unit, exerciseName: exerciseName)
        }
    }

    // MARK: Consistency

    static func consistency(_ entries: [LeagueEntry]) -> LeagueBoard {
        let ranked = LeagueStandings.rank(entries)
        let rows = ranked.enumerated().map { index, item in
            BoardRow(
                id: item.id,
                name: item.entry.name,
                isMe: item.entry.isMe,
                rank: item.rank,
                valueText: String(localized: "\(item.entry.score) pts"),
                detail: sessions(item.entry.validSessions),
                movement: item.movement,
                gapText: gap(index: index, values: ranked.map { Double($0.entry.score) }, names: ranked.map(\.entry.name)) { points($0) }
            )
        }
        return LeagueBoard(id: "consistency", title: String(localized: "Consistency"), rows: rows)
    }

    // MARK: Strength

    static func strength(_ members: [LeagueMemberInput], setup: StrengthSetup, unit: WeightUnit, exerciseName: (String) -> String) -> LeagueBoard {
        struct Scored { var member: LeagueMemberInput; var score: Double?; var detail: String }
        let scored = members.map { member -> Scored in
            let lifts = setup.exerciseKeys.map { member.lifts[$0] ?? StrengthScorer.LiftInput(exerciseKey: $0, baselineE1RMKg: nil, weekE1RMsKg: []) }
            let result = StrengthScorer.score(lifts, comparison: setup.comparison)
            let parts = lifts.map { lift -> String in
                let name = exerciseName(lift.exerciseKey)
                switch setup.comparison {
                case .absolute:
                    let best = StrengthScorer.bestCountedE1RM(lift)
                    return "\(name) \(best.map { WeightFormatter.string(kg: $0, unit: unit, includeUnit: true) } ?? "—")"
                case .relative:
                    guard let baseline = lift.baselineE1RMKg, baseline > 0 else { return "\(name) " + String(localized: "baseline") }
                    let best = StrengthScorer.bestCountedE1RM(lift) ?? baseline
                    return "\(name) \(percent(max(0, (best - baseline) / baseline * 100)))"
                }
            }
            return Scored(member: member, score: result.score, detail: parts.joined(separator: " · "))
        }
        let ranked = scored.filter { $0.score != nil }.sorted {
            $0.score! != $1.score! ? $0.score! > $1.score! : $0.member.entry.id < $1.member.entry.id
        }
        let unranked = scored.filter { $0.score == nil }.sorted { $0.member.entry.name < $1.member.entry.name }
        let format: (Double) -> String = setup.comparison == .relative
            ? { percent($0) }
            : { WeightFormatter.string(kg: $0, unit: unit, includeUnit: true) }
        let gapFormat: (Double) -> String = setup.comparison == .relative
            ? { String(localized: "\($0.formatted(.number.precision(.fractionLength(1))))%") }
            : { WeightFormatter.string(kg: $0, unit: unit, includeUnit: true) }

        var rows: [BoardRow] = []
        for (index, item) in ranked.enumerated() {
            let rank = sharedRank(index: index, values: ranked.map { $0.score! }, previous: rows.last?.rank)
            rows.append(BoardRow(
                id: item.member.entry.id,
                name: item.member.entry.name,
                isMe: item.member.entry.isMe,
                rank: rank,
                valueText: format(item.score!),
                detail: item.detail,
                movement: movement(previous: item.member.entry.previousRank, rank: rank),
                gapText: gap(index: index, values: ranked.map { $0.score! }, names: ranked.map(\.member.entry.name), format: gapFormat)
            ))
        }
        for item in unranked {
            rows.append(BoardRow(
                id: item.member.entry.id,
                name: item.member.entry.name,
                isMe: item.member.entry.isMe,
                rank: nil,
                valueText: "—",
                detail: setup.comparison == .relative ? String(localized: "Baseline week") : item.detail,
                gapText: setup.comparison == .relative
                    ? String(localized: "Your gains count from next week")
                    : String(localized: "Log one of the lifts to get on the board")
            ))
        }
        let title = setup.comparison == .relative ? String(localized: "Strength · Relative") : String(localized: "Strength · Absolute")
        return LeagueBoard(id: "strength", title: title, rows: rows)
    }

    // MARK: Custom

    static func custom(_ members: [LeagueMemberInput], categories: [CustomCategoryScorer.Category], unit: WeightUnit, exerciseName: (String) -> String) -> [LeagueBoard] {
        let byID = Dictionary(uniqueKeysWithValues: members.map { ($0.entry.id, $0) })
        var placementsPerCategory: [[CustomCategoryScorer.Placement]] = []
        var categoryBoards: [LeagueBoard] = []

        for category in categories {
            let values: [String: Double?] = Dictionary(uniqueKeysWithValues: members.map { ($0.entry.id, $0.categoryValues[category.id]) })
            let placements = CustomCategoryScorer.rank(values: values, metric: category.metric)
            placementsPerCategory.append(placements)
            let ranked = placements.filter { $0.rank != nil }
            let rows = placements.map { placement -> BoardRow in
                let member = byID[placement.userID]!
                let index = ranked.firstIndex { $0.userID == placement.userID }
                return BoardRow(
                    id: placement.userID,
                    name: member.entry.name,
                    isMe: member.entry.isMe,
                    rank: placement.rank,
                    valueText: placement.value.map { format($0, category: category, unit: unit) } ?? "—",
                    detail: placement.rank == nil ? String(localized: "No entry yet") : points(Double(placement.points)),
                    gapText: index.flatMap { i in
                        gap(index: i, values: ranked.map { $0.value ?? 0 }, names: ranked.map { byID[$0.userID]!.entry.name }) {
                            format($0, category: category, unit: unit, signed: false)
                        }
                    } ?? String(localized: "Log \(exerciseName(category.exerciseKey)) to get on the board")
                )
            }
            categoryBoards.append(LeagueBoard(id: category.id, title: title(for: category, exerciseName: exerciseName), rows: rows))
        }

        let overall = CustomCategoryScorer.overall(categoryPlacements: placementsPerCategory)
        let overallRows = overall.enumerated().map { index, entry -> BoardRow in
            let member = byID[entry.userID]!
            return BoardRow(
                id: entry.userID,
                name: member.entry.name,
                isMe: member.entry.isMe,
                rank: entry.rank,
                valueText: points(Double(entry.points)),
                detail: String(AttributedString(localized: "^[\(entry.categoryWins) category win](inflect: true)").characters),
                movement: movement(previous: member.entry.previousRank, rank: entry.rank),
                gapText: gap(index: index, values: overall.map { Double($0.points) }, names: overall.map { byID[$0.userID]!.entry.name }) { points($0) }
            )
        }
        return [LeagueBoard(id: "overall", title: String(localized: "Overall"), rows: overallRows)] + categoryBoards
    }

    static func title(for category: CustomCategoryScorer.Category, exerciseName: (String) -> String) -> String {
        "\(exerciseName(category.exerciseKey)) · \(category.metric.displayName)"
    }

    /// "14 reps", "62.5 kg", "1:30"; improvement values get a sign.
    static func format(_ value: Double, category: CustomCategoryScorer.Category, unit: WeightUnit, signed: Bool = true) -> String {
        let sign = signed && category.comparison == .improvement && value > 0 ? "+" : ""
        switch category.metric {
        case .maxReps, .totalReps:
            return sign + String(AttributedString(localized: "^[\(Int(value.rounded())) rep](inflect: true)").characters)
        case .heaviestWeight, .estimated1RM, .bestSetVolume:
            return sign + WeightFormatter.string(kg: value, unit: unit, includeUnit: true)
        case .longestHold:
            let seconds = Int(value.rounded())
            return sign + String(format: "%d:%02d", seconds / 60, seconds % 60)
        }
    }

    // MARK: Helpers

    private static func sessions(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) session](inflect: true)").characters)
    }

    private static func points(_ value: Double) -> String {
        let count = Int(value.rounded())
        return count == 1 ? String(localized: "1 pt") : String(localized: "\(count) pts")
    }

    private static func percent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
    }

    private static func movement(previous: Int?, rank: Int?) -> Int {
        guard let previous, let rank else { return 0 }
        return previous - rank
    }

    /// Exactly equal values share the rank of the member above.
    private static func sharedRank(index: Int, values: [Double], previous: Int?) -> Int {
        if index > 0, values[index] == values[index - 1], let previous { return previous }
        return index + 1
    }

    /// "12 pts behind Rina", "Tied with Rina" or "Leading by 12 pts".
    static func gap(index: Int, values: [Double], names: [String], format: (Double) -> String) -> String? {
        guard values.indices.contains(index) else { return nil }
        if index == 0 {
            guard values.count > 1 else { return nil }
            let lead = values[0] - values[1]
            return lead > 0 ? String(localized: "Leading by \(format(lead))") : String(localized: "Tied with \(firstName(names[1]))")
        }
        let behind = values[index - 1] - values[index]
        let name = firstName(names[index - 1])
        return behind > 0 ? String(localized: "\(format(behind)) behind \(name)") : String(localized: "Tied with \(name)")
    }

    static func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
