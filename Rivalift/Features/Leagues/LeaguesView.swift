import SwiftUI

/// Leagues tab. Groups and leagues need an account and the Supabase backend (M4/M5,
/// AUTH-01…03, SOC-01…18). Until then the tab explains how leagues work (appendix A.9
/// empty state) so the solo log stays fully usable (AUTH-03).
struct LeaguesView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isScoringPresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.gold)
                        .accessibilityHidden(true)
                    Text("Weekly leagues with friends").font(.title2.bold())
                    Text("Create a private group, invite friends with a link or code, and compete every week from Monday to Sunday.")
                        .foregroundStyle(.secondary)
                }
                .card()

                VStack(alignment: .leading, spacing: 14) {
                    HowItWorksRow(number: 1, title: "Train as usual", text: "Every valid workout (15+ min, 6+ working sets) earns points.")
                    HowItWorksRow(number: 2, title: "Beat yourself", text: "Personal records and hitting your weekly target add bonus points.")
                    HowItWorksRow(number: 3, title: "Win the week", text: "Fair for every level: consistency counts, not how much you lift.")
                }
                .card()

                let progress = env.weekProgress()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your estimate this week").font(.headline)
                    Text("\(estimatedPoints(progress)) pts")
                        .font(.heroNumber)
                        .monospacedDigit()
                    Text("Based on \(progress.sessions) workouts and a \(progress.streakWeeks)-week streak.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .card()

                Button("How scoring works") { isScoringPresented = true }
                    .buttonStyle(.secondary)

                Button("Create group") {}
                    .buttonStyle(.primary)
                    .disabled(true)
                Button("Join with code") {}
                    .buttonStyle(.secondary)
                    .disabled(true)
                Text("Groups arrive with sign-in in an upcoming update. Your workouts logged now will count toward your streak.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Leagues")
        .sheet(isPresented: $isScoringPresented) { ScoringExplainerView() }
    }

    private func estimatedPoints(_ progress: WeekProgress) -> Int {
        let calendar = WeekCalendar()
        let now = Date()
        let sessions = env.sessions.completedSessions(from: calendar.weekStart(for: now), to: calendar.weekEnd(for: now))
        let inputs = sessions.map { session in
            LeagueScoreEstimator.SessionInput(
                id: session.id.uuidString,
                localDate: WeekCalendar(timeZone: session.timeZone).localDateString(for: session.startedAt),
                durationSec: session.durationSec,
                workingSets: session.completedWorkingSets.count,
                leaguePRs: (session.personalRecords ?? []).filter(\.countsForLeague).count,
                startedAt: session.startedAt,
                submittedAt: session.endedAt ?? now
            )
        }
        let metNow = progress.sessions >= progress.target
        let week = LeagueScoreEstimator.WeekInput(
            sessions: inputs,
            weeklyTarget: progress.target,
            streakWeeks: max(0, progress.streakWeeks - (metNow ? 1 : 0))
        )
        return LeagueScoreEstimator.score(week).total
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
            List {
                Section {
                    Text("Up to \(config.maxScore) points per week. How much you lift doesn't matter, so beginners can win too.")
                }
                Section("Points") {
                    LabeledContent("Each valid workout", value: "\(config.sessionPoints) pts")
                    Text("At least 15 minutes and 6 working sets. One per day, up to \(config.maxSessionsPerWeek) per week.")
                        .font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Each personal record", value: "\(config.prPoints) pts")
                    Text("Heaviest weight or estimated 1RM. Up to \(config.maxPRsPerSession) per workout and \(config.maxPRsPerWeek) per week. Your first log of an exercise is a baseline, not a record.")
                        .font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Weekly target met", value: "\(config.targetBonus) pts")
                    LabeledContent("Streak", value: "\(config.streakPointsPerWeek) pts / week")
                    Text("For each previous week in a row you hit your target, up to \(config.maxStreakWeeks) weeks.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Fair play") {
                    Text("Jumps of more than 25% over your previous best are saved to your log but don't earn league points.")
                    Text("Workouts backdated by more than 48 hours don't count.")
                }
            }
            .navigationTitle("How scoring works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
