import SwiftUI

/// LOG-01: choose what to train before the session (and its clock) starts: the
/// recommended next workout, own exercises, the last session, or any template.
struct StartWorkoutView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var recommendation: AppEnvironment.Recommendation?
    @State private var userTemplates: [WorkoutTemplate] = []
    @State private var lastSessionName: String?
    @State private var isPickerPresented = false
    /// Picked exercises start once the picker has closed, so the workout cover is not
    /// presented on top of a closing sheet.
    @State private var pickedStart: WorkoutStore.StartRequest?

    var body: some View {
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
                    ) { env.workout.requestStart(.repeatLast) }
                }
                if !userTemplates.isEmpty {
                    Text("Your templates").font(.headline).padding(.top, 8)
                    ForEach(userTemplates) { template in
                        NavigationLink {
                            TemplateDetailView(template: template)
                        } label: {
                            row(template.name, String(localized: "\(template.orderedExercises.count) exercises · ~\(template.estimatedDurationMin) min"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                NavigationLink {
                    TemplatesView()
                } label: {
                    row(String(localized: "Browse all templates"), String(localized: "Programs and your own templates"))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("browseTemplates")
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Start a workout")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isPickerPresented, onDismiss: startPicked) {
            ExercisePickerView(title: "Pick exercises") { selected in
                pickedStart = .exercises(selected.map(\.id))
            }
            .environment(env)
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
            HStack {
                Text("\(template.orderedExercises.count) exercises · \(template.totalSets) sets · ~\(template.estimatedDurationMin) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                NavigationLink("Details") { TemplateDetailView(template: template) }
                    .font(.subheadline)
            }
            Button {
                env.workout.requestStart(.template(template.id))
            } label: {
                Label("Start \(template.name)", systemImage: "play.fill")
            }
            .buttonStyle(.primary)
            .padding(.top, 4)
            .accessibilityIdentifier("startRecommended")
        }
        .card()
    }

    /// Same look as `BigChoice`, as a label for navigation links.
    private func row(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func startPicked() {
        guard let pickedStart else { return }
        self.pickedStart = nil
        env.workout.requestStart(pickedStart)
    }

    private func load() {
        recommendation = env.recommendedWorkout()
        userTemplates = env.templates.userTemplates()
        lastSessionName = env.sessions.completedSessions().first?.name
    }
}
