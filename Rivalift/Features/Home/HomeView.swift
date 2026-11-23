import SwiftUI

/// PROG-06 / LOG-01 / appendix A.2. Layout follows Figma "Home" (node 163:32961).
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var progress: WeekProgress?
    /// Personal streak with rest weeks (the league streak has none).
    @State private var streak: PersonalStreak?
    @State private var quickTemplates: [WorkoutTemplate] = []
    @State private var recentRecords: [PersonalRecord] = []
    @State private var overview: AppEnvironment.TrainingOverview?
    @State private var plan: AppEnvironment.PlanHome?

    /// My Plan needs a plan; without one (onboarding skipped) Home is always Custom.
    private var showsPlan: Bool { plan != nil && env.settings.homeMode == .plan }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if showsPlan, let plan {
                    NavigationLink { PlanView() } label: { PlanCard(plan: plan) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("planCard")
                    PlanWeekStrip(plan: plan)
                    PlanToday(plan: plan)
                } else {
                    if let progress { WeekCard(progress: progress) }
                    startButton
                    if !quickTemplates.isEmpty { quickStart }
                }
                LeagueTeaserCard()
                if !recentRecords.isEmpty { records }
                if let overview, overview.totalWorkouts > 0 { MetricsCard(overview: overview, unit: env.unit) }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if showsPlan, let plan { PlanStartButton(plan: plan) }
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

    /// Date, the mode switcher ("My Plan ▾") and the weekly streak.
    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if plan != nil {
                    Menu {
                        Picker("Home mode", selection: homeMode) {
                            Label("My Plan", systemImage: "sparkles").tag(HomeMode.plan)
                            Label("Custom", systemImage: "square.and.pencil").tag(HomeMode.custom)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showsPlan ? "My Plan" : "Custom").font(.largeTitle)
                            Image(systemName: "chevron.down").font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(minHeight: Theme.minTap)
                    }
                    .accessibilityIdentifier("homeModeMenu")
                } else {
                    Text("Home").font(.largeTitle).frame(minHeight: Theme.minTap)
                }
            }
            Spacer()
            if let streak {
                NavigationLink { StreakView() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").foregroundStyle(Theme.heat)
                        Text("\(streak.current)").font(.callout.weight(.medium)).monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: Theme.minTap)
                    .background(Theme.glassFill, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.border))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(streak.current) week streak")
                .accessibilityHint("Shows your streak and rest weeks")
                .accessibilityIdentifier("streakButton")
            }
        }
        .padding(.top, 12)
    }

    private var homeMode: Binding<HomeMode> {
        Binding(
            get: { env.settings.homeMode },
            set: { env.settings.homeMode = $0; env.saveSettings() }
        )
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Personal bests this week").font(.headline.weight(.medium))
                Spacer()
                Text("\(recentRecords.count) new")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.success.opacity(0.2), in: Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            ForEach(recentRecords) { record in
                if let exercise = record.exercise {
                    NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                        recordRow(record, exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func recordRow(_ record: PersonalRecord, exercise: Exercise) -> some View {
        let weight = WeightFormatter.string(kg: record.valueKg, unit: env.unit, includeUnit: true)
        return HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.body)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Theme.primaryGradient, in: Circle())
                .overlay(Circle().strokeBorder(Theme.accent.opacity(0.5)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.callout.weight(.medium))
                Text(record.achievedAt, format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(record.prType == .weight && record.reps > 0 ? "\(weight) × \(record.reps)" : String(localized: "\(weight) 1RM"))
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.border))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func reload() {
        progress = env.weekProgress()
        streak = env.streakOverview().streak
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
        plan = env.planHome()
    }
}

/// "This week": Monday–Sunday dots and sessions vs target.
struct WeekCard: View {
    let progress: WeekProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week")
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

/// Training summary on Home: this week vs last week, and total lifted per week.
struct MetricsCard: View {
    let overview: AppEnvironment.TrainingOverview
    let unit: WeightUnit

    var body: some View {
        let now = overview.thisWeek, last = overview.lastWeek
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your training").font(.headline.weight(.medium))
                Spacer()
                Text("vs last week").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 8) {
                metric("\(now.sessions)", "Workouts", last: "\(last.sessions)")
                metric(DurationFormatter.short(now.durationSec), "Time trained", last: DurationFormatter.short(last.durationSec))
                metric(volume(now.volumeKg), "Total lifted", last: volume(last.volumeKg))
            }
            VolumeBars(weeks: overview.weeklyVolume)
            Text("Total lifted per week, last 8 weeks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func volume(_ kg: Double) -> String {
        WeightFormatter.string(kg: kg, unit: unit, includeUnit: true)
    }

    private func metric(_ value: String, _ label: LocalizedStringKey, last: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label).font(.caption)
            Text("last week \(last)").font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Weekly volume: weeks with volume as blue bars, empty weeks as a thin line.
private struct VolumeBars: View {
    let weeks: [TrainingStats.WeekVolume]

    var body: some View {
        let peak = max(weeks.map(\.volumeKg).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                if week.volumeKg > 0 {
                    let height = max(4, 72 * week.volumeKg / peak)
                    RoundedRectangle(cornerRadius: min(6, height / 2), style: .continuous)
                        .fill(Theme.primaryGradient)
                        .frame(height: height)
                } else {
                    Capsule().fill(.white.opacity(0.16)).frame(height: 2)
                }
            }
        }
        .frame(height: 80, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly volume, last 8 weeks")
    }
}

/// League card on Home: the top of the first group's board, or an invite when there is none.
struct LeagueTeaserCard: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Button {
            env.selectedTab = .leagues
        } label: {
            Group {
                if let group = env.leagues.groups.first {
                    standings(group)
                } else {
                    invite
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    /// Appendix A.2: group, rank, countdown, the top rows and the gap to the next rank.
    @ViewBuilder
    private func standings(_ group: LeagueGroup) -> some View {
        let board = env.leagueBoards(for: group).first
        let rows = board?.rows ?? []
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly league").font(.headline.weight(.medium))
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text("\(group.name) · \(CountdownText.ends(from: context.date, to: env.leagues.closesAt(group)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let rank = board?.me?.rank {
                    Text("#\(rank)").font(.title3.weight(.medium))
                        + Text(" of \(rows.count)").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 4) {
                ForEach(Self.topRows(rows)) { row in
                    HStack(spacing: 10) {
                        Text(row.rank.map(String.init) ?? "–")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .frame(width: 18)
                        AvatarView(name: row.name, size: 28)
                        Text(row.isMe ? String(localized: "You") : row.name).font(.subheadline)
                        Spacer()
                        Text(row.valueText).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(row.isMe ? Theme.accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            if let gap = board?.me?.gapText {
                Text(gap).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Top three; if you are lower, the top two and you.
    static func topRows(_ rows: [BoardRow]) -> [BoardRow] {
        let top = Array(rows.prefix(3))
        guard let me = rows.first(where: \.isMe), !top.contains(me) else { return top }
        return Array(rows.prefix(2)) + [me]
    }

    private var invite: some View {
        HStack(spacing: 14) {
            HStack(spacing: -14) {
                ForEach(1...3, id: \.self) { Image("Avatar\($0)").resizable().frame(width: 38, height: 38) }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly league").font(.headline.weight(.medium))
                Text("Compete with friends on consistency, not just strength.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
        }
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
