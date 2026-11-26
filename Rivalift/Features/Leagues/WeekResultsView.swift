import SwiftUI

/// Final standings of a closed week (appendix A.11, SOC-08): podium, the user's result,
/// the remaining ranks.
struct WeekResultsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let group: LeagueGroup
    let weekNumber: Int

    var body: some View {
        let ranked = LeagueBoards.consistency(group.lastWeek).rows
        let mine = ranked.first { $0.isMe }
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Week \(weekNumber) results").font(.largeTitle.bold())
                    Text("\(group.emoji) \(group.name)").font(.headline).foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                Podium(top: Array(ranked.prefix(3)), myName: env.settings.displayName)

                if let mine {
                    VStack(spacing: 6) {
                        if mine.rank == 1 {
                            Label("Champion", systemImage: "crown.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.gold)
                        }
                        Text("You finished #\(mine.rank ?? ranked.count) of \(ranked.count)")
                            .font(.title3.bold())
                        Text(mine.valueText).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .card()
                }

                if ranked.count > 3 {
                    VStack(spacing: 0) {
                        ForEach(ranked.dropFirst(3)) { entry in
                            StandingRow(row: entry, showsMovement: false)
                        }
                    }
                    .padding(.vertical, 6)
                    .glassCard(cornerRadius: Theme.cornerRadius)
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Start this week") {
                env.selectedTab = .home
                dismiss()
            }
            .buttonStyle(.primary)
            .padding()
            .background(Theme.bottomFade)
        }
    }
}

/// Second, first and third place side by side; first is larger (appendix A.11).
private struct Podium: View {
    let top: [BoardRow]
    let myName: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(order, id: \.id) { ranked in
                step(ranked)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var order: [BoardRow] {
        switch top.count {
        case 3: [top[1], top[0], top[2]]
        case 2: [top[1], top[0]]
        default: top
        }
    }

    private func step(_ ranked: BoardRow) -> some View {
        let isFirst = ranked.rank == 1
        let color: Color = switch ranked.rank {
        case 1: Theme.gold
        case 2: Theme.silver
        default: Theme.bronze
        }
        return VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: ranked.isMe && !myName.isEmpty ? myName : ranked.name, size: isFirst ? 76 : 58)
                    .overlay(Circle().stroke(color, lineWidth: 3))
                Image(systemName: "medal.fill")
                    .font(isFirst ? .title2 : .title3)
                    .foregroundStyle(color)
                    .background(Circle().fill(Theme.background).padding(-2))
            }
            Text(ranked.isMe ? String(localized: "You") : firstName(ranked.name))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(ranked.valueText).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.25))
                .frame(height: isFirst ? 96 : ranked.rank == 2 ? 70 : 52)
                .overlay(Text("\(ranked.rank ?? 0)").font(.title.bold()).foregroundStyle(color))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Place \(ranked.rank ?? 0), \(ranked.isMe ? String(localized: "you") : ranked.name), \(ranked.valueText)"))
    }

    private func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }
}
