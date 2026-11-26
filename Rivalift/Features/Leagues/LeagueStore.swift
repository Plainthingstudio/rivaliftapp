import Foundation
import Observation

/// A friend group with its weekly league (SOC-01, SOC-05, SOC-12).
struct LeagueGroup: Identifiable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var inviteCode: String
    var timeZone: TimeZone = .current
    /// Mode of the running week.
    var mode: LeagueMode = .consistency
    /// Mode chosen in group settings; starts next Monday (SOC-12).
    var pendingMode: LeagueMode?
    /// Everyone in the group except the user; the user's row comes from real workouts.
    var friends: [LeagueEntry]
    /// Friends' Strength lifts by member ID, then exercise key.
    var friendLifts: [String: [String: StrengthScorer.LiftInput]] = [:]
    /// Friends' Custom category values by member ID, then category ID.
    var friendCategoryValues: [String: [String: Double]] = [:]
    /// Final standings of last week, including the user (SOC-08).
    var lastWeek: [LeagueEntry] = []

    var memberCount: Int { friends.count + 1 }

    var friendInputs: [LeagueMemberInput] {
        friends.map { LeagueMemberInput(entry: $0, lifts: friendLifts[$0.id] ?? [:], categoryValues: friendCategoryValues[$0.id] ?? [:]) }
    }
}

extension LeagueMode {
    var displayName: String {
        switch self {
        case .consistency: String(localized: "Consistency")
        case .strength(let setup): setup.comparison == .relative ? String(localized: "Strength · Relative") : String(localized: "Strength · Absolute")
        case .custom(let categories): String(AttributedString(localized: "Custom · ^[\(categories.count) category](inflect: true)").characters)
        }
    }
}

/// Groups and standings for the Leagues tab.
///
/// Preview until the backend exists (M4/M5): groups come from `SampleLeagues`, and groups
/// created or joined here live in memory only. The Supabase-backed version replaces the
/// data source; the screens stay the same.
@MainActor
@Observable
final class LeagueStore {
    nonisolated static let meID = "me"
    static let nameRange = 3...30

    let isPreview = true
    private(set) var groups: [LeagueGroup]

    init(now: Date = Date()) {
        groups = SampleLeagues.groups(now: now)
    }

    func group(id: String) -> LeagueGroup? {
        groups.first { $0.id == id }
    }

    func boards(for group: LeagueGroup, me: LeagueMemberInput, unit: WeightUnit, exerciseName: (String) -> String) -> [LeagueBoard] {
        LeagueBoards.boards(mode: group.mode, members: group.friendInputs + [me], unit: unit, exerciseName: exerciseName)
    }

    func closesAt(_ group: LeagueGroup, now: Date = Date()) -> Date {
        WeekCalendar(timeZone: group.timeZone).weekEnd(for: now)
    }

    static func isValidName(_ name: String) -> Bool {
        nameRange.contains(name.trimmingCharacters(in: .whitespacesAndNewlines).count)
    }

    @discardableResult
    func createGroup(name: String, emoji: String, mode: LeagueMode = .consistency) -> LeagueGroup {
        let group = LeagueGroup(
            id: UUID().uuidString,
            name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.nameRange.upperBound)),
            emoji: emoji,
            inviteCode: InviteCode.generate(),
            mode: mode,
            friends: []
        )
        groups.insert(group, at: 0)
        return group
    }

    /// The running week keeps its mode; the new one starts next Monday (SOC-12).
    func scheduleMode(_ mode: LeagueMode, for groupID: String) {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].pendingMode = mode == groups[index].mode ? nil : mode
    }

    /// The group behind an invite code, for the confirmation step before joining (SOC-03).
    func preview(code: String, now: Date = Date()) -> LeagueGroup? {
        guard InviteCode.isValid(code) else { return nil }
        if let joined = groups.first(where: { $0.inviteCode == code }) { return joined }
        return SampleLeagues.groupForCode(code, now: now)
    }

    func isMember(of group: LeagueGroup) -> Bool {
        groups.contains { $0.id == group.id }
    }

    func join(_ group: LeagueGroup) {
        guard !isMember(of: group) else { return }
        groups.insert(group, at: 0)
    }

    /// Groups whose league counts this exercise (SOC-17).
    func groups(competingOn exerciseKey: String) -> [LeagueGroup] {
        groups.filter { $0.mode.competedExerciseKeys.contains(exerciseKey) }
    }
}

/// Made-up friends for the league preview. Consistency scores run through the real scorer;
/// Strength and Custom values are realistic lifts that the real scorers rank.
enum SampleLeagues {
    private struct Friend {
        var name: String
        var workouts: Int
        var records: Int
        var target: Int
        var streak: Int
        var previousRank: Int?
    }

    static let pullUpClubCategories = [
        CustomCategoryScorer.presets[0],
        CustomCategoryScorer.presets[3],
        CustomCategoryScorer.presets[4],
    ]

    static func groups(now: Date) -> [LeagueGroup] {
        let garage = entries([
            Friend(name: "Andi Wijaya", workouts: 3, records: 2, target: 3, streak: 2, previousRank: 2),
            Friend(name: "Budi Santoso", workouts: 4, records: 1, target: 4, streak: 3, previousRank: 1),
            Friend(name: "Citra Dewi", workouts: 2, records: 1, target: 3, streak: 0, previousRank: 3),
            Friend(name: "Fajar Nugroho", workouts: 2, records: 0, target: 3, streak: 0, previousRank: nil),
        ], now: now, prefix: "garage")
        let club = entries([
            Friend(name: "Gilang Ramadhan", workouts: 3, records: 1, target: 3, streak: 1, previousRank: 1),
            Friend(name: "Hana Pertiwi", workouts: 3, records: 2, target: 3, streak: 2, previousRank: 3),
            Friend(name: "Irfan Hakim", workouts: 2, records: 0, target: 3, streak: 0, previousRank: 2),
        ], now: now, prefix: "club")

        return [
            LeagueGroup(
                id: "sample-office",
                name: "Office Lifters",
                emoji: "🏢",
                inviteCode: "K7Q2MX",
                friends: entries([
                    Friend(name: "Rina Putri", workouts: 4, records: 3, target: 4, streak: 3, previousRank: 1),
                    Friend(name: "Dimas Pratama", workouts: 3, records: 1, target: 3, streak: 2, previousRank: 3),
                    Friend(name: "Sari Wulandari", workouts: 3, records: 4, target: 4, streak: 1, previousRank: 4),
                    Friend(name: "Ayu Lestari", workouts: 2, records: 2, target: 3, streak: 4, previousRank: 2),
                    Friend(name: "Kevin Tan", workouts: 1, records: 0, target: 3, streak: 0, previousRank: 6),
                ], now: now, prefix: "office"),
                lastWeek: finals(["Rina Putri": 97, "Dimas Pratama": 72, "Sari Wulandari": 60, "Ayu Lestari": 45, "Kevin Tan": 20], me: 85, now: now)
            ),
            LeagueGroup(
                id: "sample-garage",
                name: "Garage Gym",
                emoji: "🏋️",
                inviteCode: "GR4GEM",
                mode: .strength(StrengthSetup()),
                friends: garage,
                friendLifts: [
                    garage[0].id: lifts(squat: (120, 126), bench: (100, 103), deadlift: (150, 153)),
                    garage[1].id: lifts(squat: (140, 143), bench: (110, 112), deadlift: (180, 180)),
                    garage[2].id: lifts(squat: (70, 74), bench: (45, 46), deadlift: (90, nil)),
                    garage[3].id: lifts(squat: (nil, 100), bench: (nil, 80), deadlift: (nil, 120)),
                ]
            ),
            LeagueGroup(
                id: "sample-club",
                name: "Pull-up Club",
                emoji: "💪",
                inviteCode: "PULL8P",
                mode: .custom(pullUpClubCategories),
                friends: club,
                friendCategoryValues: [
                    club[0].id: ["preset-pull-up": 14, "preset-curl": 144, "preset-plank": 75],
                    club[1].id: ["preset-pull-up": 11, "preset-curl": 160, "preset-plank": 120],
                    club[2].id: ["preset-pull-up": 9, "preset-plank": 60],
                ]
            ),
            LeagueGroup(
                id: "sample-campus",
                name: "Campus Crew",
                emoji: "🎓",
                inviteCode: "B4NDRA",
                friends: entries([
                    Friend(name: "Bayu Saputra", workouts: 2, records: 1, target: 2, streak: 1, previousRank: 1),
                    Friend(name: "Nadia Rahma", workouts: 1, records: 2, target: 3, streak: 0, previousRank: 2),
                ], now: now, prefix: "campus"),
                lastWeek: finals(["Bayu Saputra": 55, "Nadia Rahma": 30], me: 40, now: now)
            ),
        ]
    }

    /// Any valid code that isn't one of the user's groups resolves to this sample group.
    static func groupForCode(_ code: String, now: Date) -> LeagueGroup {
        LeagueGroup(
            id: "sample-\(code)",
            name: "Iron Squad",
            emoji: "💪",
            inviteCode: code,
            friends: entries([
                Friend(name: "Andi Wijaya", workouts: 3, records: 2, target: 3, streak: 2, previousRank: 1),
                Friend(name: "Putri Anggraini", workouts: 2, records: 0, target: 3, streak: 1, previousRank: 2),
                Friend(name: "Reza Fahlevi", workouts: 1, records: 1, target: 4, streak: 0, previousRank: 3),
            ], now: now, prefix: code)
        )
    }

    /// (8-week best e1RM, best e1RM this week) per default lift; a nil baseline is a baseline week.
    private static func lifts(squat: (Double?, Double?), bench: (Double?, Double?), deadlift: (Double?, Double?)) -> [String: StrengthScorer.LiftInput] {
        let pairs = zip(StrengthSetup.defaultLifts, [squat, bench, deadlift])
        return Dictionary(uniqueKeysWithValues: pairs.map { key, value in
            (key, StrengthScorer.LiftInput(exerciseKey: key, baselineE1RMKg: value.0, weekE1RMsKg: value.1.map { [$0] } ?? []))
        })
    }

    private static func entries(_ friends: [Friend], now: Date, prefix: String) -> [LeagueEntry] {
        friends.enumerated().map { index, friend in
            let sessions = (0..<friend.workouts).map { day in
                let start = now.addingTimeInterval(TimeInterval(-(day + 1) * 86_400))
                return LeagueScoreEstimator.SessionInput(
                    id: "\(prefix)-\(index)-\(day)",
                    localDate: "day-\(day)",
                    durationSec: 55 * 60,
                    workingSets: 14,
                    leaguePRs: day == 0 ? friend.records : 0,
                    startedAt: start,
                    submittedAt: start.addingTimeInterval(3_600)
                )
            }
            let score = LeagueScoreEstimator.score(.init(sessions: sessions, weeklyTarget: friend.target, streakWeeks: friend.streak))
            return LeagueEntry(
                id: "\(prefix)-\(index)",
                name: friend.name,
                isMe: false,
                score: score.total,
                validSessions: score.validSessions,
                target: friend.target,
                reachedScoreAt: now.addingTimeInterval(TimeInterval(-(index + 1) * 3_600)),
                previousRank: friend.previousRank
            )
        }
    }

    private static func finals(_ scores: [String: Int], me: Int, now: Date) -> [LeagueEntry] {
        let lastWeek = now.addingTimeInterval(-7 * 86_400)
        var entries = scores.map { name, score in
            LeagueEntry(id: "last-\(name)", name: name, isMe: false, score: score, validSessions: score / 20,
                        target: 3, reachedScoreAt: lastWeek, previousRank: nil)
        }
        entries.append(LeagueEntry(id: LeagueStore.meID, name: String(localized: "You"), isMe: true, score: me,
                                   validSessions: me / 20, target: 3, reachedScoreAt: lastWeek, previousRank: nil))
        return entries
    }
}
