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
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 6) {
                        Text(summary.records.isEmpty ? "Nice work!" : "New records!")
                            .font(.largeTitle.bold())
                            .scaleEffect(celebrate ? 1 : 0.8)
                            .opacity(celebrate ? 1 : 0)
                        Text("Workout #\(summary.sessionNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .overlay { ConfettiView(isActive: celebrate) }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Workout name", text: $name)
                            .font(.title3.weight(.semibold))
                        Text(session.startedAt, format: .dateTime.weekday(.wide).day().month().hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .card()

                    Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                        GridRow {
                            StatTile(value: DurationFormatter.short(session.durationSec), label: "Duration")
                            StatTile(value: WeightFormatter.volume(kg: session.totalVolumeKg, unit: env.unit), label: "Volume")
                        }
                        GridRow {
                            StatTile(value: "\(session.completedWorkingSets.count)", label: "Sets")
                            StatTile(value: "\(session.totalReps)", label: "Reps")
                        }
                    }
                    .card()

                    if !summary.records.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Personal records", systemImage: "trophy.fill")
                                .font(.headline)
                                .foregroundStyle(Theme.pr)
                            ForEach(summary.records) { record in
                                RecordRow(record: record, unit: env.unit)
                            }
                        }
                        .card()
                    }

                    leagueCard

                    if summary.templateChanged, let template = summary.template {
                        Button(templateUpdated ? String(localized: "Template updated") : String(localized: "Update “\(template.name)”")) {
                            env.templates.update(template, from: session)
                            templateUpdated = true
                        }
                        .buttonStyle(.secondary)
                        .disabled(templateUpdated)
                    }

                    VStack(alignment: .leading) {
                        Text("Notes").font(.headline)
                        TextField("How did it feel?", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    .card()
                }
                .padding()
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                Button("Done") { save() }
                    .buttonStyle(.primary)
                    .padding()
                    .background(.bar)
                    .accessibilityIdentifier("summaryDoneButton")
            }
        }
        .onAppear {
            name = session.name
            notes = session.notes
            withAnimation(.spring(duration: 0.6).delay(0.1)) { celebrate = true }
        }
    }

    private var leagueCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("League", systemImage: "person.3.fill").font(.headline)
            if summary.isValidForLeague {
                Text("This workout would earn about +\(summary.estimatedLeaguePoints) pts in a Consistency league this week.")
                    .font(.subheadline)
            } else {
                Text("Workouts count for leagues when they last at least 15 minutes with 6 working sets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button("Invite friends to a league") {
                save()
                env.selectedTab = .leagues
            }
            .font(.subheadline.weight(.semibold))
        }
        .card()
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

struct RecordRow: View {
    let record: RecordLine
    let unit: WeightUnit

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName).font(.subheadline.weight(.semibold))
                Text(record.type.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(valueText)
                .font(.subheadline.monospacedDigit())
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var valueText: String {
        switch record.type {
        case .repsAtWeight:
            let old = record.previousValue.map { "\(Int($0))" } ?? "—"
            return "\(old) → \(record.reps) reps @ \(WeightFormatter.string(kg: record.value, unit: unit, includeUnit: true))"
        case .weight, .e1rm, .volume:
            let old = record.previousValue.map { WeightFormatter.string(kg: $0, unit: unit) } ?? "—"
            return "\(old) → \(WeightFormatter.string(kg: record.value, unit: unit, includeUnit: true))"
        }
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
