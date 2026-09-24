import SwiftUI

/// LOG-01: choose what to train before the session (and its clock) starts: the
/// recommended next workout, own exercises, the last session, or any template.
struct StartWorkoutSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var recommendation: AppEnvironment.Recommendation?
    @State private var userTemplates: [WorkoutTemplate] = []
    @State private var programs: [TemplateRepository.Program] = []
    @State private var lastSessionName: String?
    @State private var isPickerPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let recommendation { recommended(recommendation) }
                    BigChoice(
                        title: String(localized: "Pick exercises"),
                        subtitle: String(localized: "Build today's workout one exercise at a time"),
                        isSelected: false
                    ) { isPickerPresented = true }
                    .accessibilityIdentifier("startPickExercises")
                    if let lastSessionName {
                        BigChoice(
                            title: String(localized: "Repeat last workout"),
                            subtitle: lastSessionName,
                            isSelected: false
                        ) { env.workout.choose(.repeatLast) }
                    }
                    if !userTemplates.isEmpty {
                        section("Your templates", templates: userTemplates)
                    }
                    ForEach(programs) { program in
                        section(LocalizedStringKey(program.name), templates: program.templates)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Start a workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $isPickerPresented) {
                ExercisePickerView(title: "Pick exercises") { selected in
                    env.workout.choose(.exercises(selected.map(\.id)))
                }
                .environment(env)
            }
        }
        .onAppear(perform: load)
    }

    private func recommended(_ recommendation: AppEnvironment.Recommendation) -> some View {
        let template = recommendation.template
        return VStack(alignment: .leading, spacing: 8) {
            Label("Recommended for you", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            Text(template.name).font(.title2.bold())
            Text(recommendation.reason).font(.subheadline).foregroundStyle(.secondary)
            Text(template.orderedExercises.compactMap(\.exercise?.name).joined(separator: " · "))
                .font(.subheadline)
                .lineLimit(3)
            Text("\(template.orderedExercises.count) exercises · \(template.totalSets) sets · ~\(template.estimatedDurationMin) min")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                env.workout.choose(.template(template.id))
            } label: {
                Label("Start \(template.name)", systemImage: "play.fill")
            }
            .buttonStyle(.primary)
            .padding(.top, 4)
            .accessibilityIdentifier("startRecommended")
        }
        .card()
    }

    private func section(_ title: LocalizedStringKey, templates: [WorkoutTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.top, 8)
            ForEach(templates) { template in
                BigChoice(
                    title: template.name,
                    subtitle: String(localized: "\(template.orderedExercises.count) exercises · ~\(template.estimatedDurationMin) min"),
                    isSelected: false
                ) { env.workout.choose(.template(template.id)) }
            }
        }
    }

    private func load() {
        recommendation = env.recommendedWorkout()
        userTemplates = env.templates.userTemplates()
        // The user's plan first, then the other programs in seed order.
        let all = env.templates.programs()
        programs = all.filter { $0.name == env.settings.planProgram } + all.filter { $0.name != env.settings.planProgram }
        lastSessionName = env.sessions.completedSessions().first?.name
    }
}
