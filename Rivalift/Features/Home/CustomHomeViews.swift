import SwiftUI

/// Custom mode on Home (PLAN-05): for people with their own routines. This week by routine,
/// today's routine, all routines with ▶, and "Something different today". No plan advice here.
struct CustomHome: View {
    @Environment(AppEnvironment.self) private var env
    @State private var routines: [WorkoutTemplate] = []
    @State private var week: [RoutineWeek.Day] = []
    @State private var progress: WeekProgress?
    @State private var editing: WorkoutTemplate?
    @State private var toDelete: WorkoutTemplate?
    @State private var isBrowsing = false
    @State private var isIntroPresented = false
    @State private var buildAfterIntro = false

    private static let today = (Calendar.current.component(.weekday, from: Date()) + 5) % 7 + 1 // ISO: Monday = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            weekCard
            if let routine = todayRoutine { todayCard(routine) }
            VStack(alignment: .leading, spacing: 8) {
                header
                if routines.isEmpty {
                    emptyCard
                } else {
                    ForEach(routines) { row($0) }
                }
            }
            SomethingDifferentRow()
        }
        .navigationDestination(item: $editing) { TemplateEditorView(template: $0) }
        .navigationDestination(isPresented: $isBrowsing) { TemplatesView(opensPrograms: true) }
        .confirmationDialog("Delete \(toDelete?.name ?? "")?", isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let toDelete { env.templates.delete(toDelete) }
                reload()
            }
        } message: {
            Text("Your past workouts stay in History.")
        }
        .sheet(isPresented: $isIntroPresented, onDismiss: introDismissed) {
            CustomIntroSheet {
                buildAfterIntro = true
                isIntroPresented = false
            }
        }
        .onAppear {
            reload()
            if !env.settings.hasSeenCustomIntro { isIntroPresented = true }
        }
        .onChange(of: env.dataVersion) { _, _ in reload() }
    }

    private var todayRoutine: WorkoutTemplate? {
        guard let id = week.first(where: { $0.weekday == Self.today })?.routineID else { return nil }
        return routines.first { $0.id == id }
    }

    // MARK: This week

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                Spacer()
                if let progress {
                    Text("\(progress.sessions) of \(progress.target) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            HStack(spacing: 4) {
                ForEach(week, id: \.weekday) { column($0) }
            }
            if week.allSatisfy({ $0.routineID == nil }) {
                Text("Give your routines days to see your week here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func column(_ day: RoutineWeek.Day) -> some View {
        let isToday = day.weekday == Self.today
        let name = routines.first { $0.id == day.routineID }?.name
        let label = name.map { String($0.split(separator: " ").first ?? "") } ?? String(localized: "Rest")
        let symbol = Calendar(identifier: .iso8601).shortWeekdaySymbols[day.weekday % 7]
        return VStack(spacing: 5) {
            Text(isToday ? String(localized: "Today") : symbol)
                .font(.caption2.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? .primary : .secondary)
            marker(day.state)
            Text(label)
                .font(.caption2)
                .foregroundStyle(day.routineID == nil ? AnyShapeStyle(.tertiary) : isToday ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.accent.opacity(0.45)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Calendar(identifier: .iso8601).weekdaySymbols[day.weekday % 7]), \(name ?? String(localized: "rest day"))\(day.state == .done ? String(localized: ", done") : "")"))
    }

    @ViewBuilder
    private func marker(_ state: RoutineWeek.State) -> some View {
        switch state {
        case .done:
            Circle().fill(Theme.primaryGradient).frame(width: 26, height: 26)
                .overlay { Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(.white) }
        case .today:
            Circle().strokeBorder(Theme.accent, lineWidth: 2).frame(width: 26, height: 26)
        case .upcoming:
            Circle().strokeBorder(.white.opacity(0.2), lineWidth: 2).frame(width: 26, height: 26)
        case .missed:
            Circle().strokeBorder(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).frame(width: 26, height: 26)
        case .rest:
            Circle().fill(.white.opacity(0.16)).frame(width: 6, height: 6).frame(width: 26, height: 26)
        }
    }

    // MARK: Routines

    private func todayCard(_ routine: WorkoutTemplate) -> some View {
        let done = week.first { $0.weekday == Self.today }?.state == .done
        return VStack(alignment: .leading, spacing: 10) {
            Text(done ? "TODAY · DONE" : "TODAY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            HStack(spacing: 12) {
                NavigationLink { TemplateDetailView(template: routine) } label: {
                    summary(routine, titleFont: .title3.weight(.medium))
                }
                .buttonStyle(.plain)
                playButton(routine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Theme.accent.opacity(0.5)))
        .accessibilityIdentifier("todayRoutine")
    }

    private var header: some View {
        HStack {
            Text("Your routines").font(.headline.weight(.medium))
            Spacer()
            if !routines.isEmpty {
                Menu {
                    newRoutineButtons
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Theme.glassFill, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.border))
                        .frame(width: Theme.minTap, height: Theme.minTap)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("New routine")
                .accessibilityIdentifier("newRoutineMenu")
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var newRoutineButtons: some View {
        Button { newRoutine() } label: { Label("Build my own", systemImage: "square.and.pencil") }
        Button { isBrowsing = true } label: { Label("Start from a ready-made one", systemImage: "square.grid.2x2") }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add your first routine").font(.title3.weight(.medium))
                Text("Save the workout you already do. Next time it starts in one tap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button { newRoutine() } label: { Label("Build my own", systemImage: "square.and.pencil") }
                .buttonStyle(.primary)
                .accessibilityIdentifier("buildRoutine")
            Button { isBrowsing = true } label: { Label("Start from a ready-made one", systemImage: "square.grid.2x2") }
                .buttonStyle(.secondary)
                .accessibilityIdentifier("browseReadyMade")
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    /// Tap the card for details, ▶ to start, long-press to edit, duplicate or delete.
    private func row(_ routine: WorkoutTemplate) -> some View {
        HStack(spacing: 12) {
            NavigationLink { TemplateDetailView(template: routine) } label: {
                summary(routine, titleFont: .callout)
            }
            .buttonStyle(.plain)
            playButton(routine)
        }
        .padding(16)
        .glassCard()
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editing = routine }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                env.templates.duplicate(routine)
                reload()
            }
            Button("Delete", systemImage: "trash", role: .destructive) { toDelete = routine }
        }
    }

    private func summary(_ routine: WorkoutTemplate, titleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(routine.name).font(titleFont).lineLimit(1)
                if !routine.weekdays.isEmpty {
                    Text(Self.days(routine.weekdays))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .overlay(Capsule().strokeBorder(Theme.border))
                }
            }
            DividedText(parts: Array(routine.orderedExercises.compactMap(\.exercise?.name).prefix(3)))
            Text("\(routine.totalSets) sets · \(routine.estimatedDurationMin) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func playButton(_ routine: WorkoutTemplate) -> some View {
        Button { env.workout.requestStart(.template(routine.id)) } label: {
            Image(systemName: "play.fill")
                .font(.body)
                .foregroundStyle(.black)
                .frame(width: Theme.minTap, height: Theme.minTap)
                .background(.white, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(routine.name)")
    }

    /// "Mon · Fri".
    static func days(_ weekdays: Set<Int>) -> String {
        let symbols = Calendar(identifier: .iso8601).shortWeekdaySymbols
        return weekdays.sorted().map { symbols[$0 % 7] }.joined(separator: " · ")
    }

    // MARK: Actions

    private func newRoutine() {
        editing = env.templates.create(name: "")
    }

    private func introDismissed() {
        env.settings.hasSeenCustomIntro = true
        env.saveSettings()
        if buildAfterIntro {
            buildAfterIntro = false
            newRoutine()
        }
    }

    private func reload() {
        // A routine without exercises has nothing to start (a new one left before adding any).
        routines = env.templates.userTemplates().filter { !$0.orderedExercises.isEmpty }
        let current = env.weekProgress()
        progress = current
        let calendar = WeekCalendar()
        var trained = Set<Int>()
        for (index, day) in current.days.enumerated() where current.trainedDays.contains(calendar.localDateString(for: day)) {
            trained.insert(index + 1)
        }
        var assignments: [Int: UUID] = [:]
        for routine in routines {
            for weekday in routine.weekdays { assignments[weekday] = routine.id }
        }
        week = RoutineWeek.make(assignments: assignments, trainedWeekdays: trained, today: Self.today)
    }
}

/// One row for days off the routine or the plan: pick exercises, repeat the last workout, or a
/// suggested one (Quick Workout). Opens a short sheet.
struct SomethingDifferentRow: View {
    @Environment(AppEnvironment.self) private var env
    @State private var isSheetPresented = false
    @State private var isPickerPresented = false
    @State private var isQuickPresented = false
    @State private var choice: Choice?
    /// Picked exercises start once the picker has closed, so the workout cover is not
    /// presented on top of a closing sheet.
    @State private var pickedStart: WorkoutStore.StartRequest?
    @State private var lastSessionName: String?

    private enum Choice { case pick, repeatLast, suggest }

    var body: some View {
        Button { isSheetPresented = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "shuffle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.primaryGradient, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Something different today").font(.callout)
                    Text("Pick exercises, repeat your last one, or get a suggestion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image("IconChevronCircle").accessibilityHidden(true)
            }
            .padding(16)
            .glassCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("somethingDifferent")
        .sheet(isPresented: $isSheetPresented, onDismiss: chosen) { sheet }
        .sheet(isPresented: $isPickerPresented, onDismiss: startPicked) {
            ExercisePickerView(title: "Pick exercises") { selected in
                pickedStart = .exercises(selected.map(\.id))
            }
            .environment(env)
        }
        .navigationDestination(isPresented: $isQuickPresented) { QuickWorkoutView() }
        .onAppear { lastSessionName = env.sessions.completedSessions().first?.name }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Something different today").font(.title2.weight(.medium)).padding(.bottom, 6)
            option("Pick exercises myself", "Choose exercises and start now", icon: "list.bullet", id: "startPickExercises", .pick)
            if let lastSessionName {
                option("Repeat last workout", lastSessionName, icon: "arrow.counterclockwise", id: "repeatLastWorkout", .repeatLast)
            }
            option("Suggest one for me", "From your equipment, time and focus", icon: "sparkles", id: "suggestWorkout", .suggest)
            Text("These don't change your routines. You can save any of them as a routine after.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 12)
        .presentationDetents([.medium])
        .presentationBackground(Color(white: 0.08))
    }

    private func option(_ title: LocalizedStringKey, _ subtitle: String, icon: String, id: String, _ value: Choice) -> some View {
        Button {
            choice = value
            isSheetPresented = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.primaryGradient, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image("IconChevronCircle").accessibilityHidden(true)
            }
            .padding(14)
            .glassCard(cornerRadius: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Runs the choice once the sheet has closed, so nothing opens on top of a closing sheet.
    private func chosen() {
        switch choice {
        case .pick: isPickerPresented = true
        case .repeatLast: env.workout.requestStart(.repeatLast)
        case .suggest: isQuickPresented = true
        case nil: break
        }
        choice = nil
    }

    private func startPicked() {
        guard let pickedStart else { return }
        self.pickedStart = nil
        env.workout.requestStart(pickedStart)
    }
}

/// Shown once, the first time Custom opens: what Custom is for.
struct CustomIntroSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom is for your own routines").font(.title.weight(.medium))
                Text("You decide what to train. Rivalift keeps it ready and logs it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            point("list.bullet", "Save your routines", "Build the workouts you already do, or start from a ready-made one. Give each its days.")
            point("play.fill", "Start in one tap", "Home shows today's routine. Tap play and log as you go.")
            point("shuffle", "Something different today?", "Pick exercises or get a suggestion. Save it as a routine after.")
            Text("Prefer a guided plan? Switch to My Plan anytime from the title.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                Button("Add my first routine", action: onBuild)
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("customIntroBuild")
                Button("Got it") { dismiss() }
                    .buttonStyle(.secondary)
                    .accessibilityIdentifier("customIntroDone")
            }
        }
        .padding(24)
        .padding(.top, 12)
        .presentationDetents([.large])
        .presentationBackground(Color(white: 0.08))
    }

    private func point(_ icon: String, _ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.primaryGradient, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline.weight(.medium))
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
