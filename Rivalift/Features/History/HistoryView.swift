import SwiftUI

/// PROG-01 / appendix A.6. Layout follows Figma "History" (node 169:3641): this week's
/// progress, recent workouts, and a monthly calendar.
struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var mode: Mode = .list
    @State private var sessions: [WorkoutSession] = []
    @State private var progress: WeekProgress?

    enum Mode: String, CaseIterable, Identifiable {
        case list, calendar
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if mode == .calendar, !sessions.isEmpty {
                VStack(spacing: 0) {
                    header.padding([.horizontal, .top])
                    CalendarHistoryView(sessions: sessions)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        if sessions.isEmpty {
                            EmptyStateView(
                                systemImage: "calendar.badge.plus",
                                title: "No workouts yet",
                                message: "Your finished workouts show up here.",
                                actionTitle: "Start your first workout"
                            ) {
                                env.selectedTab = .home
                            }
                        } else {
                            if let progress {
                                HistoryWeekCard(progress: progress, sessions: thisWeek, unit: env.unit)
                            }
                            recentWorkouts
                        }
                    }
                    .padding()
                }
            }
        }
        .screenBackground()
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .onChange(of: env.dataVersion) { _, _ in reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            PillPicker(selection: $mode, options: [(.list, "List"), (.calendar, "Calendar")])
                .frame(maxWidth: .infinity)
            Text(weekRange).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
    }

    private var weekRange: String {
        let calendar = WeekCalendar()
        let start = calendar.weekStart(for: Date())
        let last = calendar.calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let format = Date.FormatStyle.dateTime.day().month(.wide)
        return "\(start.formatted(format)) - \(last.formatted(format))"
    }

    private var thisWeek: [WorkoutSession] {
        let calendar = WeekCalendar()
        let start = calendar.weekStart(for: Date())
        return sessions.filter { $0.startedAt >= start && $0.startedAt < calendar.weekEnd(for: start) }
    }

    private var recentWorkouts: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent workouts")
                Spacer()
                NavigationLink { AllWorkoutsView(sessions: sessions) } label: {
                    HStack(spacing: 0) {
                        Text("See all")
                        Image("Icon_seeall").accessibilityHidden(true)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: Theme.minTap)
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, -11)
            ForEach(Array(sessions.prefix(5).enumerated()), id: \.element.id) { index, session in
                if index > 0 {
                    Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
                }
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    RecentWorkoutRow(session: session, unit: env.unit)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func reload() {
        sessions = env.sessions.completedSessions()
        progress = env.weekProgress()
    }
}

/// "This week" in red: one dot per planned session, then the week's totals.
struct HistoryWeekCard: View {
    let progress: WeekProgress
    let sessions: [WorkoutSession]
    let unit: WeightUnit

    var body: some View {
        let prs = sessions.reduce(0) { $0 + ($1.personalRecords?.count ?? 0) }
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("This week")
                SessionTrack(done: progress.sessions, target: progress.target)
                    .padding(.horizontal, 14)
            }
            StatStrip(items: [
                ("\(sessions.count)", sessions.count == 1 ? "Workout" : "Workouts"),
                (WeightFormatter.volume(kg: sessions.reduce(0) { $0 + $1.totalVolumeKg }, unit: unit), "Total Volume"),
                (DurationFormatter.short(sessions.reduce(0) { $0 + $1.durationSec }), "Total Time"),
                ("\(prs)", "PR"),
            ])
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

/// Dots for the week's target on a thin track; finished sessions are green.
private struct SessionTrack: View {
    let done: Int
    let target: Int

    var body: some View {
        let count = max(target, 1)
        VStack(spacing: 12) {
            GeometryReader { geo in
                let span = geo.size.width - 18
                let step = count > 1 ? span / CGFloat(count - 1) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.24).shadow(.inner(color: .white.opacity(0.25), radius: 1)))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255))
                        .frame(width: max(0, geo.size.width * CGFloat(min(done, count)) / CGFloat(count) - 4), height: 3)
                        .padding(.leading, 2)
                    ForEach(0..<count, id: \.self) { index in
                        dot(complete: index < done)
                            .position(x: 9 + step * CGFloat(index), y: 9)
                    }
                }
                .frame(height: 18)
            }
            .frame(height: 18)
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { index in
                    if index > 0 { Spacer(minLength: 0) }
                    Text(count > 4 ? "\(index + 1)" : String(localized: "Sessions \(index + 1)"))
                        .font(.caption2.weight(.light))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize()
                }
            }
            .padding(.horizontal, -14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(target) sessions")
    }

    @ViewBuilder
    private func dot(complete: Bool) -> some View {
        if complete {
            Image("Icon_complete")
                .frame(width: 18, height: 18)
                .background(
                    Circle().fill(
                        Color(red: 21 / 255, green: 128 / 255, blue: 61 / 255).opacity(0.12)
                            .shadow(.inner(color: Color(red: 0x4A / 255, green: 0xDE / 255, blue: 0x80 / 255).opacity(0.46), radius: 2.5, y: 1))
                    )
                )
        } else {
            Circle()
                .fill(.white)
                .frame(width: 10, height: 10)
                .padding(4)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .shadow(color: .black.opacity(0.25), radius: 17, y: 16)
        }
    }
}

/// One finished workout: photo of its first exercise, name, date, and totals.
struct RecentWorkoutRow: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        let first = session.orderedExercises.first?.exercise
        HStack(spacing: 12) {
            ExercisePhoto(exercise: first)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .glassCard(cornerRadius: 24)
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name).font(.callout).lineLimit(1)
                    HStack(spacing: 6) {
                        Text(session.startedAt, format: .dateTime.weekday(.abbreviated).day().month().year())
                        if let first {
                            Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 12)
                            Text(first.name)
                        }
                    }
                    .font(.caption.weight(.light))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                HStack(alignment: .top) {
                    stat(String(max(0, session.durationSec) / 60), "min", "Training Time")
                    Spacer(minLength: 4)
                    stat(WeightFormatter.string(kg: session.totalVolumeKg.rounded(), unit: unit), unit.symbol, "Volume lifted")
                    Spacer(minLength: 4)
                    stat("\(session.orderedExercises.count)", "ex", "Movements")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ unit: String, _ label: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value).font(.callout.weight(.medium)).monospacedDigit()
                Text(unit).font(.caption.weight(.light))
            }
            Text(label).font(.caption2.weight(.light)).foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }
}

/// Every finished workout, grouped by week ("See all").
struct AllWorkoutsView: View {
    @Environment(AppEnvironment.self) private var env
    let sessions: [WorkoutSession]

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

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(weeks) { week in
                    HStack {
                        Text(week.start, format: .dateTime.day().month())
                        + Text(" – ")
                        + Text(WeekCalendar().calendar.date(byAdding: .day, value: 6, to: week.start) ?? week.start, format: .dateTime.day().month())
                        Spacer()
                        Text("\(week.sessions.count)/\(env.settings.effectiveWeeklyTarget(at: week.start)) sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    ForEach(Array(week.sessions.enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5) }
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            RecentWorkoutRow(session: session, unit: env.unit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("All workouts")
    }
}

/// Monthly calendar with dots on training days; tapping a day lists its sessions.
struct CalendarHistoryView: View {
    @Environment(AppEnvironment.self) private var env
    let sessions: [WorkoutSession]
    @State private var month = Date()
    @State private var selectedDay: String?

    private let calendar = WeekCalendar()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard {
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
                    .foregroundStyle(.white)
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
                                        .foregroundStyle(.white)
                                        .background(trained ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.06)), in: Circle())
                                        .overlay(Circle().strokeBorder(selectedDay == key ? Color.white : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(day, format: .dateTime.day().month()) + Text(trained ? ", trained" : ""))
                            } else {
                                Color.clear.frame(height: 36)
                            }
                        }
                    }
                }
                if let selectedDay {
                    let daySessions = sessions.filter { calendar.localDateString(for: $0.startedAt) == selectedDay }
                    Text(selectedDay).padding(.horizontal, 8)
                    if daySessions.isEmpty {
                        Text("Rest day").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 8)
                    }
                    ForEach(Array(daySessions.enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5) }
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            RecentWorkoutRow(session: session, unit: env.unit)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GlassCard {
                    Text(session.startedAt, format: .dateTime.weekday(.wide).day().month().year().hour().minute())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    StatStrip(items: [
                        (DurationFormatter.short(session.durationSec), "Duration"),
                        (WeightFormatter.volume(kg: session.totalVolumeKg, unit: env.unit), "Volume"),
                        ("\(session.completedWorkingSets.count)", "Sets"),
                    ])
                    if !session.notes.isEmpty {
                        GlassDivider()
                        Text(session.notes).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                ForEach(session.orderedExercises) { entry in
                    GlassCard {
                        if let exercise = entry.exercise {
                            NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                                HStack(spacing: 12) {
                                    ExercisePhoto(exercise: exercise, width: 52, height: 38)
                                    Text(exercise.name).font(.headline).multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Image("IconChevronCircle").accessibilityHidden(true)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            GlassDivider()
                        }
                        ForEach(Array(entry.orderedSets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text(set.setType.badge ?? "\(index + 1)")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                Text(setText(set, type: entry.exercise?.type ?? .weightReps))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                Spacer()
                                if set.isPR { PRBadge() }
                            }
                        }
                        if !entry.notes.isEmpty {
                            Text(entry.notes).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Save as routine") {
                    templateName = session.name
                    isSaveTemplatePresented = true
                }
                .buttonStyle(.secondary)
                Button("Delete workout", role: .destructive) { isDeleteConfirmPresented = true }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTap)
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save as routine", isPresented: $isSaveTemplatePresented) {
            TextField("Routine name", text: $templateName)
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
