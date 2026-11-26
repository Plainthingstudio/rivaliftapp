import SwiftUI

/// LOG-12 / PROG-05 / appendix A.5.
struct WorkoutSummaryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let summary: WorkoutSummary

    @State private var name = ""
    @State private var notes = ""
    @State private var celebrate = false
    @State private var templateUpdated = false

    private var session: WorkoutSession { summary.session }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    celebration
                    titleCard
                    summaryCard
                    if !summary.records.isEmpty { recordsCard }
                    leagueCard
                    if session.templateID == nil { SaveRoutineCard(session: session) }
                    if summary.templateChanged, let template = summary.template {
                        Button(templateUpdated ? String(localized: "Routine updated") : String(localized: "Update “\(template.name)”")) {
                            env.templates.update(template, from: session)
                            templateUpdated = true
                        }
                        .buttonStyle(.secondary)
                        .disabled(templateUpdated)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                        TextField("How did it feel?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                }
                .padding()
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                Button("Done") { save() }
                    .buttonStyle(.primary)
                    .padding()
                    .background(Theme.bottomFade)
                    .accessibilityIdentifier("summaryDoneButton")
            }
        }
        .onAppear {
            name = session.name
            notes = session.notes
            withAnimation(.spring(duration: 0.6).delay(0.1)) { celebrate = true }
        }
    }

    /// Figma "Celebration": trophy ring, title, workout number.
    private var celebration: some View {
        VStack(spacing: 12) {
            RingIcon(image: "Icon_trophy", iconSize: 20, strong: true)
            VStack(spacing: 4) {
                Text(summary.records.isEmpty ? "Nice work!" : "New Records!")
                    .font(.title)
                    .scaleEffect(celebrate ? 1 : 0.8)
                    .opacity(celebrate ? 1 : 0)
                Text("Workout #\(summary.sessionNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay { ConfettiView(isActive: celebrate) }
    }

    /// Name (editable) and start time on a blue-lit card.
    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Workout name", text: $name)
                .font(.body.weight(.medium))
            Text(session.startedAt, format: .dateTime.weekday(.wide).day().month().hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Summary").font(.callout)
            StatStrip(items: [
                (DurationFormatter.short(session.durationSec), "Duration"),
                (WeightFormatter.volume(kg: session.totalVolumeKg, unit: env.unit), "Volume"),
                ("\(session.completedWorkingSets.count)", "Sets"),
                ("\(session.totalReps)", "Reps"),
            ])
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RingIcon(image: "Icon_trophy", iconSize: 20, strong: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Personal Records").font(.callout)
                    Text("^[\(summary.records.count) new record](inflect: true) this workout.")
                        .font(.caption.weight(.light))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if summary.records.contains(where: { $0.type == .e1rm }) {
                    OneRepMaxInfoButton(unit: env.unit).padding(.vertical, -12)
                }
            }
            ForEach(Array(summary.records.enumerated()), id: \.element.id) { index, record in
                if index > 0 { Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5) }
                RecordRow(record: record, unit: env.unit, exercise: exercise(named: record.exerciseName))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func exercise(named name: String) -> Exercise? {
        session.orderedExercises.compactMap(\.exercise).first { $0.name == name }
    }

    private var leagueCard: some View {
        let changes = env.leagueRankChanges(for: session.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image("Icon_league_icon").accessibilityHidden(true)
                Text("League").font(.callout)
            }
            ForEach(changes) { change in
                HStack(spacing: 8) {
                    Text(change.groupEmoji)
                    Text(change.title).font(.subheadline).lineLimit(1)
                    Spacer()
                    RankChangeText(before: change.before, after: change.after)
                }
                .accessibilityElement(children: .combine)
            }
            if summary.isValidForLeague {
                Text("This workout would earn about +\(summary.estimatedLeaguePoints) pts in a Consistency league this week.")
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("Workouts count for leagues when they last at least 15 minutes with 6 working sets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                save()
                env.selectedTab = .leagues
            } label: {
                HStack(spacing: 0) {
                    Text("Invite friends to a league")
                    Image("Icon_details_chev").accessibilityHidden(true)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: Theme.minTap)
                .background(Color.black.shadow(.inner(color: .white.opacity(0.2), radius: 7, y: 2)), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private struct RankChangeText: View {
        let before: Int?
        let after: Int?

        var body: some View {
            let text = "\(before.map { "#\($0)" } ?? "—") → \(after.map { "#\($0)" } ?? "—")"
            let improved = (after ?? .max) < (before ?? .max)
            Label(text, systemImage: improved ? "arrow.up" : "equal")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(improved ? Color.green : Color.secondary)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { session.name = trimmed }
        session.notes = notes
        env.sessions.save()
        env.dataDidChange()
        env.workout.summary = nil
        dismiss()
    }
}

/// One new record: exercise photo, then the value with the gain over the old best.
struct RecordRow: View {
    let record: RecordLine
    let unit: WeightUnit
    var exercise: Exercise?

    var body: some View {
        HStack(spacing: 12) {
            ExercisePhoto(exercise: exercise)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .glassCard(cornerRadius: 24)
            VStack(alignment: .leading, spacing: 12) {
                Text(record.exerciseName).font(.subheadline).lineLimit(2)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(value).font(.title3.weight(.medium)).monospacedDigit()
                            Text(valueUnit).font(.caption.weight(.medium))
                        }
                        Text(record.type.displayName).font(.caption.weight(.light)).foregroundStyle(.white.opacity(0.8))
                    }
                    Spacer(minLength: 4)
                    if let gain {
                        VStack(spacing: 4) {
                            Image("Icon_pr_up").accessibilityHidden(true)
                            Text(gain).font(.caption2).foregroundStyle(Color(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.1))
                        .strokeBorder(.white.opacity(0.2))
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var value: String {
        record.type == .repsAtWeight ? "\(record.reps)" : WeightFormatter.string(kg: record.value, unit: unit)
    }

    private var valueUnit: String {
        record.type == .repsAtWeight ? String(localized: "reps") : unit.symbol
    }

    /// "+2 kg" or "+2 reps" over the previous best; nil for a first record.
    private var gain: String? {
        guard let previous = record.previousValue else { return nil }
        if record.type == .repsAtWeight {
            let delta = record.reps - Int(previous)
            return delta > 0 ? "+\(delta) reps" : nil
        }
        let delta = UnitConverter.fromKg(record.value, to: unit) - UnitConverter.fromKg(previous, to: unit)
        guard delta > 0 else { return nil }
        return "+\(delta.formatted(.number.precision(.fractionLength(0...1)))) \(unit.symbol)"
    }
}

/// Light confetti burst (appendix A.5). Hidden for Reduce Motion.
struct ConfettiView: View {
    var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pieces: [(x: CGFloat, delay: Double, color: Color, rotation: Double)] = (0..<24).map { index in
        let colors: [Color] = [.orange, .pink, .yellow, .green, .blue, .purple]
        return (
            x: CGFloat((index * 37) % 100) / 100,
            delay: Double(index % 6) * 0.05,
            color: colors[index % colors.count],
            rotation: Double(index * 29 % 360)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            if !reduceMotion {
                ForEach(pieces.indices, id: \.self) { index in
                    let piece = pieces[index]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: 6, height: 10)
                        .rotationEffect(.degrees(isActive ? piece.rotation + 360 : piece.rotation))
                        .position(x: proxy.size.width * piece.x, y: isActive ? proxy.size.height + 40 : -20)
                        .opacity(isActive ? 0 : 1)
                        .animation(.easeIn(duration: 1.4).delay(piece.delay), value: isActive)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A workout not started from a routine (picked exercises, a suggestion): offer to keep it as one.
private struct SaveRoutineCard: View {
    @Environment(AppEnvironment.self) private var env
    let session: WorkoutSession
    @State private var name = ""
    @State private var isSaved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isSaved ? "Saved to your routines" : "Save as a routine?").font(.headline.weight(.medium))
                Text(isSaved ? "Start it from Home in one tap." : "Do this workout again in one tap from Home.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !isSaved {
                TextField("Routine name", text: $name).glassField()
                Button("Save routine") {
                    let fallback = RoutineNaming.name(primaryMuscles: session.orderedExercises.compactMap(\.exercise?.primaryMuscle))
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    env.templates.createFromSession(session, name: trimmed.isEmpty ? fallback : trimmed)
                    env.dataDidChange()
                    withAnimation { isSaved = true }
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("saveRoutineButton")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Theme.accent.opacity(0.5)))
        .onAppear {
            if name.isEmpty {
                name = RoutineNaming.name(primaryMuscles: session.orderedExercises.compactMap(\.exercise?.primaryMuscle))
            }
        }
    }
}
