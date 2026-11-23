import SwiftUI

/// "Your plan": the plan's workouts and settings. Opens as a preview; Edit unlocks the
/// schedule, length and goal, and changing plan.
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
                    VStack(spacing: 8) {
                        ForEach(Array(plan.program.templates.enumerated()), id: \.element.id) { index, workout in
                            NavigationLink { TemplateDetailView(template: workout) } label: {
                                dayCard(index: index, workout: workout, plan: plan)
                            }
                            .buttonStyle(.plain)
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

    private func dayCard(index: Int, workout: WorkoutTemplate, plan: AppEnvironment.PlanHome) -> some View {
        let day = plan.week.days.first { $0.workoutID == workout.id }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(index + 1) · \(workout.name)").font(.headline.weight(.medium))
                    Group {
                        if let day {
                            Text("\(workout.orderedExercises.count) exercises · \(workout.estimatedDurationMin) min · \(day.date.formatted(.dateTime.weekday(.abbreviated)))")
                        } else {
                            Text("\(workout.orderedExercises.count) exercises · \(workout.estimatedDurationMin) min")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
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

    /// Read-only settings in preview mode.
    private var summary: some View {
        let symbols = Calendar(identifier: .iso8601).shortWeekdaySymbols
        let days = env.planWeekdays().sorted().map { symbols[$0 % 7] }.joined(separator: ", ")
        return GlassSection("Settings") {
            summaryRow("Training days", days)
            GlassDivider()
            summaryRow("Plan length", String(localized: "\(planWeeks) weeks"))
            GlassDivider()
            summaryRow("Goal", AppEnvironment.planTitle(for: env.settings.goal))
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
                    set: { env.settings.trainingWeekdays = $0; env.saveSettings() }
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
            GlassDivider()
            HStack {
                Text("Goal").font(.subheadline)
                Spacer()
                Picker("Goal", selection: Binding(
                    get: { env.settings.goal },
                    set: { env.settings.goal = $0; env.saveSettings() }
                )) {
                    ForEach(TrainingGoal.allCases) { Text(AppEnvironment.planTitle(for: $0)).tag($0) }
                }
                .labelsHidden()
                .tint(.secondary)
            }
            .frame(minHeight: Theme.minTap)
        }
    }

    private func reload() {
        plan = env.planHome()
    }
}

/// Built-in programs to switch to; the new plan starts this week.
private struct ChoosePlanSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(env.templates.programs()) { program in
                        let current = program.name == env.settings.planProgram
                        Button { choose(program) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppEnvironment.splitName(for: program.name)).font(.headline.weight(.medium))
                                    Text("^[\(program.templates.count) workout](inflect: true): \(program.templates.map(\.name).joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                if current {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent).accessibilityHidden(true)
                                }
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(current ? .isSelected : [])
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

    private func choose(_ program: TemplateRepository.Program) {
        if program.name != env.settings.planProgram {
            env.settings.planProgram = program.name
            env.settings.planStartedAt = Date()
            env.settings.daySwapsRaw = ""
            env.saveSettings()
        }
        dismiss()
    }
}
