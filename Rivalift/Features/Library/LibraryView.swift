import SwiftUI

/// Library tab: plans, exercises and the user's own workouts in one place.
struct LibraryView: View {
    @State private var segment: Segment = .plans

    enum Segment: Hashable { case plans, exercises, workouts }

    var body: some View {
        Group {
            switch segment {
            case .plans: LibraryPlansView()
            case .exercises: ExerciseLibraryView()
            case .workouts: TemplatesView(showsPrograms: false)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            PillPicker(selection: $segment, options: [(.plans, "Plans"), (.exercises, "Exercises"), (.workouts, "My workouts")])
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Your current plan, then every plan named for what it does.
private struct LibraryPlansView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var home: AppEnvironment.PlanHome?

    var body: some View {
        let current = env.currentPlan
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let home {
                    caption("CURRENT PLAN")
                    NavigationLink { PlanView() } label: {
                        PlanCatalogCard(plan: current, detail: String(localized: "Week \(home.progress.week) of \(home.progress.weeks) · \(home.subtitle)"), isCurrent: true)
                    }
                    .buttonStyle(.plain)
                }
                caption("ALL PLANS").padding(.top, 8)
                ForEach(PlanCatalog.all.filter { $0.id != current.id || home == nil }) { plan in
                    NavigationLink { PlanDetailView(plan: plan) } label: {
                        PlanCatalogCard(plan: plan)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("plan-\(plan.id)")
                }
            }
            .padding()
        }
        .screenBackground()
        .onAppear { home = env.planHome() }
        .onChange(of: env.dataVersion) { _, _ in home = env.planHome() }
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 4)
    }
}

/// A plan in a list: name, what it does, and days, weeks and level chips.
struct PlanCatalogCard: View {
    let plan: TrainingPlan
    /// Replaces the chips, e.g. "Week 2 of 8 · Full body · 3 days a week" for the current plan.
    var detail: String?
    var isCurrent = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title).font(.headline.weight(.medium))
                    Text(detail ?? plan.summary).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                }
                if detail == nil {
                    HStack(spacing: 6) {
                        ForEach([plan.daysText, String(localized: "\(plan.weeks) weeks"), plan.levelName], id: \.self) { chip in
                            Text(chip)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .overlay(Capsule().strokeBorder(Theme.border))
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(isCurrent ? Theme.accent : .secondary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { if isCurrent { Theme.accent.opacity(0.12) } }
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// A plan before starting it: days a week, which days, a fuller first week when starting
/// mid-week, and the workouts. Switching from another plan asks first.
struct PlanDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    let plan: TrainingPlan
    /// After starting; the default goes back and shows Home.
    var onStart: (() -> Void)?
    @State private var days: Int?
    @State private var weekdays: Set<Int>?
    @State private var fitThisWeek = false
    @State private var isConfirming = false

    private static let symbols = Calendar(identifier: .iso8601).shortWeekdaySymbols
    private static func names(_ days: Set<Int>) -> String {
        days.sorted().map { symbols[$0 % 7] }.joined(separator: ", ")
    }

    var body: some View {
        let hasPlan = env.planHome() != nil
        let isCurrent = plan.id == env.currentPlan.id && hasPlan
        let days = days ?? env.suggestedDays(for: plan)
        let weekdays = weekdays ?? (env.planWeekdays().count == days ? env.planWeekdays() : PlanWeek.defaultWeekdays(count: days))
        let programName = plan.program(daysPerWeek: days)
        let workouts = env.templates.programs().first { $0.name == programName }?.templates ?? []
        let today = (Calendar.current.component(.weekday, from: Date()) + 5) % 7 + 1 // ISO: Monday = 1
        let catchUp = PlanWeek.catchUpWeekdays(count: days, weekdays: weekdays, today: today)
        let unchanged = isCurrent && env.settings.planProgram == programName && weekdays == env.planWeekdays()
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title).font(.largeTitle)
                    Text(plan.summary).font(.subheadline).foregroundStyle(.secondary)
                    Text("\(plan.weeks) weeks · \(plan.levelName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                if plan.days.count > 1 { dayCountPicker(selected: days) }
                VStack(alignment: .leading, spacing: 8) {
                    caption("WHICH DAYS")
                    WeekdayPicker(selection: Binding(get: { weekdays }, set: { self.weekdays = $0 }))
                    if weekdays.count != days {
                        Text("Pick ^[\(days) day](inflect: true). You picked \(weekdays.count).")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let catchUp, weekdays.count == days { thisWeekCard(catchUp, days: days, weekdays: weekdays, today: today) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("What's inside: \(AppEnvironment.splitName(for: programName))").font(.headline.weight(.medium))
                    Group {
                        if workouts.count < days {
                            Text("^[\(workouts.count) workout](inflect: true) on repeat. Next week picks up where you left off.")
                        } else {
                            Text("^[\(days) workout](inflect: true) a week.")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if !workouts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(weekdays.sorted().enumerated()), id: \.element) { index, weekday in
                            let workout = workouts[index % workouts.count]
                            NavigationLink { TemplateDetailView(template: workout) } label: {
                                dayCard(day: Self.symbols[weekday % 7], workout: workout)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if unchanged {
                    Button("This is your plan") {}.buttonStyle(.secondary).disabled(true)
                } else {
                    Button(isCurrent ? String(localized: "Save changes") : String(localized: "Start this plan · \(days) days")) {
                        if hasPlan { isConfirming = true } else { start(days: days, weekdays: weekdays, catchUp: catchUp) }
                    }
                    .buttonStyle(.primary)
                    .disabled(weekdays.count != days)
                    .accessibilityIdentifier("startThisPlan")
                }
            }
            .padding(.horizontal)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .background(Theme.bottomFade)
        }
        .alert(isCurrent ? String(localized: "Change your plan?") : String(localized: "Switch to \(plan.title)?"), isPresented: $isConfirming) {
            Button(isCurrent ? String(localized: "Save changes") : String(localized: "Switch plan")) {
                start(days: days, weekdays: weekdays, catchUp: catchUp)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if isCurrent {
                Text("\(plan.title) keeps going with \(AppEnvironment.splitName(for: programName)) on \(Self.names(weekdays)).")
            } else {
                Text("\(env.currentPlan.title) stops and \(plan.title) starts this week, week 1 of \(plan.weeks). Your workouts and records stay.")
            }
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func start(days: Int, weekdays: Set<Int>, catchUp: Set<Int>?) {
        env.startPlan(plan, daysPerWeek: days, weekdays: weekdays, thisWeek: fitThisWeek ? catchUp : nil)
        if let onStart { onStart() } else {
            dismiss()
            env.selectedTab = .home
        }
    }

    private func caption(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
    }

    /// One large button per day count, with the split it gets.
    private func dayCountPicker(selected: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            caption("DAYS A WEEK")
            HStack(spacing: 8) {
                ForEach(Array(plan.days), id: \.self) { count in
                    let isSelected = count == selected
                    Button {
                        days = count
                        weekdays = nil
                        fitThisWeek = false
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(count) days").font(.title3.weight(.semibold))
                            Text(AppEnvironment.splitName(for: plan.program(daysPerWeek: count)))
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68)
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(isSelected ? AnyShapeStyle(Theme.primaryGradient) : AnyShapeStyle(Theme.glassFill))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(isSelected ? Theme.accent.opacity(0.6) : Theme.border)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("planDays-\(count)")
                }
            }
        }
    }

    /// Starting mid-week: offer to fit the week's workouts into the days left.
    private func thisWeekCard(_ catchUp: Set<Int>, days: Int, weekdays: Set<Int>, today: Int) -> some View {
        let usual = weekdays.filter { $0 >= today }
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $fitThisWeek) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(catchUp.count < days
                         ? String(localized: "Fit ^[\(catchUp.count) workout](inflect: true) into this week")
                         : String(localized: "Fit all \(days) workouts into this week"))
                        .font(.subheadline.weight(.medium))
                    Text(fitThisWeek
                         ? String(localized: "This week: \(Self.names(catchUp)). From next week: \(Self.names(weekdays)).")
                         : usual.isEmpty
                            ? String(localized: "You're starting late this week, so your first workout is next week.")
                            : String(localized: "This week you'd train \(Self.names(usual)) only, since the week has started."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accent)
            .accessibilityIdentifier("fitThisWeek")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    private func dayCard(day: String, workout: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(day) · \(workout.name)").font(.headline.weight(.medium))
                    Text("\(workout.orderedExercises.count) exercises · \(workout.estimatedDurationMin) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
            }
            HStack(spacing: 6) {
                ForEach(workout.orderedExercises.prefix(5)) { ExercisePhoto(exercise: $0.exercise, width: 52, height: 40) }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
    }
}
