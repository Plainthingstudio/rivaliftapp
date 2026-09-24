import SwiftUI

/// Floating rest timer with −15 s, +15 s and skip (LOG-09).
struct RestTimerBar: View {
    let timer: RestTimerService

    var body: some View {
        if timer.endDate != nil {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let remaining = timer.remaining(at: context.date)
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Rest")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            if let name = timer.exerciseName {
                                Text("Next: \(name)")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text(DurationFormatter.clock(Int(remaining.rounded(.up))))
                            .font(.title2.monospacedDigit().weight(.bold))
                            .contentTransition(.numericText(countsDown: true))
                    }
                    ProgressView(value: timer.progress(at: context.date))
                        .tint(Theme.accent)
                    HStack(spacing: 8) {
                        Button("−15s") { timer.adjust(by: -15) }
                            .accessibilityLabel("Subtract 15 seconds")
                        Button("+15s") { timer.adjust(by: 15) }
                            .accessibilityLabel("Add 15 seconds")
                        Button("Skip") { timer.skip() }
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume workout \(session.name)")
        .accessibilityIdentifier("miniWorkoutBar")
    }
}
