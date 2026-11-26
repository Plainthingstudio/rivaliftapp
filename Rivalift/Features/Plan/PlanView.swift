import SwiftUI

/// "Your plan": this week's workouts and the plan's settings. Opens as a preview; Edit unlocks
/// training days (which re-pick the program for that many days), length, and changing plan.
struct PlanView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var plan: AppEnvironment.PlanHome?
    @State private var isChoosingPlan = false
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let plan {
                    header(plan)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This week").font(.headline.weight(.medium)).padding(.horizontal, 4)
                        ForEach(plan.week.days.filter { $0.state != .rest }, id: \.date) { day in
                            if let workout = plan.workout(day.workoutID) {
                                NavigationLink { TemplateDetailView(template: workout) } label: {
                                    dayCard(day, workout: workout)
                                }
                                .buttonStyle(.plain)
                            } else {
                                missedCard(day)
                            }
                        }
                    }
                    if isEditing { settings } else { summary }
                }
                if isEditing {
                    Button("Change plan") { isChoosingPlan = true }
                        .buttonStyle(.secondary)
                        .accessibilityIdentifier("changePlanButton")
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Your plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") { withAnimation(.snappy) { isEditing.toggle() } }
                    .fontWeight(isEditing ? .semibold : .regular)
                    .accessibilityIdentifier("editPlanButton")
            }
        }
        .sheet(isPresented: $isChoosingPlan) { ChoosePlanSheet() }
        .onAppear(perform: reload)
        .onChange(of: env.dataVersion) { _, _ in reload() }
    }

    private func header(_ plan: AppEnvironment.PlanHome) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.title).font(.largeTitle)
            Text("\(plan.subtitle) · \(plan.progress.weeks) weeks").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text("Week \(plan.progress.week) of \(plan.progress.weeks)")
                if let start = env.settings.planStartedAt {
                    Text("·")
                    Text("Started \(start.formatted(.dateTime.day().month()))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
    }

    /// A training day this week: weekday, workout, and done or today.
    private func dayCard(_ day: PlanWeek.Day, workout: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(day.date.formatted(.dateTime.weekday(.abbreviated))) · \(workout.name)").font(.headline.weight(.medium))
                    Text("\(workout.orderedExercises.count) exercises · \(workout.estimatedDurationMin) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                switch day.state {
                case .done: Label("Done", systemImage: "checkmark.circle.fill").font(.caption.weight(.medium)).foregroundStyle(Theme.success)
                case .today: Text("Today").font(.caption.weight(.medium)).foregroundStyle(Theme.accent)
                default: Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
                }
            }
            HStack(spacing: 6) {
                ForEach(workout.orderedExercises.prefix(5)) { item in
                    ExercisePhoto(exercise: item.exercise, width: 52, height: 40)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .contentShape(Rectangle())
    }

    private func missedCard(_ day: PlanWeek.Day) -> some View {
        HStack {
            Text("\(day.date.formatted(.dateTime.weekday(.abbreviated))) · Missed").font(.headline.weight(.medium))
            Spacer()
            Text("Your next workout moves to the next training day").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .opacity(0.7)
        .accessibilityElement(children: .combine)
    }

    /// Read-only settings in preview mode.
    private var summary: some View {
        let symbols = Calendar(identifier: .iso8601).shortWeekdaySymbols
        let days = env.planWeekdays().sorted().map { symbols[$0 % 7] }.joined(separator: ", ")
        return GlassSection("Settings") {
            summaryRow("Training days", days)
            GlassDivider()
            summaryRow("Plan length", String(localized: "\(planWeeks) weeks"))
        }
    }

    private func summaryRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(minHeight: Theme.minTap)
        .accessibilityElement(children: .combine)
    }

    private var planWeeks: Int { env.settings.streakGoalWeeks > 0 ? env.settings.streakGoalWeeks : 8 }

    private var settings: some View {
        GlassSection("Settings") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Training days").font(.subheadline)
                WeekdayPicker(selection: Binding(
                    get: { env.planWeekdays() },
                    set: { env.setTrainingDays($0) }
                ))
            }
            GlassDivider()
            Stepper(value: Binding(
                get: { planWeeks },
                set: { env.settings.streakGoalWeeks = $0; env.saveSettings() }
            ), in: 4...16, step: 2) {
                HStack {
                    Text("Plan length").font(.subheadline)
                    Spacer()
                    Text("\(planWeeks) weeks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: Theme.minTap)
        }
    }

    private func reload() {
        plan = env.planHome()
    }
}

/// Plans to switch to; the new plan starts this week.
private struct ChoosePlanSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let current = env.currentPlan.id
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(PlanCatalog.all) { plan in
                        NavigationLink { PlanDetailView(plan: plan) { dismiss() } } label: {
                            PlanCatalogCard(plan: plan, isCurrent: plan.id == current)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Change plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}
