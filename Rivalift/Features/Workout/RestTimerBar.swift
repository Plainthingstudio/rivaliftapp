import SwiftUI

/// Floating rest timer with −15 s, +15 s and skip (LOG-09).
struct RestTimerBar: View {
    let timer: RestTimerService

    var body: some View {
        if timer.endDate != nil {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let remaining = timer.remaining(at: context.date)
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Rest").font(.caption).foregroundStyle(.secondary)
                            Text(DurationFormatter.clock(Int(remaining.rounded(.up))))
                                .font(.largeTitle.monospacedDigit())
                                .contentTransition(.numericText(countsDown: true))
                            if let name = timer.exerciseName {
                                Text("Next: \(name)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 8)
                        HStack(spacing: 8) {
                            Button("-15s") { timer.adjust(by: -15) }
                                .buttonStyle(TimerPillStyle(prominent: false))
                                .accessibilityLabel("Subtract 15 seconds")
                            Button("+15s") { timer.adjust(by: 15) }
                                .buttonStyle(TimerPillStyle(prominent: false))
                                .accessibilityLabel("Add 15 seconds")
                            Button("Skip") { timer.skip() }
                                .buttonStyle(TimerPillStyle(prominent: true))
                        }
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(LinearGradient(stops: [.init(color: Color(white: 0.6), location: 0.333), .init(color: .white, location: 1)], startPoint: .leading, endPoint: .trailing))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.1)))
                            .frame(width: max(6, geo.size.width * (1 - timer.progress(at: context.date))))
                    }
                    .frame(height: 6)
                    .padding(5)
                    .background(
                        Color.white.opacity(0.04)
                            .shadow(.inner(color: .white.opacity(0.1), radius: 27.5, x: 2, y: 4))
                            .shadow(.inner(color: .white.opacity(0.25), radius: 1)),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .glassCard()
                .shadow(color: Color(red: 246 / 255, green: 79 / 255, blue: 89 / 255).opacity(0.2), radius: 15, y: -5)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Rest timer")
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Collapsed active workout shown above the tab bar.
struct MiniWorkoutBar: View {
    let session: WorkoutSession
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(session.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("\(DurationFormatter.clock(Int(context.date.timeIntervalSince(session.startedAt)))) · \(session.completedSetCount) sets")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(minHeight: Theme.minTap)
                .glassCard(cornerRadius: 22)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume workout \(session.name)")
        .accessibilityIdentifier("miniWorkoutBar")
    }
}

/// White pills for −15 s / +15 s and the blue gradient Skip (Figma rest timer).
private struct TimerPillStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(prominent ? .medium : .regular))
            .foregroundStyle(prominent ? Color.white : Color.black)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 14)
            .frame(minHeight: Theme.minTap)
            .background {
                if prominent {
                    Capsule().fill(Theme.primaryGradient)
                } else {
                    Capsule().fill(.white)
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
