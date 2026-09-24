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
        List {
            Picker("View", selection: $tab) {
                ForEach(DetailTab.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            switch tab {
            case .summary: summary
            case .history: historyList
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { history = env.sessions.history(for: exercise) }
    }

    @ViewBuilder
    private var summary: some View {
        Section {
            LabeledContent("Primary", value: exercise.primaryMuscle.displayName)
            if !exercise.secondaryMuscles.isEmpty {
                LabeledContent("Secondary", value: exercise.secondaryMuscles.map(\.displayName).joined(separator: ", "))
            }
            LabeledContent("Equipment", value: exercise.equipment.displayName)
        }
        Section("Progress") {
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
            }
            if points.count < 2 {
                Text("Log this exercise in at least two workouts to see a chart.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value(metric.rawValue, UnitConverter.fromKg(point.valueKg, to: env.unit)))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Date", point.date), y: .value(metric.rawValue, UnitConverter.fromKg(point.valueKg, to: env.unit)))
                }
                .chartYAxisLabel(env.unit.symbol)
                .frame(height: 200)
                .foregroundStyle(Theme.accent)
            }
            Picker("Range", selection: $range) {
                ForEach(TimeRange.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        Section("Personal records") {
            let bests = ExerciseBests.from(sessions: history.reversed().map(\.samples))
            recordRow("Heaviest weight", kg: bests.heaviestKg, type: .weight)
            recordRow("Est. 1RM", kg: bests.bestE1RMKg, type: .e1rm)
            recordRow("Best session volume", kg: bests.bestSessionVolumeKg, type: .volume)
            LabeledContent("Most reps") {
                let maxReps = history.flatMap(\.samples).filter(\.setType.isWorking).map(\.reps).max()
                Text(maxReps.map { "\($0)" } ?? "—")
            }
        }
    }

    private func recordRow(_ title: LocalizedStringKey, kg: Double?, type: PRType) -> some View {
        let date = (exercise.personalRecords ?? []).filter { $0.prType == type }.map(\.achievedAt).max()
        return LabeledContent {
            VStack(alignment: .trailing) {
                Text(kg.map { WeightFormatter.string(kg: $0, unit: env.unit, includeUnit: true) } ?? "—")
                if let date { Text(date, format: .dateTime.day().month().year()).font(.caption).foregroundStyle(.secondary) }
            }
        } label: {
            Text(title)
        }
    }

    @ViewBuilder
    private var historyList: some View {
        if history.isEmpty {
            Text("No history yet").foregroundStyle(.secondary)
        }
        ForEach(history) { entry in
            Section {
                ForEach(entry.orderedSets) { set in
                    HStack {
                        Text(set.setType.badge ?? "•").frame(width: 24)
                        Text("\(WeightFormatter.string(kg: set.weightKg, unit: env.unit, includeUnit: true)) × \(set.reps)")
                            .monospacedDigit()
                        Spacer()
                        if set.isPR { PRBadge() }
                    }
                }
            } header: {
                if let date = entry.session?.startedAt {
                    Text(date, format: .dateTime.weekday(.abbreviated).day().month().year())
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
