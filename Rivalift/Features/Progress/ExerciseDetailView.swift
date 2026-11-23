import Charts
import SwiftUI

/// PROG-03 / PROG-04 / appendix A.7.
struct ExerciseDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let exercise: Exercise

    @State private var tab: DetailTab = .summary
    @State private var metric: Metric = .e1rm
    @State private var range: TimeRange = .threeMonths
    @State private var history: [SessionExercise] = []

    enum DetailTab: String, CaseIterable, Identifiable {
        case summary = "Summary", history = "History"
        var id: String { rawValue }
    }

    enum Metric: String, CaseIterable, Identifiable {
        case heaviest = "Heaviest weight", e1rm = "Est. 1RM", volume = "Best set volume"
        var id: String { rawValue }
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case month = "1M", threeMonths = "3M", year = "1Y", all = "All"
        var id: String { rawValue }

        var start: Date? {
            let cal = Calendar.current
            switch self {
            case .month: return cal.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
            case .year: return cal.date(byAdding: .year, value: -1, to: Date())
            case .all: return nil
            }
        }
    }

    struct Point: Identifiable {
        var id: Date { date }
        var date: Date
        var valueKg: Double
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(ownPhoto)
                    .resizable()
                    .aspectRatio(3 / 2, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .glassCard(cornerRadius: Theme.cornerRadius)
                    .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(.white.opacity(0.1)))
                    .accessibilityHidden(true)
                PillPicker(selection: $tab, options: DetailTab.allCases.map { ($0, LocalizedStringKey($0.rawValue)) })
                    .frame(maxWidth: .infinity)
                switch tab {
                case .summary: summary
                case .history: historyList
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { history = env.sessions.history(for: exercise) }
    }

    // MARK: Summary (Figma "Exercise Detail")

    @ViewBuilder
    private var summary: some View {
        if let guide = env.exercises.guide(for: exercise) {
            sectionTitle("How to do it")
            card {
                Text(guide.about).font(.subheadline).foregroundStyle(.secondary)
                divider
                ForEach(Array(guide.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .frame(width: 24, height: 24)
                            .background(Theme.accent.opacity(0.3), in: Circle())
                            .overlay(Circle().strokeBorder(Theme.accent))
                            .accessibilityHidden(true)
                        Text(step).font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(String(localized: "Step \(index + 1): \(step)"))
                }
            }
            sectionTitle("Tips")
            card {
                ForEach(guide.tips, id: \.self) { tip in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "lightbulb.fill").font(.caption).foregroundStyle(Theme.accent).accessibilityHidden(true)
                        Text(tip).font(.subheadline)
                    }
                }
            }
        }

        sectionTitle("Exercise info")
        VStack(spacing: 8) {
            infoCard(photo: primaryPhoto, title: "Primary", value: exercise.primaryMuscle.displayName)
            if !exercise.secondaryMuscles.isEmpty {
                infoCard(photo: secondaryPhoto, title: "Secondary", value: exercise.secondaryMuscles.map(\.displayName).joined(separator: ", "))
            }
            infoCard(photo: equipmentPhoto, title: "Equipment", value: exercise.equipment.displayName)
        }

        HStack {
            sectionTitle("Progress")
            Spacer()
            if metric == .e1rm { OneRepMaxInfoButton(unit: env.unit).padding(.vertical, -12) }
        }
        card {
            HStack(spacing: 10) {
                RingIcon(image: "Icon_metric_icon", strong: true)
                Text("Metric").font(.subheadline)
                Spacer()
                Menu {
                    Picker("Metric", selection: $metric) {
                        ForEach(Metric.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey(metric.rawValue)).font(.subheadline).foregroundStyle(.white).lineLimit(1)
                        Image("Icon_set_updown").accessibilityHidden(true)
                    }
                    .padding(.horizontal, 13)
                    .frame(minHeight: Theme.minTap)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white.opacity(0.1))
                            .strokeBorder(.white.opacity(0.2))
                    )
                }
            }
            divider
            if points.count < 2 {
                Text("Log this exercise in at least two workouts to see a chart.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value(metric.rawValue, UnitConverter.fromKg(point.valueKg, to: env.unit)))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(Theme.accent)
                    PointMark(x: .value("Date", point.date), y: .value(metric.rawValue, UnitConverter.fromKg(point.valueKg, to: env.unit)))
                        .foregroundStyle(.white)
                }
                .chartYAxisLabel(env.unit.symbol)
                .frame(height: 200)
            }
            divider
            rangePicker
        }

        sectionTitle("Personal records")
        card {
            let bests = ExerciseBests.from(sessions: history.reversed().map(\.samples))
            recordRow("Icon_rec_weight", "Heaviest weight", kg: bests.heaviestKg, type: .weight)
            divider
            recordRow("Icon_rec_1rm", "Est. 1RM", kg: bests.bestE1RMKg, type: .e1rm)
            divider
            recordRow("Icon_rec_volume", "Best session volume", kg: bests.bestSessionVolumeKg, type: .volume)
            divider
            let maxReps = history.flatMap(\.samples).filter(\.setType.isWorking).map(\.reps).max()
            HStack(spacing: 10) {
                RingIcon(image: "Icon_rec_reps", strong: true)
                Text("Most reps")
                Spacer()
                Text(maxReps.map { "\($0)" } ?? "—").font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// 1M / 3M / 1Y / All as glass pills; the selected one is blue (Figma "Weekly target" pill row).
    private var rangePicker: some View {
        HStack(spacing: 12) {
            ForEach(TimeRange.allCases) { option in
                let selected = option == range
                Button { range = option } label: {
                    Text(option.rawValue)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(selected ? 1 : 0.6))
                        .frame(maxWidth: .infinity, minHeight: 37)
                        .background {
                            if selected {
                                Capsule().fill(Theme.primaryGradient)
                            } else {
                                Capsule().fill(Color.black.opacity(0.24).shadow(.inner(color: .white.opacity(0.25), radius: 1)))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.shadow(.inner(color: .white.opacity(0.2), radius: 7, y: 2)), in: Capsule())
    }

    private func recordRow(_ icon: String, _ title: LocalizedStringKey, kg: Double?, type: PRType) -> some View {
        let date = (exercise.personalRecords ?? []).filter { $0.prType == type }.map(\.achievedAt).max()
        return HStack(spacing: 10) {
            RingIcon(image: icon, strong: true)
            Text(title)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(kg.map { WeightFormatter.string(kg: $0, unit: env.unit, includeUnit: true) } ?? "—")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let date { Text(date, format: .dateTime.day().month().year()).font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func infoCard(photo: String, title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 24) {
            Image(photo)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 71)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(value).font(.caption.weight(.light)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
    }

    // ponytail: the design's muscle/equipment photos only fit chest, shoulders and barbell;
    // other exercises show their own photo until per-muscle art exists.
    private var ownPhoto: String { ExerciseArt.imageName(key: exercise.key, muscle: exercise.primaryMuscle) }
    private var primaryPhoto: String { exercise.primaryMuscle == .chest ? "Photo_info_primary" : ownPhoto }
    private var secondaryPhoto: String { exercise.secondaryMuscles.contains(.shoulders) ? "Photo_info_secondary" : ownPhoto }
    private var equipmentPhoto: String { exercise.equipment == .barbell ? "Photo_info_equipment" : ownPhoto }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title).padding(.horizontal, 4)
    }

    private var divider: some View {
        Rectangle().fill(Theme.border).frame(height: 0.5)
    }

    private func card(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
    }

    // MARK: History

    @ViewBuilder
    private var historyList: some View {
        if history.isEmpty {
            Text("No history yet").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
        ForEach(history) { entry in
            card {
                if let date = entry.session?.startedAt {
                    Text(date, format: .dateTime.weekday(.abbreviated).day().month().year())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(entry.orderedSets) { set in
                    HStack {
                        Text(set.setType.badge ?? "•").frame(width: 24)
                        Text("\(WeightFormatter.string(kg: set.weightKg, unit: env.unit, includeUnit: true)) × \(set.reps)")
                            .monospacedDigit()
                        Spacer()
                        if set.isPR { PRBadge() }
                    }
                }
            }
        }
    }

    private var points: [Point] {
        let start = range.start
        return history.reversed().compactMap { entry -> Point? in
            guard let date = entry.session?.startedAt else { return nil }
            if let start, date < start { return nil }
            let working = entry.samples.filter { $0.setType.isWorking && $0.weightKg > 0 }
            let value: Double?
            switch metric {
            case .heaviest: value = working.map(\.weightKg).max()
            case .e1rm: value = working.compactMap { OneRepMax.estimate(for: $0) }.max()
            case .volume: value = working.map(\.volumeKg).max()
            }
            return value.map { Point(date: date, valueKg: $0) }
        }
    }
}
