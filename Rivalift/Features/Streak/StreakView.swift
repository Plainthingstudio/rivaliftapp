import SwiftUI

/// Weekly streak: this week, rest weeks and the last weeks. Opened from the 🔥 on Home.
struct StreakView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var overview: AppEnvironment.StreakOverview?

    var body: some View {
        ScrollView {
            if let overview {
                VStack(alignment: .leading, spacing: 14) {
                    hero(overview)
                    thisWeek(overview)
                    restWeeks(overview.streak)
                    recentWeeks(overview)
                    Text("Rest weeks only protect your own streak. League points don't change.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding()
            }
        }
        .screenBackground()
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { overview = env.streakOverview() }
        .onChange(of: env.dataVersion) { _, _ in overview = env.streakOverview() }
    }

    private func hero(_ overview: AppEnvironment.StreakOverview) -> some View {
        let streak = overview.streak
        return VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 56))
                .foregroundStyle(streak.current > 0 ? Theme.heat : .secondary)
                .accessibilityHidden(true)
            Text("^[\(streak.current) week](inflect: true)").font(.largeTitle.weight(.medium)).monospacedDigit()
            Text(streak.current > 0 ? "Your streak" : "Start your streak this week")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Best: ^[\(streak.best) week](inflect: true)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private func thisWeek(_ overview: AppEnvironment.StreakOverview) -> some View {
        let done = overview.sessionsThisWeek, target = overview.target
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").font(.headline.weight(.medium))
                Spacer()
                Text("\(min(done, target)) of \(target) workouts").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 6) {
                ForEach(0..<max(target, 1), id: \.self) { index in
                    Capsule()
                        .fill(index < done ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.1)))
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
            Group {
                if overview.streak.thisWeekMet {
                    Label("This week counts. Nice work!", systemImage: "checkmark.circle.fill")
                } else if overview.streak.current > 0 {
                    Label("^[\(target - done) more workout](inflect: true) by Sunday to keep your streak going.", systemImage: "calendar")
                } else {
                    Label("^[\(target - done) more workout](inflect: true) by Sunday to start your streak.", systemImage: "calendar")
                }
            }
            .font(.subheadline)
            .foregroundStyle(overview.streak.thisWeekMet ? Theme.success : .secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private func restWeeks(_ streak: PersonalStreak) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rest weeks").font(.headline.weight(.medium))
                    Text("A missed week uses one, and your streak carries on.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    ForEach(0..<PersonalStreak.maxRestWeeks, id: \.self) { index in
                        Image(systemName: index < streak.restWeeks ? "shield.fill" : "shield")
                            .font(.title2)
                            .foregroundStyle(index < streak.restWeeks ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.25)))
                    }
                }
                .accessibilityHidden(true)
            }
            Group {
                if let weeks = streak.weeksToNextRest {
                    Text("^[\(streak.restWeeks) rest week](inflect: true) saved. Hit your target ^[\(weeks) more week](inflect: true) to earn another.")
                } else {
                    Text("You have the most rest weeks you can save (\(PersonalStreak.maxRestWeeks)).")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    /// The last 12 weeks, this week last.
    private func recentWeeks(_ overview: AppEnvironment.StreakOverview) -> some View {
        let past = Array(zip(overview.weeks, overview.streak.history).suffix(11))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Last weeks").font(.headline.weight(.medium))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 12) {
                ForEach(past, id: \.0) { week, state in
                    weekCell(week, marker: marker(state), label: label(state))
                }
                weekCell(overview.thisWeek, marker: AnyView(
                    Circle()
                        .strokeBorder(Theme.accent, lineWidth: 2)
                        .background(Circle().fill(overview.streak.thisWeekMet ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Color.clear)))
                ), label: String(localized: "this week"))
            }
            if past.isEmpty {
                Text("Your weeks show up here as you train.").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                legend(AnyView(Circle().fill(Theme.primaryGradient)), "Target hit")
                legend(AnyView(Image(systemName: "shield.fill").font(.caption2).foregroundStyle(Theme.accent)), "Rest week")
                legend(AnyView(Circle().strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))), "Missed")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func weekCell(_ week: Date, marker: some View, label: String) -> some View {
        VStack(spacing: 4) {
            marker.frame(width: 30, height: 30)
            Text(week, format: .dateTime.day().month(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Week of \(week.formatted(.dateTime.day().month(.wide))): \(label)"))
    }

    private func marker(_ state: PersonalStreak.Week) -> AnyView {
        switch state {
        case .met:
            AnyView(Circle().fill(Theme.primaryGradient).overlay {
                Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white)
            })
        case .rest:
            AnyView(Circle().fill(Theme.accent.opacity(0.16)).overlay {
                Image(systemName: "shield.fill").font(.caption).foregroundStyle(Theme.accent)
            })
        case .missed:
            AnyView(Circle().strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
        }
    }

    private func label(_ state: PersonalStreak.Week) -> String {
        switch state {
        case .met: String(localized: "target hit")
        case .rest: String(localized: "rest week used")
        case .missed: String(localized: "missed")
        }
    }

    private func legend(_ marker: AnyView, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            marker.frame(width: 12, height: 12)
            Text(text)
        }
    }
}
