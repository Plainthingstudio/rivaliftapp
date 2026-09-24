import SwiftUI

/// PROG-06 / LOG-01 / appendix A.2.
struct HomeView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var progress: WeekProgress?
    @State private var quickTemplates: [WorkoutTemplate] = []
    @State private var recentRecords: [PersonalRecord] = []
    @State private var hasHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                greeting
                if let progress { WeekCard(progress: progress) }
                startButtons
                LeagueTeaserCard()
                if !quickTemplates.isEmpty { quickStart }
                if !recentRecords.isEmpty { records }
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Home")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: reload)
        .onChange(of: env.dataVersion) { _, _ in reload() }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(env.settings.displayName.isEmpty ? String(localized: "Let's lift") : String(localized: "Hi, \(env.settings.displayName)"))
                    .font(.largeTitle.bold())
            }
            Spacer()
            Button {
                env.selectedTab = .profile
            } label: {
                AvatarView(name: env.settings.displayName.isEmpty ? "?" : env.settings.displayName, size: 44)
            }
            .accessibilityLabel("Profile")
        }
    }

    private var startButtons: some View {
        VStack(spacing: 10) {
            if env.workout.session != nil {
                Button("Resume workout") { env.workout.isPresented = true }
                    .buttonStyle(.primary)
            } else {
                Button {
                    env.workout.requestStart(.empty)
                } label: {
                    Label("Start workout", systemImage: "play.fill")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("startWorkoutButton")
                if hasHistory {
                    Button {
                        env.workout.requestStart(.repeatLast)
                    } label: {
                        Label("Repeat last workout", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
    }

    private var quickStart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Quick start").font(.headline)
                Spacer()
                NavigationLink("All templates") { TemplatesView() }
                    .font(.subheadline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(quickTemplates) { template in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Text(template.orderedExercises.compactMap(\.exercise?.name).prefix(3).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Button("Start") { env.workout.requestStart(.template(template.id)) }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                        .frame(width: 180, height: 120, alignment: .leading)
                        .card()
                    }
                }
            }
        }
    }

    private var records: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Records this week", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(Theme.pr)
            ForEach(recentRecords) { record in
                HStack {
                    Text(record.exercise?.name ?? "")
                    Spacer()
                    Text("\(record.prType.displayName) · \(WeightFormatter.string(kg: record.valueKg, unit: env.unit, includeUnit: true))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .card()
    }

    private func reload() {
        progress = env.weekProgress()
        quickTemplates = env.templates.recentlyUsed()
        if quickTemplates.isEmpty {
            quickTemplates = Array(env.templates.builtInTemplates().prefix(3))
        }
        let calendar = WeekCalendar()
        let weekSessions = env.sessions.completedSessions(from: calendar.weekStart(for: Date()), to: calendar.weekEnd(for: Date()))
        recentRecords = Array(
            weekSessions.flatMap { $0.personalRecords ?? [] }
                .filter { $0.prType == .weight || $0.prType == .e1rm }
                .sorted { $0.achievedAt > $1.achievedAt }
                .prefix(3)
        )
        hasHistory = env.sessions.completedSessionCount() > 0
    }
}

/// "This week": Monday–Sunday dots, sessions vs target, weekly streak.
struct WeekCard: View {
    let progress: WeekProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week").font(.headline)
                Spacer()
                Label("\(progress.streakWeeks)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.streakWeeks > 0 ? Color.orange : Color.secondary)
                    .accessibilityLabel("\(progress.streakWeeks) week streak")
            }
            HStack {
                ForEach(progress.days, id: \.self) { day in
                    let trained = progress.trainedDays.contains(WeekCalendar().localDateString(for: day))
                    let isToday = Calendar.current.isDateInToday(day)
                    VStack(spacing: 6) {
                        Text(day, format: .dateTime.weekday(.narrow))
                            .font(.caption.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? .primary : .secondary)
                        ZStack {
                            Circle()
                                .fill(trained ? Theme.accent : Theme.elevated)
                                .frame(width: 30, height: 30)
                            if trained {
                                Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide)) + Text(trained ? ", trained" : ""))
                }
            }
            Text("\(progress.sessions) of \(progress.target) sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .card()
    }
}

/// League card on Home. Leagues need an account (M4/M5), so for now it explains them.
struct LeagueTeaserCard: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Button {
            env.selectedTab = .leagues
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly league").font(.headline).foregroundStyle(.primary)
                    Text("Compete with friends on consistency, not just strength.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .card()
        }
        .buttonStyle(.plain)
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
