import SwiftUI

/// Group leaderboard (appendix A.10, SOC-05 … SOC-07, SOC-11, SOC-15): countdown, the
/// user's position, ranked members, one tab per Custom category, and invites.
struct GroupLeaderboardView: View {
    @Environment(AppEnvironment.self) private var env
    let groupID: String
    @State private var boardID: String?
    @State private var isScoringPresented = false
    @State private var isInvitePresented = false
    @State private var isSettingsPresented = false

    var body: some View {
        if let group = env.leagues.group(id: groupID) {
            content(group)
        } else {
            ContentUnavailableView("Group not found", systemImage: "person.3")
        }
    }

    private func content(_ group: LeagueGroup) -> some View {
        let now = Date()
        let calendar = WeekCalendar(timeZone: group.timeZone)
        let boards = env.leagueBoards(for: group, now: now)
        let board = boards.first { $0.id == boardID } ?? boards.first
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if env.leagues.isPreview { PreviewNotice() }
                header(group, calendar: calendar, now: now)
                if let pending = group.pendingMode {
                    Label("\(pending.displayName) starts next Monday. This week stays \(group.mode.displayName).", systemImage: "calendar.badge.clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if boards.count > 1 {
                    BoardTabs(boards: boards, selection: Binding(get: { board?.id }, set: { boardID = $0 }))
                }
                if let board {
                    if let mine = board.me { MyPositionCard(row: mine) }
                    if group.friends.isEmpty {
                        invitePrompt
                    } else {
                        VStack(spacing: 0) {
                            ForEach(board.rows) { row in
                                StandingRow(row: row, showsMovement: board.id == boards.first?.id)
                                if row.id != board.rows.last?.id { Divider().padding(.leading, 64) }
                            }
                        }
                        .padding(.vertical, 6)
                        .glassCard(cornerRadius: Theme.cornerRadius)
                    }
                }
                VStack(spacing: 0) {
                    Button { isScoringPresented = true } label: {
                        LinkRow(title: "How this league works", systemImage: "questionmark.circle")
                    }
                    if !group.lastWeek.isEmpty {
                        Divider().padding(.leading, 52)
                        NavigationLink {
                            WeekResultsView(group: group, weekNumber: calendar.weekNumber(for: now) - 1)
                        } label: {
                            LinkRow(title: "Last week's results", systemImage: "trophy")
                        }
                    }
                }
                .buttonStyle(.plain)
                .glassCard(cornerRadius: Theme.cornerRadius)
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Group settings", systemImage: "gearshape") { isSettingsPresented = true }
                    .accessibilityIdentifier("groupSettingsButton")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                isInvitePresented = true
            } label: {
                Label("Invite friends", systemImage: "person.badge.plus")
            }
            .buttonStyle(.primary)
            .padding()
            .background(Theme.bottomFade)
            .accessibilityIdentifier("inviteFriendsButton")
        }
        .sheet(isPresented: $isScoringPresented) { LeagueModeExplainer(mode: group.mode) }
        .sheet(isPresented: $isInvitePresented) {
            NavigationStack { InviteView(group: group) }
        }
        .sheet(isPresented: $isSettingsPresented) {
            GroupSettingsView(group: group).environment(env)
        }
    }

    private func header(_ group: LeagueGroup, calendar: WeekCalendar, now: Date) -> some View {
        let start = calendar.weekStart(for: now)
        let lastDay = calendar.calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let closesAt = calendar.weekEnd(for: now)
        return HStack(spacing: 14) {
            GroupEmoji(emoji: group.emoji, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name).font(.title2.bold())
                Text("Week \(calendar.weekNumber(for: now)) · \(start.formatted(.dateTime.day().month())) – \(lastDay.formatted(.dateTime.day().month()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ModeBadge(mode: group.mode)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Label(CountdownText.ends(from: context.date, to: closesAt), systemImage: "clock")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    /// SOC-11: fewer than two members.
    private var invitePrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.wave.2.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Invite friends to start the league").font(.headline)
            Text("Leagues need at least two people. Share the invite code and your friends' workouts start counting right away.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

/// Overall plus one tab per Custom category (SOC-15).
struct BoardTabs: View {
    let boards: [LeagueBoard]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(boards) { board in
                    let isSelected = board.id == selection
                    Button {
                        selection = board.id
                    } label: {
                        Text(board.title)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(isSelected ? Theme.accent : Theme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

struct ModeBadge: View {
    let mode: LeagueMode

    var body: some View {
        Text(mode.displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.elevated, in: Capsule())
    }
}

/// "#2 · +1.3% · Back Squat +2.0% … · 0.8% behind Andi" (appendix A.10).
struct MyPositionCard: View {
    let row: BoardRow

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your rank").font(.statLabel).foregroundStyle(.secondary)
                Text(row.rank.map { "#\($0)" } ?? "—").font(.heroNumber).monospacedDigit()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(row.rank == nil ? String(localized: "Not ranked yet") : row.valueText).font(.title3.bold()).monospacedDigit()
                Text(row.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let gap = row.gapText {
                    Text(gap).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                }
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

/// Rank, avatar, name, detail, value and movement (SOC-06).
struct StandingRow: View {
    let row: BoardRow
    var showsMovement = true

    var body: some View {
        HStack(spacing: 12) {
            RankBadge(rank: row.rank)
            AvatarView(name: row.name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.name).font(.body.weight(row.isMe ? .semibold : .regular)).lineLimit(1)
                    if row.isMe {
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                Text(row.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            Text(row.valueText).font(.headline).monospacedDigit()
            if showsMovement { Movement(value: row.movement).frame(width: 28) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(row.isMe ? Theme.accent.opacity(0.08) : .clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let who = row.isMe ? String(localized: "you") : row.name
        var text = row.rank.map { String(localized: "Rank \($0), \(who), \(row.valueText), \(row.detail)") }
            ?? String(localized: "\(who), not ranked yet, \(row.detail)")
        if row.movement > 0 { text += String(localized: ", up \(row.movement)") }
        if row.movement < 0 { text += String(localized: ", down \(-row.movement)") }
        return text
    }
}

struct RankBadge: View {
    let rank: Int?

    var body: some View {
        Group {
            switch rank {
            case 1: Image(systemName: "medal.fill").foregroundStyle(Theme.gold)
            case 2: Image(systemName: "medal.fill").foregroundStyle(Theme.silver)
            case 3: Image(systemName: "medal.fill").foregroundStyle(Theme.bronze)
            case let rank?: Text("\(rank)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            case nil: Text("–").font(.subheadline).foregroundStyle(.tertiary)
            }
        }
        .font(.title3)
        .frame(width: 28)
    }
}

private struct Movement: View {
    let value: Int

    var body: some View {
        if value > 0 {
            Label("\(value)", systemImage: "arrow.up").labelStyle(.iconOnly).foregroundStyle(.green)
        } else if value < 0 {
            Label("\(-value)", systemImage: "arrow.down").labelStyle(.iconOnly).foregroundStyle(.red)
        } else {
            Image(systemName: "minus").foregroundStyle(.tertiary)
        }
    }
}

private struct LinkRow: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(Theme.accent).frame(width: 28)
            Text(title).foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: Theme.minTap + 8)
        .contentShape(Rectangle())
    }
}
