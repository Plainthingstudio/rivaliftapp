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
            VStack(alignment: .leading, spacing: 14) {
                if let recommendation { recommended(recommendation) }
                choices
                if !userTemplates.isEmpty {
                    Text("Your templates").padding(.horizontal, 8).padding(.top, 8)
                    ForEach(userTemplates) { template in
                        NavigationLink {
                            TemplateDetailView(template: template)
                        } label: {
                            TemplateRowCard(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .screenBackground()
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

    /// Figma "Recommended": blue-lit card with the next workout, then its start button.
    @ViewBuilder
    private func recommended(_ recommendation: AppEnvironment.Recommendation) -> some View {
        let template = recommendation.template
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Image("Icon_sparkle").accessibilityHidden(true)
                Text("Recommended for you").font(.caption.weight(.medium))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(template.name).font(.title2)
                DividedText(parts: recommendation.reason.components(separatedBy: " · "))
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(template.orderedExercises.compactMap(\.exercise), id: \.id) { exercise in
                    HStack(spacing: 10) {
                        ExercisePhoto(exercise: exercise, width: 40, height: 29)
                        Text(exercise.name).font(.subheadline)
                    }
                }
            }
            HStack {
                DividedText(parts: [
                    String(localized: "\(template.orderedExercises.count) exercises"),
                    String(localized: "\(template.totalSets) sets"),
                    String(localized: "\(template.estimatedDurationMin) min"),
                ])
                Spacer()
                NavigationLink { TemplateDetailView(template: template) } label: {
                    HStack(spacing: 0) {
                        Text("Details")
                        Image("Icon_details_chev").accessibilityHidden(true)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(minHeight: Theme.minTap)
                }
                .buttonStyle(.plain)
                .padding(.vertical, -12)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .blueGlow()
        .dotTexture(alignment: .center, y: -79.96)
        .glassCard()
        Button {
            env.workout.requestStart(.template(template.id))
        } label: {
            HStack(spacing: 6) {
                Image("IconPlay").accessibilityHidden(true)
                Text("Start \(template.name)")
            }
        }
        .buttonStyle(.primary)
        .accessibilityIdentifier("startRecommended")
    }

    /// Figma "Card": pick exercises, repeat the last workout, browse templates.
    private var choices: some View {
        VStack(spacing: 12) {
            Button { isPickerPresented = true } label: {
                choiceRow("Icon_ring_dumbbell", String(localized: "Pick exercises"), String(localized: "Build today's workout one exercise at a time"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("startPickExercises")
            if let lastSessionName {
                divider
                Button { env.workout.requestStart(.repeatLast) } label: {
                    choiceRow("Icon_ring_repeat", String(localized: "Repeat last workout"), lastSessionName)
                }
                .buttonStyle(.plain)
            }
            divider
            NavigationLink { TemplatesView() } label: {
                choiceRow("Icon_ring_doc", String(localized: "Browse all templates"), String(localized: "Programs and your own templates"))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("browseTemplates")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .dotTexture(alignment: .center, x: 14, y: -79.96)
        .glassCard()
    }

    private var divider: some View {
        Rectangle().fill(Theme.heat.opacity(0.3)).frame(height: 0.5)
    }

    private func choiceRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 8) {
            RingIcon(image: icon, strong: true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.callout)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image("IconChevronCircle").accessibilityHidden(true)
        }
        .contentShape(Rectangle())
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
