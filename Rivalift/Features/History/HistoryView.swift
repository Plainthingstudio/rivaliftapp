import SwiftUI

/// PROG-01 / appendix A.6: list grouped by week, and a monthly calendar.
struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var mode: Mode = .list
    @State private var sessions: [WorkoutSession] = []

    enum Mode: String, CaseIterable, Identifiable {
        case list, calendar
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                EmptyStateView(
                    systemImage: "calendar.badge.plus",
                    title: "No workouts yet",
                    message: "Your finished workouts show up here.",
                    actionTitle: "Start your first workout"
                ) {
                    env.workout.isStartSheetPresented = true
                }
            } else {
                switch mode {
                case .list: listView
                case .calendar: CalendarHistoryView(sessions: sessions)
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $mode) {
                    Text("List").tag(Mode.list)
                    Text("Calendar").tag(Mode.calendar)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .onAppear(perform: reload)
        .onChange(of: env.dataVersion) { _, _ in reload() }
    }

    struct WeekGroup: Identifiable {
        var start: Date
        var sessions: [WorkoutSession]
        var id: Date { start }
    }

    private var weeks: [WeekGroup] {
        let calendar = WeekCalendar()
        let grouped = Dictionary(grouping: sessions) { calendar.weekStart(for: $0.startedAt) }
        return grouped.keys.sorted(by: >).map { WeekGroup(start: $0, sessions: grouped[$0] ?? []) }
    }

    private var listView: some View {
        List {
            ForEach(weeks) { week in
                Section {
                    ForEach(week.sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionCard(session: session, unit: env.unit)
                        }
                    }
                } header: {
                    HStack {
                        Text(week.start, format: .dateTime.day().month())
                        + Text(" – ")
                        + Text(WeekCalendar().calendar.date(byAdding: .day, value: 6, to: week.start) ?? week.start, format: .dateTime.day().month())
                        Spacer()
                        Text("\(week.sessions.count)/\(env.settings.effectiveWeeklyTarget(at: week.start)) sessions")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func reload() {
        sessions = env.sessions.completedSessions()
    }
}

struct SessionCard: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.name).font(.headline)
                Spacer()
                let prs = session.personalRecords?.count ?? 0
                if prs > 0 {
                    Label("\(prs)", systemImage: "trophy.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.pr)
                        .accessibilityLabel("\(prs) records")
                }
            }
            Text(session.startedAt, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label(DurationFormatter.short(session.durationSec), systemImage: "clock")
                Label(WeightFormatter.volume(kg: session.totalVolumeKg, unit: unit), systemImage: "scalemass")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(session.orderedExercises.prefix(3).compactMap(\.exercise?.name).joined(separator: " · "))
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

/// Monthly calendar with dots on training days; tapping a day lists its sessions.
struct CalendarHistoryView: View {
    let sessions: [WorkoutSession]
    @State private var month = Date()
    @State private var selectedDay: String?

    private let calendar = WeekCalendar()

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: Theme.minTap, height: Theme.minTap) }
                            .accessibilityLabel("Previous month")
                        Spacer()
                        Text(month, format: .dateTime.month(.wide).year()).font(.headline)
                        Spacer()
                        Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: Theme.minTap, height: Theme.minTap) }
                            .accessibilityLabel("Next month")
                    }
                    .buttonStyle(.plain)
                    let columns = Array(repeating: GridItem(.flexible()), count: 7)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(calendar.days(ofWeekContaining: Date()), id: \.self) { day in
                            Text(day, format: .dateTime.weekday(.narrow)).font(.caption).foregroundStyle(.secondary)
                        }
                        ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                            if let day {
                                let key = calendar.localDateString(for: day)
                                let trained = trainedDays.contains(key)
                                Button {
                                    selectedDay = key
                                } label: {
                                    Text(day, format: .dateTime.day())
                                        .font(.subheadline.weight(trained ? .bold : .regular))
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(trained ? Color.white : Color.primary)
                                        .background(trained ? Theme.accent : .clear, in: Circle())
                                        .overlay(Circle().stroke(selectedDay == key ? Theme.accent : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(day, format: .dateTime.day().month()) + Text(trained ? ", trained" : ""))
                            } else {
                                Color.clear.frame(height: 36)
                            }
                        }
                    }
                }
            }
            if let selectedDay {
                Section(selectedDay) {
                    let daySessions = sessions.filter { calendar.localDateString(for: $0.startedAt) == selectedDay }
                    if daySessions.isEmpty {
                        Text("Rest day").foregroundStyle(.secondary)
                    }
                    ForEach(daySessions) { session in
                        NavigationLink(session.name) { SessionDetailView(session: session) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var trainedDays: Set<String> {
        Set(sessions.map { calendar.localDateString(for: $0.startedAt) })
    }

    /// Leading nils pad the first week so days line up under Monday-first headers.
    private var monthCells: [Date?] {
        let cal = calendar.calendar
        guard let interval = cal.dateInterval(of: .month, for: month),
              let count = cal.range(of: .day, in: .month, for: month)?.count else { return [] }
        let weekday = cal.component(.weekday, from: interval.start)
        let leading = (weekday + 5) % 7
        let days = (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leading) + days.map(Optional.some)
    }

    private func shiftMonth(_ delta: Int) {
        month = calendar.calendar.date(byAdding: .month, value: delta, to: month) ?? month
    }
}

/// PROG-02 / LIB-05.
struct SessionDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let session: WorkoutSession

    @State private var isSaveTemplatePresented = false
    @State private var templateName = ""
    @State private var isDeleteConfirmPresented = false

    var body: some View {
        List {
            Section {
                LabeledContent("Date") { Text(session.startedAt, format: .dateTime.day().month().year().hour().minute()) }
                LabeledContent("Duration", value: DurationFormatter.short(session.durationSec))
                LabeledContent("Volume", value: WeightFormatter.volume(kg: session.totalVolumeKg, unit: env.unit))
                LabeledContent("Sets", value: "\(session.completedWorkingSets.count)")
                if !session.notes.isEmpty { Text(session.notes).foregroundStyle(.secondary) }
            }
            ForEach(session.orderedExercises) { entry in
                Section {
                    ForEach(Array(entry.orderedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text(set.setType.badge ?? "\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .frame(width: 28)
                            Text(setText(set, type: entry.exercise?.type ?? .weightReps))
                                .monospacedDigit()
                            Spacer()
                            if set.isPR { PRBadge() }
                        }
                    }
                    if !entry.notes.isEmpty {
                        Text(entry.notes).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    if let exercise = entry.exercise {
                        NavigationLink(exercise.name) { ExerciseDetailView(exercise: exercise) }
                            .font(.headline)
                            .textCase(nil)
                    }
                }
            }
            Section {
                Button("Save as template") {
                    templateName = session.name
                    isSaveTemplatePresented = true
                }
                Button("Delete workout", role: .destructive) { isDeleteConfirmPresented = true }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save as template", isPresented: $isSaveTemplatePresented) {
            TextField("Template name", text: $templateName)
            Button("Save") {
                env.templates.createFromSession(session, name: templateName.isEmpty ? session.name : templateName)
                env.dataDidChange()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this workout?", isPresented: $isDeleteConfirmPresented, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                env.sessions.delete(session)
                env.dataDidChange()
                dismiss()
            }
        } message: {
            Text("Personal records will be recalculated.")
        }
    }

    private func setText(_ set: SetEntry, type: ExerciseType) -> String {
        switch type {
        case .weightReps:
            return "\(WeightFormatter.string(kg: set.weightKg, unit: env.unit, includeUnit: true)) × \(set.reps)"
        case .bodyweightReps:
            return set.weightKg > 0 ? "+\(WeightFormatter.string(kg: set.weightKg, unit: env.unit, includeUnit: true)) × \(set.reps)" : "\(set.reps) reps"
        case .duration:
            return DurationFormatter.clock(set.durationSec)
        }
    }
}
