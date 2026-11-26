import SwiftUI

/// Leagues tab (appendix A.9): the user's groups with rank, score and countdown, plus
/// create and join. Runs on sample data until the backend exists (M4/M5).
struct LeaguesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isScoringPresented = false
    @State private var isCreating = false

    var body: some View {
        let store = env.leagues
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenTitle(title: "Leagues", subtitle: String(localized: "Compete with friends. Get stronger together."))
                if store.groups.isEmpty { intro }
                EstimateCard(breakdown: env.leagueEstimate(), streakWeeks: env.weekProgress().streakWeeks)
                if store.groups.isEmpty {
                    howItWorks
                } else {
                    ForEach(store.groups) { group in
                        NavigationLink(value: group.id) {
                            GroupCard(group: group, mine: env.leagueBoards(for: group).first?.me, closesAt: store.closesAt(group))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button { isCreating = true } label: {
                    HStack(spacing: 6) {
                        Image("Icon_create").accessibilityHidden(true)
                        Text("Create Leagues")
                    }
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("createGroupButton")
                NavigationLink { JoinGroupView() } label: {
                    HStack(spacing: 6) {
                        Image("Icon_join").accessibilityHidden(true)
                        Text("Join with code")
                    }
                }
                .buttonStyle(.secondary)
                .accessibilityIdentifier("joinGroupButton")
                if store.isPreview {
                    Text("Preview with sample friends. Real groups go live once sign-in arrives; your own score is real.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("How scoring works") { isScoringPresented = true }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: Theme.minTap)
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Leagues")
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: String.self) { id in
            GroupLeaderboardView(groupID: id)
        }
        .navigationDestination(isPresented: $isCreating) {
            CreateGroupView(onFinish: { isCreating = false })
        }
        .sheet(isPresented: $isScoringPresented) { ScoringExplainerView() }
    }

    /// Empty state (appendix A.9, Figma "Intro").
    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            RingIcon(image: "Icon_trophy", iconSize: 20, strong: true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Weekly leagues with friends")
                Text("Create a private group, invite friends with a link or code, and compete every week from Monday to Sunday.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// How leagues work in three points (Figma "How it works").
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 12) {
            step("Icon_num1", "Train as usual", "Every valid workout (15+ min, 6+ working sets) earns points.")
            Rectangle().fill(Theme.border).frame(height: 0.5)
            step("Icon_num2", "Beat yourself", "Personal records and hitting your weekly target add bonus points.")
            Rectangle().fill(Theme.border).frame(height: 0.5)
            step("Icon_num3", "Win the week", "Fair for every level: consistency counts, not how much you lift.")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func step(_ icon: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            RingIcon(image: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout)
                Text(text).font(.caption.weight(.light)).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// "Your estimate this week" in red (Figma "Estimate"). The server has the final score.
struct EstimateCard: View {
    let breakdown: LeagueScoreEstimator.Breakdown
    let streakWeeks: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your estimate this week")
            VStack(alignment: .leading, spacing: 6) {
                Text("\(breakdown.total) pts").font(.title.weight(.medium)).monospacedDigit()
                Text("Based on \(breakdown.validSessions) workouts and a \(streakWeeks)-week streak.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

/// Says plainly that the friends and groups are examples.
struct PreviewNotice: View {
    var body: some View {
        Label {
            Text("Preview with sample friends. Real groups go live once sign-in arrives; your own score is real.")
                .font(.footnote)
        } icon: {
            Image(systemName: "eye")
        }
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// One group in the Leagues list (appendix A.9).
struct GroupCard: View {
    let group: LeagueGroup
    let mine: BoardRow?
    let closesAt: Date

    var body: some View {
        HStack(spacing: 14) {
            GroupEmoji(emoji: group.emoji, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name).font(.headline).foregroundStyle(.primary)
                Text("\(group.memberCount) members · \(group.mode.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(CountdownText.ends(from: context.date, to: closesAt))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            Spacer()
            if let mine {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(mine.rank.map { "#\($0)" } ?? "—").font(.title3.bold()).monospacedDigit()
                    Text(mine.rank == nil ? String(localized: "Not ranked") : mine.valueText)
                        .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct GroupEmoji: View {
    var emoji: String
    var size: CGFloat = 44

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(Theme.elevated, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

enum CountdownText {
    static func ends(from now: Date, to end: Date) -> String {
        if let left = LeagueCountdown.remaining(from: now, to: end) {
            return String(localized: "Ends in \(left)")
        }
        return String(localized: "Finalizing results")
    }
}

private struct HowItWorksRow: View {
    var number: Int
    var title: LocalizedStringKey
    var text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Plain-language explanation of the Consistency formula (appendix A.10).
struct ScoringExplainerView: View {
    @Environment(\.dismiss) private var dismiss
    private let config = LeagueConfig.default

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GlassCard {
                        Text("Up to \(config.maxScore) points per week. How much you lift doesn't matter, so beginners can win too.")
                            .font(.subheadline)
                    }
                    GlassSection("Points") {
                        points("Each valid workout", "\(config.sessionPoints) pts",
                               detail: "At least 15 minutes and 6 working sets. One per day, up to \(config.maxSessionsPerWeek) per week.")
                        GlassDivider()
                        points("Each personal record", "\(config.prPoints) pts",
                               detail: "Heaviest weight or estimated 1RM (the most you could lift for one rep, estimated from your sets). Up to \(config.maxPRsPerSession) per workout and \(config.maxPRsPerWeek) per week. Your first log of an exercise is a baseline, not a record.")
                        GlassDivider()
                        points("Weekly target met", "\(config.targetBonus) pts")
                        GlassDivider()
                        points("Streak", "\(config.streakPointsPerWeek) pts / week",
                               detail: "For each previous week in a row you hit your target, up to \(config.maxStreakWeeks) weeks.")
                    }
                    GlassSection("Fair play") {
                        Text("Jumps of more than 25% over your previous best are saved to your log but don't earn league points.").font(.subheadline)
                        GlassDivider()
                        Text("Workouts backdated by more than 48 hours don't count.").font(.subheadline)
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("How scoring works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func points(_ title: LocalizedStringKey, _ value: String, detail: LocalizedStringKey? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary) }
        }
        .accessibilityElement(children: .combine)
    }
}
