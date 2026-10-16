import SwiftUI

/// PROG-06 / LOG-01 / appendix A.2. Layout follows Figma "Home" (node 163:32961).
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var progress: WeekProgress?
    @State private var quickTemplates: [WorkoutTemplate] = []
    @State private var recentRecords: [PersonalRecord] = []
    @State private var overview: AppEnvironment.TrainingOverview?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                greeting
                if let progress { WeekCard(progress: progress) }
                startButton
                if let overview, overview.totalWorkouts > 0 { MetricsCard(overview: overview, unit: env.unit) }
                LeagueTeaserCard()
                if !quickTemplates.isEmpty { quickStart }
                if !recentRecords.isEmpty { records }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: Bindable(env.workout).isStartScreenPresented) {
            StartWorkoutView()
        }
        .onAppear(perform: reload)
        .onChange(of: env.dataVersion) { _, _ in reload() }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date(), format: .dateTime.weekday(.wide).day().month())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(env.settings.displayName.isEmpty ? String(localized: "Let's lift") : String(localized: "Hi, \(env.settings.displayName)"))
                .font(.largeTitle)
            Text("Keep going. Consistency builds real progress")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var startButton: some View {
        if env.workout.session != nil {
            Button("Resume workout") { env.workout.isPresented = true }
                .buttonStyle(.primary)
        } else {
            Button {
                env.workout.isStartScreenPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image("IconPlay").accessibilityHidden(true)
                    Text("Start Workout")
                }
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("startWorkoutButton")
        }
    }

    private var quickStart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick start").font(.callout)
                Spacer()
                NavigationLink { TemplatesView() } label: {
                    HStack(spacing: 0) {
                        Text("All templates")
                        Image("IconChevronRight").accessibilityHidden(true)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: Theme.minTap)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, -12)
            HStack(spacing: 4) {
                ForEach(quickTemplates.prefix(2)) { template in
                    NavigationLink {
                        TemplateDetailView(template: template)
                    } label: {
                        QuickStartCard(template: template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var records: some View {
        let best = recentRecords.map(\.valueKg).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image("Icon_records_trophy").accessibilityHidden(true)
                Text("Records this week")
                Spacer()
                if recentRecords.contains(where: { $0.prType == .e1rm }) {
                    OneRepMaxInfoButton(unit: env.unit).padding(.vertical, -12)
                }
            }
            ForEach(recentRecords) { record in
                if let exercise = record.exercise {
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        recordRow(record, name: exercise.name, fraction: best > 0 ? record.valueKg / best : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dotTexture(opacity: 0.2 / 0.7, x: 14.5, y: -69.6)
        .glassCard()
    }

    private func recordRow(_ record: PersonalRecord, name: String, fraction: Double) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(.subheadline)
                RecordBar(fraction: fraction)
            }
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(record.prType.displayName)
                        .font(.caption.weight(.light))
                        .foregroundStyle(.secondary)
                    Text(WeightFormatter.string(kg: record.valueKg, unit: env.unit, includeUnit: true))
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                }
                Image("IconChevronCircle").accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        progress = env.weekProgress()
        quickTemplates = env.templates.recentlyUsed()
        if quickTemplates.isEmpty {
            let plan = env.templates.programs().first { $0.name == env.settings.planProgram }?.templates
            quickTemplates = Array((plan ?? env.templates.builtInTemplates()).prefix(3))
        }
        let calendar = WeekCalendar()
        let weekSessions = env.sessions.completedSessions(from: calendar.weekStart(for: Date()), to: calendar.weekEnd(for: Date()))
        recentRecords = Array(
            weekSessions.flatMap { $0.personalRecords ?? [] }
                .filter { $0.prType == .weight || $0.prType == .e1rm }
                .sorted { $0.achievedAt > $1.achievedAt }
                .prefix(3)
        )
        overview = env.trainingOverview()
    }
}

/// "This week": Monday–Sunday dots, sessions vs target, weekly streak.
struct WeekCard: View {
    let progress: WeekProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("This week")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.heat)
                    Text("\(progress.streakWeeks)").font(.callout.weight(.medium))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(progress.streakWeeks) week streak")
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 0) {
                    ForEach(Array(progress.days.enumerated()), id: \.element) { index, day in
                        if index > 0 { Spacer(minLength: 0) }
                        dayColumn(day)
                    }
                }
                Text("\(progress.sessions) of \(progress.target) sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dotTexture("DotGridWeek", y: -48.6)
        .glassCard()
    }

    private func dayColumn(_ day: Date) -> some View {
        let trained = progress.trainedDays.contains(WeekCalendar().localDateString(for: day))
        let isToday = Calendar.current.isDateInToday(day)
        return VStack(spacing: 6) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption.weight(isToday ? .medium : .regular))
                .foregroundStyle(isToday ? .primary : .secondary)
            if trained {
                Circle()
                    .fill(Theme.primaryGradient)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
            } else {
                Circle()
                    .fill(.white.opacity(0.1).shadow(.inner(color: .white.opacity(0.25), radius: 1)))
                    .frame(width: 30, height: 30)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide)) + Text(trained ? ", trained" : ""))
    }
}

/// Training summary on Home: this week vs last week and weekly volume.
struct MetricsCard: View {
    let overview: AppEnvironment.TrainingOverview
    let unit: WeightUnit

    var body: some View {
        let now = overview.thisWeek, last = overview.lastWeek
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your training")
                Spacer()
                Text("^[\(overview.totalWorkouts) workout](inflect: true) all time")
                    .font(.caption)
            }
            HStack(alignment: .top, spacing: 0) {
                metric(WeightFormatter.string(kg: now.volumeKg, unit: unit, includeUnit: true), "Total Volume", now.volumeKg, last.volumeKg, large: true)
                Spacer(minLength: 8)
                divided(metric("\(now.sets)", "Sets", Double(now.sets), Double(last.sets)))
                Spacer(minLength: 8)
                divided(metric(DurationFormatter.short(now.durationSec), "Time", Double(now.durationSec), Double(last.durationSec)))
                Spacer(minLength: 8)
                divided(metric("\(now.sessions)", "Workouts", Double(now.sessions), Double(last.sessions)))
            }
            VolumeBars(weeks: overview.weeklyVolume)
            HStack(spacing: 0) {
                let labelled = overview.weeklyVolume.enumerated().filter { $0.offset.isMultiple(of: 2) }
                ForEach(labelled, id: \.offset) { item in
                    if item.offset > 0 { Spacer(minLength: 0) }
                    Text(item.element.weekStart, format: .dateTime.day().month(.abbreviated))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            Text("This week vs last week · volume over the last 8 weeks")
                .font(.caption.weight(.light))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dotTexture(alignment: .center, x: -0.57, y: 0)
        .redCard(cornerRadius: 50)
    }

    private func divided(_ content: some View) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.2)).frame(width: 0.5, height: 40)
            content
        }
    }

    private func metric(_ value: String, _ label: LocalizedStringKey, _ current: Double, _ previous: Double, large: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(large ? .title2 : .body)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let change = TrainingStats.percentChange(current: current, previous: previous), change != 0 {
                Label("\(abs(change))%", systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(change > 0 ? Color.green : Color.secondary)
                    .accessibilityLabel(change > 0 ? "Up \(change) percent from last week" : "Down \(-change) percent from last week")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Weekly volume: weeks with volume as red bars, empty weeks as a thin light line.
private struct VolumeBars: View {
    let weeks: [TrainingStats.WeekVolume]

    var body: some View {
        let peak = max(weeks.map(\.volumeKg).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                if week.volumeKg > 0 {
                    let height = max(4, 72 * week.volumeKg / peak)
                    RoundedRectangle(cornerRadius: min(10, height / 2), style: .continuous)
                        .fill(Theme.barGradient)
                        .frame(height: height)
                } else {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255))
                        .frame(height: 2)
                }
            }
        }
        .frame(height: 90, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly volume, last 8 weeks")
    }
}

/// League card on Home: your position in the first group, or an invite when there is none.
struct LeagueTeaserCard: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Button {
            env.selectedTab = .leagues
        } label: {
            HStack(spacing: 14) {
                if let group = env.leagues.groups.first {
                    position(in: group)
                } else {
                    invite
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .dotTexture(opacity: 0.2 / 0.7, x: 14, y: -77.6)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    /// Appendix A.2: group, rank, score, gap to the next rank and countdown.
    @ViewBuilder
    private func position(in group: LeagueGroup) -> some View {
        let board = env.leagueBoards(for: group).first
        HStack(spacing: -14) {
            ForEach(board?.rows.prefix(3) ?? []) { AvatarView(name: $0.name, size: 38) }
        }
        divider
        VStack(alignment: .leading, spacing: 4) {
            Text(group.name)
            if let me = board?.me {
                Text(me.rank.map { "#\($0) · \(me.valueText)" } ?? String(localized: "Not ranked yet"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let gap = me.gapText {
                    Text(gap).font(.caption).foregroundStyle(.secondary)
                }
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(CountdownText.ends(from: context.date, to: env.leagues.closesAt(group)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    @ViewBuilder
    private var invite: some View {
        HStack(spacing: -14) {
            ForEach(1...3, id: \.self) { Image("Avatar\($0)").resizable().frame(width: 38, height: 38) }
        }
        .accessibilityHidden(true)
        divider
        VStack(alignment: .leading, spacing: 4) {
            Text("Weekly league")
            Text("Compete with friends on consistency, not just strength.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 40)
    }
}

/// Template card with an illustration of its main lift.
private struct QuickStartCard: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading) {
            Text(template.name).font(.callout).lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                HStack(spacing: 2) {
                    Image("IconClock")
                    Text("\(template.estimatedDurationMin) min")
                }
                Spacer(minLength: 4)
                Rectangle().fill(.white.opacity(0.2)).frame(width: 0.5, height: 10)
                Spacer(minLength: 4)
                HStack(spacing: 2) {
                    Image("IconClipboard")
                    Text("^[\(template.orderedExercises.count) exercise](inflect: true)")
                }
            }
            .font(.caption.weight(.light))
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background { art }
        .dotTexture("DotGridWeek", x: 14.5, y: -59.6)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    /// Position of each illustration inside the card, as fractions of the card (from the design).
    private var art: some View {
        let lower = isLowerBody
        let rect = lower
            ? CGRect(x: 0.0892, y: 0.2179, width: 0.7834, height: 0.7069)
            : CGRect(x: 0.1695, y: 0.2386, width: 0.6723, height: 0.5924)
        return GeometryReader { geo in
            Image(lower ? "QuickStartLower" : "QuickStartUpper")
                .resizable()
                .scaledToFit()
                .blendMode(.lighten) // the illustration's near-black backdrop melts into the card
                .frame(width: geo.size.width * rect.width, height: geo.size.height * rect.height)
                .offset(x: geo.size.width * rect.minX, y: geo.size.height * rect.minY)
        }
        .accessibilityHidden(true)
    }

    // ponytail: two illustrations (squat, bench); per-template art when templates get images
    private var isLowerBody: Bool {
        let muscles = template.orderedExercises.compactMap(\.exercise?.primaryMuscle)
        let lower = muscles.filter { [.quads, .hamstrings, .glutes, .calves].contains($0) }.count
        return lower * 2 > muscles.count
    }
}

/// Estimated value relative to the best record shown.
private struct RecordBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(stops: [
                    .init(color: Color(white: 0.6), location: 0.333),
                    .init(color: .white, location: 1),
                ], startPoint: .leading, endPoint: .trailing))
                .overlay { RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(.white.opacity(0.1)) }
                .frame(width: max(6, geo.size.width * min(fraction, 1)))
        }
        .frame(height: 6)
        .padding(5)
        .background(
            Color.white.opacity(0.04)
                .shadow(.inner(color: .white.opacity(0.1), radius: 27.5, x: 2, y: 4))
                .shadow(.inner(color: .white.opacity(0.25), radius: 1))
                .shadow(.inner(color: .white.opacity(0.1), radius: 8, x: 2, y: 4)),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

/// "Resume or discard" when starting while a workout is already active (section 14.1).
private struct StartConflictAlert: ViewModifier {
    @Environment(AppEnvironment.self) private var env

    func body(content: Content) -> some View {
        content.alert(
            "A workout is already running",
            isPresented: Binding(get: { env.workout.pendingStart != nil }, set: { if !$0 { env.workout.pendingStart = nil } })
        ) {
            Button("Resume current workout") { env.workout.resumeInsteadOfStarting() }
            Button("Discard and start new", role: .destructive) { env.workout.discardAndStartPending() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only one workout can be active at a time.")
        }
    }
}

extension View {
    func startConflictAlert() -> some View { modifier(StartConflictAlert()) }
}
